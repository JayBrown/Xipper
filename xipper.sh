#!/bin/bash

# Xipper v1.0 (shell script version)

LANG=en_US.UTF-8
export PATH=/usr/local/bin:$PATH
ACCOUNT=$(who am i | /usr/bin/awk {'print $1'})
CURRENT_VERSION="1.0"

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
		/usr/bin/osascript -e 'display notification "$2" with title "$ACCOUNT Xipper" subtitle "$1"' &>/dev/null
	elif [[ "$NOTESTATUS" == "tn" ]] ; then
		"$TERMNOTE_LOC/Contents/MacOS/terminal-notifier" \
			-title "$ACCOUNT Xipper" \
			-subtitle "$1" \
			-message "$2" \
			-appIcon "$ICON_LOC" \
			>/dev/null
	fi
}

# directories
CACHE_DIR="${HOME}/Library/Caches/local.lcars.xipper"
if [[ ! -e "$CACHE_DIR" ]] ; then
	mkdir -p "$CACHE_DIR"
fi
CERT_DIR="$CACHE_DIR/certs"
if [[ ! -e "$CERT_DIR" ]] ; then
	mkdir -p "$CERT_DIR"
fi
rm -rf "$CERT_DIR/"*

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
if [[ "$TARGET_NAME" == *".xip" ]] ; then
	METHOD="verify"
else
	METHOD="sign"
fi

# archive file/folder & sign xip archive
if [[ "$METHOD" == "sign" ]] ; then

	# check for online status (connection to Apple timestamping server)
	((COUNT = 2))
	while [[ $COUNT -ne 0 ]] ; do
		/sbin/ping -q -c 1 8.8.8.8 &> /dev/null
		RC=$?
		if [[ $RC -eq 0 ]] ; then
			((COUNT = 1))
		fi
		((COUNT = COUNT - 1))
	done
	if [[ ! $RC -eq 0 ]] ; then
		notify "Error: offline" "Timestamping not possible"
		exit
	fi

	# check for eap certificates in the user's keychain
	notify "Please wait!" "Looking for certificates…"
	CERTS=$(/usr/bin/security find-identity -v -p eap | /usr/bin/awk '{print substr($0, index($0,$3))}' | /usr/bin/sed -e '$d' -e 's/^"//' -e 's/"$//')
	if [[ "$CERTS" == "" ]] ; then
		notify "Keychain error" "No signing identity found"
		exit
	else
		IPSC_COUNT=$(echo "$CERTS" | /usr/bin/wc -l | xargs)
		if [[ ($IPSC_COUNT>1) ]] ; then
			IPSC_MULTI="true"
		else
			IPSC_MULTI="false"
		fi
	fi

	# enter filename for the new xip archive
	DEST_NAME=$(/usr/bin/osascript 2>&1 << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.xipper:lcars.png"
	set theFilename to text returned of (display dialog "Enter the destination filename." ¬
		default answer "$TARGET_NAME.xip" ¬
		buttons {"Cancel", "Enter"} ¬
		default button 2 ¬
		with title "Xipper" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
theFilename
EOT)
	if [[ $(echo "$DEST_NAME" | /usr/bin/grep "User canceled.") != "" ]] ; then
		exit # ALT: continue
	fi
	if [[ "$DEST_NAME" == "" ]] ; then
		DEST_NAME="archive.xip"
	fi
	if [[ "$DEST_NAME" != *".xip" ]] ; then
		DEST_NAME="$DEST_NAME.xip"
	fi

	TARGET_DIR=$(/usr/bin/dirname "$FILEPATH")

	if [[ "$IPSC_MULTI" == "true" ]] ; then

		# select signing identity from list
		CERT_CHOICE=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theList to {}
	set theItems to paragraphs of "$CERTS"
	repeat with anItem in theItems
		set theList to theList & {(anItem) as string}
	end repeat
	set AppleScript's text item delimiters to return & linefeed
	set theResult to choose from list theList with prompt "Choose your identity to sign \"" & "$DEST_NAME" & "\"." with title "Xipper" OK button name "Select" cancel button name "Cancel" without multiple selections allowed
	return the result as string
	set AppleScript's text item delimiters to ""
end tell
theResult
EOT)
		if [[ "$CERT_CHOICE" == "" ]] || [[ "$CERT_CHOICE" == "false" ]] ; then
			exit # ALT: continue
		fi
	elif [[ "$IPSC_MULTI" == "false" ]] ; then
		CERT_CHOICE="$CERTS"
	fi
	XIP_OUT=$(/usr/bin/xip --sign "$CERT_CHOICE" --timestamp "$FILEPATH" "$TARGET_DIR/$DEST_NAME")
	if [[ $(echo "$XIP_OUT" | /usr/bin/grep "xip: error:") != "" ]] ; then
		notify "xip: error" "Please refer to output"

		# xip error info window
		INFO=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.xipper:lcars.png"
	set userChoice to button returned of (display dialog "$XIP_OUT" ¬
		buttons {"OK"} ¬
		default button 1 ¬
		with title "Xipper" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
EOT)
		exit # ALT: continue
	fi
