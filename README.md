# Keychain Dumper

## Usage

All that should be needed to use this tool is the binary that is in the [Releases tab](https://github.com/ptoomey3/Keychain-Dumper/releases/).  This binary has been signed with a self-signed certificate with a "wildcard" entitlement. This entitlement allows keychain_dumper access to all Keychain items in older iOS releases. That support seems to have been removed in more recent releases of iOS. Instead, you must now add explicit entitlements that exist on a given device (entitlements can be app-specific). To help with that, this repository includes a `updateEntitlements.sh` shell script that can be run on-device to grant `keychain_dumper` all of the entitlements available on the device. Finally, if you either don't trust the binary in the Releases tab or are having trouble dumping Keychain items using the below steps, you can build the tool from source and manually sign the appropriate entitlments into your build of the keychain_dumper binary.

To follow these directions successfully, your device must be jailbroken.

Upload keychain_dumper to a directory of your choice on the target device (I have used /tmp during testing). Once uploaded, be sure to validate that keychain_dumper is executable (`# chmod +x ./keychain_dumper` if it isn't) and validate that /private/var/Keychains/keychain-2.db is world readable (`# chmod +r /private/var/Keychains/keychain-2.db` if it isn't).

Note: iOS 11 devices using Electra (or other jailbreaks) may still require a trick to bypass the native sandbox. Compile the binary with the included `entitlements.xml`, sign it with the developer account certificate/priv_key and copy the binary to `/bin` or `/sbin` (which already allow execution).

If you are using the binary from the Releases tab you can attempt to dump all of the accessible password Keychain entries by simply running the tool with no flags:
```bash
    # ./keychain_dumper
```
Some Keychain entries are available regardless of whether the device is locked or not, while other entries will only be accessible if the iOS device is unlocked (i.e. a user has entered their pin). If your device has Touch ID or Face ID enabled, a prompt will appear asking for the appropriate identification. If no Keychain entries are displayed, or if you don't trust the provided binary, you may need to rerun the tool after building the application from source.  Please see the Build section below for details on how to build and sign the application.

By default, keychain_dumper only dumps _Generic_ and _Internet_ passwords.  This is generally what you are most interested in, as most application passwords are stored as _Generic_ or _Internet_ passwords.  However, you can also pass optional flags to dump additional information from the Keychain.  If you run keychain_dumper with the `-h` option you will get the following usage string:

    Usage: keychain_dumper [-e]|[-h]|[-agnick]
    <no flags>: Dump Password Keychain Items (Generic Password, Internet Passwords)
    -a: Dump All Keychain Items (Generic Passwords, Internet Passwords, Identities, Certificates, and Keys)
    -e: Dump Entitlements
    -g: Dump Generic Passwords
    -n: Dump Internet Passwords
    -i: Dump Identities
    -c: Dump Certificates
    -k: Dump Keys
	-s: Dump Selected Entitlement Group

By default, passing no flags is equivalent to running keychain_dumper with the `-gn` flags set.  The other flags largely allow you to dump additional information related to certificates that are installed on the device.

## Building

### Create a Self-Signed Certificate

This section requires a Mac.

Open up the Keychain Access app located in `/Applications/Utilties/Keychain Access` (In the _Other_ folder in Launchpad).

From the application menu open Keychain Access -> Certificate Assistant -> Create a Certificate

Enter a name for the certificate, and make note of it, as you will need it later when you sign `keychain_dumper`.  Make sure the Identity Type is “Self Signed Root” and the Certificate Type is “Code Signing”.  You don’t need to check “Let me override defaults” unless you want to change other properties on the certificate (name, email, etc).

### Build It

You should be able to compile the project using the included Makefile.

    $ make

If all goes well you should have a binary `keychain_dumper` placed in the same directory as the cloned repository.

### Sign It

First we need to find the certificate to use for signing.

    $ make list

Find the 40 character hex string corresponding to the certificate you generated above. You can then sign `keychain_dumper`.

    $ CER=(40 character hex string for certificate) make codesign

You should now be able to follow the directions specified in the Usage section above.  If you don't want to use the wildcard entitlment file that is provided (or you are running more modern versions of iOS that don't support a wildcard entitlement), you can also sign specific entitlements into the binary.  Using an unsigned keychain_dumper binary, you can get a list of entitelments that exist on your specific iOS device with the `-e` flag.  For example:
```bash
    # ./keychain_dumper -e > /var/tmp/entitlements.xml
```
The resulting file can be used in place of the included entitlements.xml file.

## Contact & Help

If you find a bug you can [open an issue](http://github.com/ptoomey3/Keychain-Dumper/issues).
