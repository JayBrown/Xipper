![xipper-platform-macos](https://img.shields.io/badge/platform-macOS-lightgrey.svg)
![xipper-code-shell](https://img.shields.io/badge/code-shell-yellow.svg)
[![xipper-depend-tnote](https://img.shields.io/badge/dependency-terminal--notifier%201.6.3-green.svg)](https://github.com/alloy/terminal-notifier)
[![xipper-license](http://img.shields.io/badge/license-MIT+-blue.svg)](https://github.com/JayBrown/minisign-misc/blob/master/license.md)

# Xipper <img src="https://github.com/JayBrown/Xipper/blob/master/img/jb-img.png" height="20px"/>

**Simple macOS workflows and shell scripts
* to compress files with the native xip program and sign them with an Installer Package Signing Certificate (IPSC), and
* to verify IPSCs and import/trust IPSCs untrusted by macOS default.**

**Xipper ➤ Create** lets you choose an IPSC-compatible identity from your keychains and will do the rest, namely create a xip archive from the file(s) you selected; it uses the native macOS [`xip` program](https://developer.apple.com/legacy/library/documentation/Darwin/Reference/ManPages/man1/xip.1.html).

**Xipper ➤ Verify** verifies the signature of a xip archive. In case of `pkgutil` warnings, e.g. due to an untrusted certificate, you will receive information about the certifiate chain and the xip's origin; then you have the choice to trust and import the root certificate into your login keychain (or the leaf, if there is no root). You also have the option to revoke such a trust setting later.

For the difference between IPSCs and normal Code Signing Certificates (CSCs), see Apple's documentation in §4.12 of [this PDF](http://images.apple.com/certificateauthority/pdf/Developer_ID_CPS_v1.0.pdf).

If you're only looking for a tool to verify xip signatures without any additional options, I recommend Patrick Wardle's **[What's Your Sign?](https://objective-see.com/products/whatsyoursign.html)** over at [Objective-See](https://objective-see.com/products.html): it will also work on DMGs and bundles, i.e. with CSCs. Please note that the current version of **What's Your Sign** (v1.1.0) produces a *status error*, if a xip was signed with a 3rd-party (i.e. non-Apple) certificate chain that you have trusted in one of your keychains; in these cases use **Xipper** instead to verify a signature.

## Prerequisites
* [terminal-notifier](https://github.com/alloy/terminal-notifier)

Install using [Homebrew](http://brew.sh) with `brew install terminal-notifier` (or with a similar manager)

You need to have Spotlight enabled for `mdfind` to locate the terminal-notifier.app on your volume; if you don't install terminal-notifier, or if you have deactivated Spotlight, the Xipper scripts will call notifications via AppleScript instead.

Because Xipper uses the macOS Notification Center, the minimum Mac OS requirement is **OS X 10.8 (Mountain Lion)**.

## Caveats
* I haven't upgraded to **macOS Sierra** yet, so I have no idea how the system will react to xip archives signed with self-issued/self-signed IPSCs, i.e. 3rd-party certificates not issued by Apple; therefore the import & trust options (see also below)… for what it's worth.
* The xip program needs to connect to Apple's trusted timestamping server, so if your Mac is offline, Xipper will run with the option `--timestamp=none`
* Please note that the username you chose for your macOS will be embedded in the xip archive's xml header as well, not only your IPSC; so if you want to keep your local username private, you should create a DMG and `codesign` it with a CSC; my own workflow **[DiMaGo](https://github.com/JayBrown/DiMaGo)** will also do that for you.
* Also note that `xip` creates archives with a silent obligatory `--keepParent` option, so if your source is a single file, e.g. a text document or a binary, the contents of your xip archive will reveal the name of file's original parent directory, if you don't put your target file(s) into a dedicated new folder before xipping. (This does not apply if you are xipping bundles.)
* Xipper searches for `eap` in your keychains instead of `pkgSign`; explanation: maybe this will change in **macOS Sierra**, but in OS X 10.11.6 Apple's `security` program still does not include an option to search for IPSCs with the `security find-identity -p policy` command. I assume that the correct option would be `-p pkgSign`, but currently this is only available for `add-trusted-cert` and `verify-cert`. Therefore Xipper will search with the option `-p eap` instead. This might return more than your actual IPSCs, but it does show you all the valid identities in your keychains you can use to sign a xip archive; these would also include your Apple ID certificate, the one that begins with `com.apple.idms.appleid.prd`.

## Installation & Usage
* [Download the latest DMG](https://github.com/JayBrown/Xipper/releases) and open

### Workflows
* Double-click on the workflow files to install
* If you encounter problems, open them with Automator and save/install from there
* Standard Finder integration in the Services menu

### Shell scripts [optional]
* Copy the scripts to `/usr/local/bin`
* In your shell enter `chmod +x /usr/local/bin/xipper-create.sh` and `chmod +x /usr/local/bin/xipper-verify.sh`
* Run the scripts with `xipper-create.sh /path/to/your/file` and `xipper-verify.sh /path/to/your/file`

This is only necessary if for some reason you want to run them from the shell or another shell script.

## General Notes
You can always sign xip archives with your macOS-trusted Apple ID certificate (issued by *Apple Application Integration Certification*), which is the one that has the common name `com.apple.idms.appleid.prd.*`, which you also need to authenticate yourself on certain websites.

The normal procedure for getting another IPSC is to pay for an Apple Developer ID. But you can also self-sign your own IPSC (or issue one using your own CA). MacOS will not trust such a certificate, but you and third parties can, either manually or with Xipper.

Self-signing (or self-issuing) your own IPSCs is easy. You might be able to do it with Apple's own **Keychain Access**, but I recommend using **[xca](https://sourceforge.net/projects/xca/)** with the mandatory X509v3 extensions as put forth by Apple:

```
1.2.840.113635.100.6.1.14=critical,DER:05:00
keyUsage=critical,digitalSignature
basicConstraints=critical,CA:FALSE
```

These are just the basic extensions for signing xip archives or a pkg file; if you want to actually sign the *contents* of a pkg, then you need to add the relevant extensions to your certificate (see Apple's documentation above).

## To do
* further inspect certificates with `openssl`, e.g. to check if CA=true|false
* **later:** check if there are additional options for dealing with xip archives when using the xar program
* **maybe:** read Apple ID from system? (Should replace com.apple.idms.appleid.prd.*)
* **maybe:** mkdir temporary target directory && mv target file (necessary if target is a single file, and not a folder, or several targets in different locations)
