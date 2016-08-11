![xipper-platform-macos](https://img.shields.io/badge/platform-macOS-lightgrey.svg)
![xipper-code-shell](https://img.shields.io/badge/code-shell-yellow.svg)
[![xipper-depend-tnote](https://img.shields.io/badge/dependency-terminal--notifier%201.6.3-green.svg)](https://github.com/alloy/terminal-notifier)
[![xipper-license](http://img.shields.io/badge/license-MIT+-blue.svg)](https://github.com/JayBrown/minisign-misc/blob/master/license.md)

# Xipper <img src="https://github.com/JayBrown/Xipper/blob/master/img/jb-img.png" height="20px"/>

**Simple macOS workflow and shell script to compress files with the native xip program and sign them with an Installer Package Signing Certificate (IPSC), plus the ability to import and trust IPSCs untrusted by macOS default.**

Xipper lets you choose an IPSC identity from your keychain and will do the rest. If you run it on a xip archive, it will verify the signature. In case of `pkgutil` warnings, e.g. due to an untrusted certificate, you will receive information about the certificates and the signing party; then you have the choice to import either the leaf or (if there is one) the root into your login keychain as a trusted certificate.

For the difference between IPSCs and normal Code Signing Certificates, see Apple's documentation in §4.12 of [this PDF](http://images.apple.com/certificateauthority/pdf/Developer_ID_CPS_v1.0.pdf).

## Prerequisites
* [terminal-notifier](https://github.com/alloy/terminal-notifier)

Install using [Homebrew](http://brew.sh) with `brew install terminal-notifier` (or with a similar manager)

You need to have Spotlight enabled for `mdfind` to locate the terminal-notifier.app on your volume; if you don't install terminal-notifier, or if you have deactivated Spotlight, the Xipper script will call notifications via AppleScript instead.

Because Xipper uses the macOS Notification Center, the minimum Mac OS requirement is **OS X 10.8 (Mountain Lion)**.

## Caveats
* I haven't upgraded to **macOS Sierra** yet, so I have no idea how the system will react to xip archives signed with self-issued/self-signed IPSCs; therefore the import & trust options (see also below)… for what it's worth.
* The xip program needs to connect to Apple's timestamping server, so if your Mac is offline, Xipper will not work. Please note that the username you chose for your macOS will be embedded in the xip archive's xml header as well, not only your IPSC.
* Xipper searches for `eap` in your keychains instead of `pkgSign`.

Explanation: Maybe this will change in **macOS Sierra**, but in OS X 10.11.6 Apple's `security` program still does not include an option to search for IPSCs with the `security find-identity -p policy` command. I assume that the correct option would be `-p pkgSign`, but currently this is only available for `add-trusted-cert` and `verify-cert`. Therefore Xipper will search with the option `-p eap` instead. This might return more than your actual IPSCs, but it does show you all the valid identities in your keychains you can use to sign a xip archive; these would also include your Apple ID certificate, the one that begins with `com.apple.idms.appleid.prd`.

## Installation & Usage
* [Download the latest DMG](https://github.com/JayBrown/Xipper/releases) and open

### Workflow
* Double-click on the workflow file to install
* If you encounter problems, open it with Automator and save/install from there
* Standard Finder integration in the Services menu

### Shell script [optional]
* Move the script to `/usr/local/bin`
* In your shell enter `chmod +x /usr/local/bin/xipper.sh`
* Run the script with `xipper.sh /path/to/your/file`

This is only necessary if for some reason you want to run this from the shell or another shell script.

## General Notes
You can always sign xip archives with your Apple-issued trusted Apple ID certificate, which is the one that has the common name `com.apple.idms.appleid.prd.xxxxxxxxxxxxxxxx`, which you also need to authenticate yourself on certain websites like sap.com.

The normal procedure for getting another IPSC is to pay for an Apple Developer ID. But you can also self-sign your own IPSC (or issue one using your own CA). MacOS will not trust such a certificate, but you and third parties can, either manually or with Xipper.

Self-signing (or self-issuing) your own IPSCs is easy. You might be able to do it with Apple's own **Keychain Access**, but I recommend using **[xca](https://sourceforge.net/projects/xca/)** with the mandatory X509v3 extensions as put forth by Apple:

```
1.2.840.113635.100.6.1.14=critical,DER:05:00
keyUsage=critical,digitalSignature
basicConstraints=critical,CA:FALSE
```

## To do
* xip creation: mkdir temporary target directory && mv target file (necessary if target is a single file, and not a folder)
* add option to revoke trust for user-trusted certificates
* expand cache to subfolders and keep certificates & xip TOCs in ./trusted or ./untrusted (in case the user wants to manually inspect them further)
* check: read Apple ID from system? (Should replace com.apple.idms.appleid.prd.*)
* later: check if there are additional options for dealing with xip archives when using the xar program
