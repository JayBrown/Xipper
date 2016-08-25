#!/bin/bash

# Xipper v1.2.1
# Xipper ➤ Create (shell script version)

LANG=en_US.UTF-8
export PATH=/usr/local/bin:$PATH
ACCOUNT=$(/usr/bin/id -un)
CURRENT_VERSION="1.21"

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
		/usr/bin/osascript -e 'display notification "$2" with title "Xipper [$ACCOUNT]" subtitle "$1"' &>/dev/null
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
	notify "Offline" "Timestamping disabled"
	TIMESTAMP="false"
else
	TIMESTAMP="true"
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
fi

# check if one of the files is unreadable for current user
for FILEPATH in "$@"
do
	if [[ ! -r "$FILEPATH" ]] ; then
		TARGET_NAME=$(/usr/bin/basename "$FILEPATH")
		notify "Error: $TARGET_NAME" "No read permissions for $ACCOUNT"
		exit
	fi
done

# check for eap certificates in the user's keychains
CERTS=$(/usr/bin/security find-identity -v -p eap | /usr/bin/awk '{print substr($0, index($0,$3))}' | /usr/bin/sed -e '$d' -e 's/^"//' -e 's/"$//' | /usr/bin/sort -fdu)
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

# count parameters & choose method
if [[ $# -gt 1 ]] ; then
	METHOD_CHOICE=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.xipper:lcars.png"
	set theMethod to button returned of (display dialog "You have selected multiple files. Do you want to create a single xip archive of all files or multiple xip archives (one per file)?" ¬
		buttons {"Cancel", "Multiple Archives", "Single Archive"} ¬
		default button 3 ¬
		with title "Xipper" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
theMethod
EOT)
	if [[ "$METHOD_CHOICE" == "" ]] || [[ "$METHOD_CHOICE" == "false" ]] ; then
		exit # ALT: continue
	fi
	if [[ "$METHOD_CHOICE" == "Multiple Archives" ]] ; then
		METHOD="multi"
	elif [[ "$METHOD_CHOICE" == "Single Archive" ]] ; then
		METHOD="single"
	fi
else
	METHOD="multi"
fi

# archive file/folder & sign xip archive
if [[ "$METHOD" == "multi" ]] ; then

	for FILEPATH in "$@"
	do
		GOHOME=""
		TARGET_NAME=$(/usr/bin/basename "$FILEPATH")

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

		# check if target directory is writable
		TARGET_DIR=$(/usr/bin/dirname "$FILEPATH")
		if [[ ! -w "$TARGET_DIR" ]] ; then
			GOHOME="true"
		fi

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
				continue
			fi
		elif [[ "$IPSC_MULTI" == "false" ]] ; then
			CERT_CHOICE="$CERTS"
		fi

		# change target directory to user's home folder if it's not writable
		if [[ "$GOHOME" == "true" ]] ; then
			TARGET_DIR="${HOME}"
		fi

		# create xip
		if [[ "$TIMESTAMP" == "true" ]] ; then
			XIP_OUT=$(/usr/bin/xip --sign "$CERT_CHOICE" --timestamp "$FILEPATH" "$TARGET_DIR/$DEST_NAME" 2>&1)
		elif [[ "$TIMESTAMP" == "false" ]] ; then
			XIP_OUT=$(/usr/bin/xip --sign "$CERT_CHOICE" --timestamp=none "$FILEPATH" "$TARGET_DIR/$DEST_NAME" 2>&1)
		fi
		echo "$XIP_OUT"
		sleep 10
		if [[ $(echo "$XIP_OUT" | /usr/bin/grep "xip: error:") != "" ]] ; then
			notify "xip: error" "Please refer to xip stderr"
			XIP_OUT=$(echo "$XIP_OUT" | /usr/bin/sed -e 's/\"//g' -e 'G;')

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
userChoice
EOT)
			exit # ALT: continue
		else
			if [[ "$GOHOME" == "true" ]] ; then
				open "$TARGET_DIR"
			fi
			notify "Completed" "$DEST_NAME"
		fi
	done

elif [[ "$METHOD" == "single" ]] ; then

	# enter filename for the new xip archive
	DEST_NAME=$(/usr/bin/osascript 2>&1 << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.xipper:lcars.png"
	set theFilename to text returned of (display dialog "Enter the destination filename." ¬
		default answer "archive.xip" ¬
		buttons {"Cancel", "Enter"} ¬
		default button 2 ¬
		with title "Xipper" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
theFilename
EOT)
	if [[ $(echo "$DEST_NAME" | /usr/bin/grep "User canceled.") != "" ]] ; then
		exit
	fi
	if [[ "$DEST_NAME" == "" ]] ; then
		DEST_NAME="archive.xip"
	fi
	if [[ "$DEST_NAME" != *".xip" ]] ; then
		DEST_NAME="$DEST_NAME.xip"
	fi

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

	# check if target files are all in the same parent directory
	echo -n "" > "$CACHE_DIR/ppaths~temp.txt"
	for TARGET in "$@"
	do
		PARENT=$(/usr/bin/dirname "$TARGET")
		echo "$PARENT" >> "$CACHE_DIR/ppaths~temp.txt"
	done
	PARENT_LIST=$(/bin/cat "$CACHE_DIR/ppaths~temp.txt" | /usr/bin/sort -u)
	PARENT_COUNT=$(echo "$PARENT_LIST" | /usr/bin/wc -l | xargs)
	if [[ ($PARENT_COUNT>1) ]] ; then
		TARGET_DIR="${HOME}"
		GOHOME="true"
	else
		if [[ ! -w "$PARENT_LIST" ]] ; then
			TARGET_DIR="${HOME}"
			GOHOME="true"
		else
			TARGET_DIR="$PARENT_LIST"
		fi
	fi

	# create xip
	if [[ "$TIMESTAMP" == "true" ]] ; then
		XIP_OUT=$(/usr/bin/xip --sign "$CERT_CHOICE" --timestamp "${@}" "$TARGET_DIR/$DEST_NAME" 2>&1)
	elif [[ "$TIMESTAMP" == "false" ]] ; then
		XIP_OUT=$(/usr/bin/xip --sign "$CERT_CHOICE" --timestamp=none "${@}" "$TARGET_DIR/$DEST_NAME" 2>&1)
	fi
	echo "$XIP_OUT"
	echo -n "" > "$CACHE_DIR/ppaths~temp.txt"
	if [[ $(echo "$XIP_OUT" | /usr/bin/grep "xip: error:") != "" ]] ; then
		notify "xip: error" "Please refer to xip stderr"
		XIP_OUT=$(echo "$XIP_OUT" | /usr/bin/sed -e 's/\"//g' -e 'G;')

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
userChoice
EOT)
		exit
	else
		if [[ "$GOHOME" == "true" ]] ; then
			open "$TARGET_DIR"
		fi
		notify "Completed" "$DEST_NAME"
	fi
fi

exit # ALT: [DELETE]