fi

# very xip archive
if [[ "$METHOD" == "verify" ]] ; then
	XIP_VERIFY=$(/usr/sbin/pkgutil --check-signature "$FILEPATH")
	XIP_STATUS=$(echo "$XIP_VERIFY" | /usr/bin/awk '/Status:/ {print substr($0, index($0,$2))}')
	if [[ $(echo "$XIP_STATUS" | /usr/bin/grep "untrusted") != "" ]] ; then
		VER_STATUS="false"
		notify "pkgutil: warning" "$XIP_STATUS"
	else
		VER_STATUS="true"
		notify "pkgutil: notification" "Certificate is trusted"
	fi
	# dump full xip/xar TOC xml
	TOC=$(/usr/bin/xar --dump-toc=- -f "$FILEPATH")
	# determine date of xip creation & username
	XIP_USER=$(echo "$TOC" | /usr/bin/xmllint --xpath '//user' - | /usr/bin/awk '{gsub("<user>",""); gsub("</user>",""); print}')
	XIP_DATE=$(echo "$TOC" | /usr/bin/xmllint --xpath '//ctime' - | /usr/bin/awk '{gsub("<ctime>",""); gsub("</ctime>",""); gsub("T"," "); gsub("Z",""); print}')
	# export certificate(s)
	echo "$TOC" | /usr/bin/xmllint --xpath '//signature[@style="RSA"]' - \
		| /usr/bin/sed -n '/<X509Certificate>/,/<\/X509Certificate>/p' \
		| /usr/bin/sed -e 's/^[ \t]*//' \
		| /usr/bin/awk '{gsub("<X509Certificate>","-----BEGIN CERTIFICATE-----\n"); gsub("</X509Certificate>","\n-----END CERTIFICATE-----"); print}' \
		| /usr/bin/csplit -k -s -n 1 -f "$CERT_DIR/$TARGET_NAME"-cert - '/END CERTIFICATE/+1' '{3}' 2>/dev/null
	for CERT in "$CERT_DIR/$TARGET_NAME-cert"* ; do
		if [[ $(/bin/cat "$CERT") == "" ]] ; then
			rm -rf "$CERT"
		else
			mv "$CERT" "$CERT.pem"
		fi
	done
	# check leaf certificate information
	LEAF=$(/usr/bin/openssl x509 -in "$CERT_DIR/$TARGET_NAME-cert0.pem" -noout -issuer -subject -startdate -enddate)
	ISSUER_RAW=$(echo "$LEAF" | /usr/bin/grep "issuer=" | /usr/bin/awk -F"/CN=" '{print substr($0, index($0,$2))}')
	ISSUER=$(echo "$ISSUER_RAW" | /usr/bin/awk -F/ '{print $1}')
	SUBJECT_RAW=$(echo "$LEAF" | /usr/bin/grep "subject=" | /usr/bin/awk -F"/CN=" '{print substr($0, index($0,$2))}')
	SUBJECT=$(echo "$SUBJECT_RAW" | /usr/bin/awk -F/ '{print $1}')
	SINCE=$(echo "$LEAF" | /usr/bin/grep "notBefore=" |/usr/bin/awk -F= '{print substr($0, index($0,$2))}')
	UNTIL=$(echo "$LEAF" | /usr/bin/grep "notAfter=" |/usr/bin/awk -F= '{print substr($0, index($0,$2))}')
	XIP_INFO="Issuer: $ISSUER
