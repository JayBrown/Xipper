#!/bin/bash

# Xipper v1.2.2
# Xipper ➤ Verify (shell script version)

LANG=en_US.UTF-8
export PATH=/usr/local/bin:$PATH
ACCOUNT=$(/usr/bin/id -un)
CURRENT_VERSION="1.22"

# check compatibility & determine correct Mac OS name
MACOS2NO=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F. '{print $2}')
if [[ "$MACOS2NO" -le 7 ]] ; then
	echo "Error! Exiting…"
	echo "Xipper needs at least OS X 10.8 (Mountain Lion)"
	INFO=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set userChoice to button returned of (display alert "Error! Minimum OS requirement:" & return & "OS X 10.8 (Mountain Lion)" ¬
		as critical ¬
		buttons {"Quit"} ¬
		default button 1 ¬
		giving up after 60)
end tell
EOT)
	exit
fi

# notify function
notify () {
 	if [[ "$NOTESTATUS" == "osa" ]] ; then
		/usr/bin/osascript &>/dev/null << EOT
tell application "System Events"
	display notification "$2" with title "Xipper [" & "$ACCOUNT" & "]" subtitle "$1"
end tell
EOT
	elif [[ "$NOTESTATUS" == "tn" ]] ; then
		"$TERMNOTE_LOC/Contents/MacOS/terminal-notifier" \
			-title "Xipper [$ACCOUNT]" \
			-subtitle "$1" \
			-message "$2" \
			-appIcon "$ICON_LOC" \
			>/dev/null
	fi
}

# directories
CACHE_DIR="${HOME}/Library/Caches/local.lcars.xipper"
mkdir -p "$CACHE_DIR"
CERT_DIR="$CACHE_DIR/certs"
mkdir -p "$CERT_DIR"
TOC_DIR="$CACHE_DIR/toc"
mkdir -p "$TOC_DIR"

# remove old toc and certificates from previous run
rm -rf "$TOC_DIR/"*".xml"
rm -rf "$CERT_DIR/"*".pem"

# icon for notifications & prompts
ICON64="iVBORw0KGgoAAAANSUhEUgAAAIwAAACMEAYAAAD+UJ19AAACYElEQVR4nOzUsW1T
URxH4fcQSyBGSPWQrDRZIGUq2IAmJWyRMgWRWCCuDAWrGDwAkjsk3F/MBm6OYlnf
19zqSj/9i/N6jKenaRpjunhXV/f30zTPNzePj/N86q9fHx4evi9j/P202/3+WO47
D2++3N4uyzS9/Xp3d319+p3W6+fncfTnqNx3Lpbl3bf/72q1+jHPp99pu91sfr4f
43DY7w+fu33n4tVLDwAul8AAGYEBMgIDZAQGyAgMkBEYICMwQEZggIzAABmBATIC
A2QEBsgIDJARGCAjMEBGYICMwAAZgQEyAgNkBAbICAyQERggIzBARmCAjMAAGYEB
MgIDZAQGyAgMkBEYICMwQEZggIzAABmBATICA2QEBsgIDJARGCAjMEBGYICMwAAZ
gQEyAgNkBAbICAyQERggIzBARmCAjMAAGYEBMgIDZAQGyAgMkBEYICMwQEZggIzA
ABmBATICA2QEBsgIDJARGCAjMEBGYICMwAAZgQEyAgNkBAbICAyQERggIzBARmCA
jMAAGYEBMgIDZAQGyAgMkBEYICMwQEZggIzAABmBATICA2QEBsgIDJARGCAjMEBG
YICMwAAZgQEyAgNkBAbICAyQERggIzBARmCAjMAAGYEBMgIDZAQGyAgMkBEYICMw
QEZggIzAABmBATICA2QEBsgIDJARGCAjMEBGYICMwAAZgQEyAgNkBAbICAyQERgg
IzBARmCAjMAAGYEBMgIDZAQGyAgMkBEYICMwQEZggIzAABmBATICA2QEBsgIDJAR
GCAjMEBGYICMwAAZgQEy/wIAAP//nmUueblZmDIAAAAASUVORK5CYII="

