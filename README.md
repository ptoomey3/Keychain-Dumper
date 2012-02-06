# Keychain Dumper

## Usage

All that should be needed to use keychain_dumper is the binary that is checked in to the Keychain-Dumper Git repository.  This binary has been signed with a self-signed certificate with a "wildcard" entitlement that should grant keychain_dumper access to all Keychain items that would have been granted had the tool been signed with each individual entitlement.  If you either don't trust this binary or are having trouble dumping Keychain items using the below steps, you may can build the tool from source and manually sign the appropriate entitlments into your build of the keychain_dumper binary.

As an aside, the following directions assume the target device has already been jailbroken.  

Upload keychain_dumper to a directory of your choice on the target device (I have used /tmp during testing).  Also, once uploaded, be sure to validate that keychain_dumper is executable (chmod +x ./keychain_dumper if it isn't) and validate that /private/var/Keychains/keychain-2.db is world readable (chmod +r /private/var/Keychains/keychain-2.db if it isn't).

If you are using the binary from Git you can attempt to dump all of the accessible password Keychain entries by simply running the tool with now flags

    ./keychain_dumper

Some keychain entries are available regardless of whether the iOS is locked or not, while other entries will only be accessible if the iOS device is unlocked (i.e. a user has entered their pin).  If no Keychain entries are displayed, or if you don't want to trust the provided binary, you may need to rerun the tool after building the application from source.  Please see the Build section below for details on how to build and sign the application.  

By default keychain_dumper only dumps "Generic" and "Internet" passwords.  This is generally what you are interested in, as most application passwords are stored as "Generic" or "Internet" passwords.  However, you can also pass optional flags to dump additional information from the Keychain.  If you run keychain_dumper with the `-h` option you will get the following usage string:

	Usage: keychain_dumper [-e]|[-h]|[-agnick]
	<no flags>: Dump Password Keychain Items (Generic Password, Internet Passwords)
	-a: Dump All Keychain Items (Generic Passwords, Internet Passwords, Identities, Certificates, and Keys)
	-e: Dump Entitlements
	-g: Dump Generic Passwords
	-n: Dump Internet Passwords
	-i: Dump Identities
	-c: Dump Certificates
	-k: Dump Keys

By default passing no option flags is equivalent to running keychain_dumper with the `-gn` flags set.  The other flags largely allow you to dump additional information related to certificates that are installed on the device.  
    
## Building


### Create a Self-Signed Certificate

Open up the Keychain Access app located in /Applications/Utilties/Keychain Access

From the application menu open Keychain Access -> Certificate Assistant -> Create a Certificate

Enter a name for the certificate, and make note of this name, as you will need it later when you sign Keychain Dumper.  Make sure the Identity Type is “Self Signed Root” and the Certificate Type is “Code Signing”.  You don’t need to check the “Let me override defaults” unless you want to change other properties on the certificate (name, email, etc).

### Build It

In order to build Keychain Dumper you must first create two symbolic links to the appropriate iOS SDK directories. At the time the tool was developed the iOS 5.0 SDK was current and you may need to update the target directories based on the current SDK that is installed.  

	ln -s /Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.0.sdk/ sdk
	ln -s /Developer/Platforms/iPhoneOS.platform/Developer toolchain

Once you have created the symbolic links your directory structure should look similar to:

	-rwxr-xr-x  1 anonymous  staff  1184 Jan 20 08:44 Makefile
	-rw-r--r--  1 anonymous  staff  2504 Jan 24 13:31 README.md
	-rw-r--r--  1 anonymous  staff   269 Jan 24 11:27 entitlements.xml
	-rw-r--r--  1 anonymous  staff  8525 Jan 18 14:49 main.m
	lrwxr-xr-x  1 anonymous  staff    70 Jan 18 14:50 sdk -> /Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.0.sdk/
	lrwxr-xr-x  1 anonymous  staff    48 Jan 18 14:50 toolchain -> /Developer/Platforms/iPhoneOS.platform/Developer

You should now be able to compile the project using the included makefile.

	make

If all goes well you should have a binary `keychain_dumper` placed in the same directory as all of the other project files.  


### Sign It

Using the entitlements.xml file found in the Keychain-Dumper Git repository, sign the binary.  The below certificate was named "Test Cert 1", but you should subsitute the name you used during the certificate creation step above.  

	codesign -fs "Test Cert 1" --entitlements entitlements.xml keychain_dumper

You should now be able to follow the directions specified in the Usage section above.  If you don't want to use the wildcard entitlment file that is provided, you can also sign specific entitlements into the binary.  Using the unsigned Keychain Dumper you can get a list of entitelments that exist on your specific iOS device by using the `-e` flag.  For example, you can run Keychain Dumper as follows:

	./keychain_dumper -e > /var/tmp/entitlements.xml

The resulting file can be used in place of the included entitlements.xml file.  

## Contact & Help

If you find a bug you can [open an issue](http://github.com/ptoomey3/Keychain-Dumper/issues).