Subject: $SUBJECT
Issued: $SINCE
Valid until: $UNTIL

Archive created by: $XIP_USER
Creation date: $XIP_DATE UTC"
	# info windows
	if [[ "$VER_STATUS" == "false" ]] ; then
		# count certs
		CERTS_LIST=$(find "$CERT_DIR" -maxdepth 1 -name \*.pem)
		CERTS_COUNT=$(echo "$CERTS_LIST" | /usr/bin/wc -l | xargs)
		if [[ "$CERTS_COUNT" -gt 1 ]] ; then
			INFO=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.xipper:lcars.png"
	set userChoice to button returned of (display dialog "The program pkgutil has given a warning for the archive \"" & "$TARGET_NAME" & "\". Do you want to import and trust the root certificate(s) or only the leaf certificate?" & Return & Return & "$XIP_INFO" ¬
		buttons {"Cancel", "Trust Leaf", "Trust Root"} ¬
		default button 1 ¬
		with title "Warning" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
EOT)
			if [[ "$INFO" == "" ]] || [[ "$INFO" == "false" ]] ; then
				rm -rf "$CERT_DIR/$TARGET_NAME-cert"*
				exit # ALT: continue
			elif [[ "$INFO" == "Trust Leaf" ]] ; then
				/usr/bin/security add-trusted-cert -r trustAsRoot -k "${HOME}/Library/Keychains/login.keychain" "$CERT_DIR/$TARGET_NAME-cert0.pem" && rm -rf "$CERT_DIR/$TARGET_NAME-cert"* && notify "Trusted leaf as root" "$SUBJECT"
			elif [[ "$INFO" == "Trust Root" ]] ; then
				if [[ -e "$CERT_DIR/$TARGET_NAME-cert2.pem" ]] ; then
					/usr/bin/security add-trusted-cert -r trustRoot -k "${HOME}/Library/Keychains/login.keychain" "$CERT_DIR/$TARGET_NAME-cert2.pem" && \
						/usr/bin/security add-certificates -k "${HOME}/Library/Keychains/login.keychain" "$CERT_DIR/$TARGET_NAME-cert1.pem" && \
						notify "Trusted root & intermediary" "$ISSUER" && \
						rm -rf "$CERT_DIR/$TARGET_NAME-cert"*
				else
					/usr/bin/security add-trusted-cert -r trustRoot -k "${HOME}/Library/Keychains/login.keychain" "$CERT_DIR/$TARGET_NAME-cert1.pem" && rm -rf "$CERT_DIR/$TARGET_NAME-cert"* && notify "Trusted root" "$ISSUER"
				fi
			fi
		else
			INFO=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.xipper:lcars.png"
	set userChoice to button returned of (display dialog "The program pkgutil has given a warning for the archive \"" & "$TARGET_NAME" & "\". Do you want to import and trust the leaf certificate?" & Return & Return & "$XIP_INFO" ¬
		buttons {"Cancel", "Trust Leaf"} ¬
		default button 1 ¬
		with title "Warning" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
EOT)
			if [[ "$INFO" == "" ]] || [[ "$INFO" == "false" ]] ; then
				rm -rf "$CERT_DIR/$TARGET_NAME-cert"*
				exit # ALT: continue
			elif [[ "$INFO" == "Trust Leaf" ]] ; then
				/usr/bin/security add-trusted-cert -r trustAsRoot -k "${HOME}/Library/Keychains/login.keychain" "$CERT_DIR/$TARGET_NAME-cert0.pem" && rm -rf "$CERT_DIR/$TARGET_NAME-cert"* && notify "Trusted leaf as root" "$SUBJECT"
			fi
		fi
	elif [[ "$VER_STATUS" == "true" ]] ; then
		INFO=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.xipper:lcars.png"
	set userChoice to button returned of (display dialog "Certificate information for \"" & "$TARGET_NAME" & "\"" & Return & Return & "$XIP_INFO" ¬
		buttons {"OK"} ¬
		default button 1 ¬
		with title "Results" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
EOT)
	fi
fi

exit # ALT: done