# save icon
ICON_LOC="$CACHE_DIR/lcars.png"
if [[ ! -e "$ICON_LOC" ]] ; then
	echo "$ICON64" > "$CACHE_DIR/lcars.base64"
	/usr/bin/base64 -D -i "$CACHE_DIR/lcars.base64" -o "$ICON_LOC" && rm -rf "$CACHE_DIR/lcars.base64"
fi
if [[ -e "$CACHE_DIR/lcars.base64" ]] ; then
	rm -rf "$CACHE_DIR/lcars.base64"
fi

# look for terminal-notifier
TERMNOTE_LOC=$(/usr/bin/mdfind "kMDItemCFBundleIdentifier == 'nl.superalloy.oss.terminal-notifier'" 2>/dev/null | /usr/bin/awk 'NR==1')
if [[ "$TERMNOTE_LOC" == "" ]] ; then
	NOTESTATUS="osa"
else
	NOTESTATUS="tn"
fi

# check for update
NEWEST_VERSION=$(/usr/bin/curl --silent https://api.github.com/repos/JayBrown/Xipper/releases/latest | /usr/bin/awk '/tag_name/ {print $2}' | xargs)
if [[ "$NEWEST_VERSION" == "" ]] ; then
	NEWEST_VERSION="0"
fi
NEWEST_VERSION=${NEWEST_VERSION//,}
if (( $(echo "$NEWEST_VERSION > $CURRENT_VERSION" | /usr/bin/bc -l) )) ; then
	notify "Update available" "Xipper v$NEWEST_VERSION"
	/usr/bin/open "https://github.com/JayBrown/Xipper/releases/latest"
fi

FILEPATH="$1" # ALT: for FILEPATH in "$@" ### do

TARGET_NAME=$(/usr/bin/basename "$FILEPATH")
if [[ "$TARGET_NAME" != *".xip" ]] ; then
	notify "Error" "Not a xip archive"
	exit # ALT: continue
fi

# verify xip archive
XIP_VERIFY=$(/usr/sbin/pkgutil --check-signature "$FILEPATH")
XIP_STATUS=$(echo "$XIP_VERIFY" | /usr/bin/awk '/Status:/ {print substr($0, index($0,$2))}')
if [[ $(echo "$XIP_STATUS" | /usr/bin/grep "untrusted") != "" ]] ; then
	VER_STATUS="false"
	notify "$TARGET_NAME" "❌ Certificate is not trusted"
elif [[ "$XIP_STATUS" == "signed by a certificate trusted by Mac OS X" ]] ; then
	VER_STATUS="true"
	APPLE="true"
	notify "$TARGET_NAME" "☑️ Certificate trusted by macOS"
elif [[ "$XIP_STATUS" == "signed Apple software" ]] ; then
	VER_STATUS="true"
	APPLE="true"
	notify "$TARGET_NAME" "✅ Signed Apple software"
elif [[ "$XIP_STATUS" == "signed by a certificate trusted for current user" ]] ; then
	VER_STATUS="true"
	APPLE="false"
	notify "$TARGET_NAME" "✔️︎ Certificate trusted by $ACCOUNT"
elif [[ "$XIP_STATUS" == "signed by a certificate trusted on this system" ]] ; then
	VER_STATUS="true"
	APPLE="false"
	notify "$TARGET_NAME" "✔︎ Certificate trusted by admin"
elif [[ "$XIP_STATUS" == "signed by a certificate that has since expired" ]] ; then
	VER_STATUS="true"
	APPLE="true"
	notify "$TARGET_NAME" "✖︎ Expired certificate or untrusted root"
else
	VER_STATUS="false"
	notify "$TARGET_NAME" "❓︎ Unknown certificate status"
fi

# dump full xip/xar TOC xml
CURRENT_DATE=$(/bin/date +%Y%m%d-%H%M%S)
TOC=$(/usr/bin/xar --dump-toc=- -f "$FILEPATH")
TOC_LOC="$TOC_DIR/$TARGET_NAME-$CURRENT_DATE-toc.xml"
echo "$TOC" > "$TOC_LOC"

# determine date of xip creation & username
XIP_USER=$(echo "$TOC" | /usr/bin/xmllint --xpath '//user' - | /usr/bin/awk '{gsub("<user>",""); gsub("</user>",""); print}')
XIP_DATE=$(echo "$TOC" | /usr/bin/xmllint --xpath '//ctime' - | /usr/bin/awk '{gsub("<ctime>",""); gsub("</ctime>",""); gsub("T"," "); gsub("Z",""); print}')

# export certificate(s)
echo "$TOC" | /usr/bin/xmllint --xpath '//signature[@style="RSA"]' - \
	| /usr/bin/sed -n '/<X509Certificate>/,/<\/X509Certificate>/p' \
	| xargs \
	| /usr/bin/awk '{gsub("<X509Certificate>","-----BEGINCERTIFICATE-----"); gsub("</X509Certificate>","-----ENDCERTIFICATE-----"); print}' \
	| /usr/bin/awk '{gsub(" ","\n"); print}' \
	| /usr/bin/awk '{gsub("BEGINCERTIFICATE-----","BEGIN CERTIFICATE-----\n"); gsub("-----ENDCERTIFICATE","\n-----END CERTIFICATE"); print}' \
	| /usr/bin/csplit -k -s -n 1 -f "$CERT_DIR/$TARGET_NAME-$CURRENT_DATE"-cert - '/END CERTIFICATE/+1' '{3}' 2>/dev/null
for CERT in "$CERT_DIR/$TARGET_NAME-$CURRENT_DATE-cert"* ; do
	if [[ $(/bin/cat "$CERT") == "" ]] ; then
		rm -rf "$CERT"
	else
		mv "$CERT" "$CERT.pem"
	fi
done

# check leaf certificate information
LEAF=$(/usr/bin/openssl x509 -in "$CERT_DIR/$TARGET_NAME-$CURRENT_DATE-cert0.pem" -noout -issuer -subject -startdate -enddate -fingerprint)
ISSUER_RAW=$(echo "$LEAF" | /usr/bin/grep "issuer=" | /usr/bin/awk -F"/CN=" '{print substr($0, index($0,$2))}')
ISSUER=$(echo "$ISSUER_RAW" | /usr/bin/awk -F/ '{print $1}')
SUBJECT_RAW=$(echo "$LEAF" | /usr/bin/grep "subject=" | /usr/bin/awk -F"/CN=" '{print substr($0, index($0,$2))}')
SUBJECT=$(echo "$SUBJECT_RAW" | /usr/bin/awk -F/ '{print $1}')
SINCE=$(echo "$LEAF" | /usr/bin/grep "notBefore=" |/usr/bin/awk -F= '{print substr($0, index($0,$2))}')
UNTIL=$(echo "$LEAF" | /usr/bin/grep "notAfter=" |/usr/bin/awk -F= '{print substr($0, index($0,$2))}')
HASH=$(echo "$LEAF" | /usr/bin/grep "SHA1 Fingerprint=" | /usr/bin/awk -F= '{gsub (":",""); print substr($0, index($0,$2))}')
CERTS_LIST=$(find "$CERT_DIR" -maxdepth 1 -name \*.pem | /usr/bin/sort -nr)
ROOT_CERT=$(echo "$CERTS_LIST" | /usr/bin/head -n 1)
ROOT_RAW=$(/usr/bin/openssl x509 -in "$ROOT_CERT" -noout -subject -fingerprint)
if [[ "$ROOT_RAW" == "" ]] ; then
	ROOT="n/a"
	ROOT_HASH="n/a"
else
	ROOT=$(echo "$ROOT_RAW" | /usr/bin/grep "subject=" | /usr/bin/awk -F"/CN=" '{print substr($0, index($0,$2))}' | /usr/bin/awk -F/ '{print $1}')
	ROOT_HASH=$(echo "$ROOT_RAW" | /usr/bin/grep "SHA1 Fingerprint=" | /usr/bin/awk -F= '{gsub (":",""); print substr($0, index($0,$2))}')
fi

# set info window text
XIP_INFO="■■■ Archive filename ■■■
$TARGET_NAME

■■■ Verification status (pkgutil) ■■■
$XIP_STATUS

■■■ Subject ■■■
CN: $SUBJECT
SHA-1: $HASH

■■■ Issuer ■■■
CN: $ISSUER
Issued: $SINCE
Valid until: $UNTIL

■■■ Root ■■■
CN: $ROOT
SHA-1: $ROOT_HASH

■■■ Archive data ■■■
Created by: $XIP_USER
Creation date: $XIP_DATE UTC"

# info windows
if [[ "$VER_STATUS" == "false" ]] ; then
	# count certs
	CERTS_LIST=$(find "$CERT_DIR" -maxdepth 1 -name \*.pem | /usr/bin/sort -nr)
	CERTS_COUNT=$(echo "$CERTS_LIST" | /usr/bin/wc -l | xargs)
	if [[ "$CERTS_COUNT" -gt 1 ]] ; then
		CERT_INFO="certificate chain"
	else
		CERT_INFO="certificate"
	fi
	INFO=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.xipper:lcars.png"
	set userChoice to button returned of (display dialog "The program pkgutil has given a warning for the current archive. Do you want to trust the " & "$CERT_INFO" & "?" & Return & Return & "$XIP_INFO" ¬
		buttons {"Cancel", "Trust"} ¬
		default button 1 ¬
		with title "Warning" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
userChoice
EOT)
	if [[ "$INFO" == "" ]] || [[ "$INFO" == "false" ]] ; then
		exit # ALT: continue
	fi
	ROOT_CERT=$(echo "$CERTS_LIST" | /usr/bin/head -n 1)
	if [[ "$CERTS_COUNT" -gt 1 ]] ; then
		/usr/bin/security add-trusted-cert -r trustRoot -k "${HOME}/Library/Keychains/login.keychain" "$ROOT_CERT" && notify "Imported & trusted root certificate" "$ROOT"
	else
		/usr/bin/security add-trusted-cert -r trustAsRoot -k "${HOME}/Library/Keychains/login.keychain" "$ROOT_CERT" && notify "Imported & trusted certificate" "$SUBJECT"
	fi
elif [[ "$VER_STATUS" == "true" ]] ; then
	if [[ "$APPLE" == "true" ]] ; then
		INFO=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.xipper:lcars.png"
	set userChoice to button returned of (display dialog "Archive: " & "$TARGET_NAME" & Return & Return & "$XIP_INFO" ¬
		buttons {"OK"} ¬
		default button 1 ¬
		with title "Results" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
userChoice
EOT)
	elif [[ "$APPLE" == "false" ]] ; then
		INFO=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.xipper:lcars.png"
	set userChoice to button returned of (display dialog "Archive: " & "$TARGET_NAME" & Return & Return & "$XIP_INFO" ¬
		buttons {"Revoke Trust","OK"} ¬
		default button 2 ¬
		with title "Results" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
userChoice
EOT)

		# revoke trust of stored 3rd-party certificate
		if [[ "$INFO" == "Revoke Trust" ]] ; then
			CERTS_LIST=$(find "$CERT_DIR" -maxdepth 1 -name \*.pem | /usr/bin/sort -nr)
			ROOT_CERT=$(echo "$CERTS_LIST" | /usr/bin/head -n 1)
			REVOKE=$(/usr/bin/security remove-trusted-cert "$ROOT_CERT" 2>&1)
			if [[ "$REVOKE" == "" ]] ; then
				notify "Revoked trusted certificate" "$ROOT | $SUBJECT"
			else
				notify "Keychain error" "Please revoke trust manually"
				/usr/bin/open -b com.apple.keychainaccess
			fi
		fi
	fi
fi

exit # ALT: done
