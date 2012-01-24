# Keychain Dumper

## Building

In order to build keychain_dumper you must first create two symbolic links to the appropriate iOS SDK directories. At the time the tool was developed the iOS 4.2 SDK was current and you may need to update the target directories based on the current SDK that is installed.  

	ln -s /Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.0.sdk/ sdk
	ln -s /Developer/Platforms/iPhoneOS.platform/Developer toolchain

Once you have created the symbolic links your directory structure should look similar to:

	-rwxr-xr-x@ 1 userid  staff  1283 Feb 20 19:32 Makefile
	-rwxr-xr-x@ 1 userid  staff   795 Oct  7 12:09 README.md
	-rw-r--r--@ 1 userid  staff  5476 Feb 20 18:10 main.m
	lrwxr-xr-x  1 userid  staff    70 Feb 27 14:40 sdk -> /Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.0.sdk/ 
	lrwxr-xr-x  1 userid  staff    48 Feb 14 16:35 toolchain -> /Developer/Platforms/iPhoneOS.platform/Developer 

You should now be able to compile the project using the included makefile.

	make

If all goes well you should have a binary "keychain_dumper" placed in the same directory as all of the other project files.  Please see the Usage section for more details on what to do from here.

## Usage

Before proceeding ensure you have installed "ldid" on the target iOS device from cydia (these directions assume the target device has already been jailbroken).  

Upload keychain_dumper to a directory of your choice on the target device (I have used /private/var during testing).  Also, once uploaded, be sure to validate that keychain_dumper is executable (chmod +x ./keychain_dumper if it isn't) and validate that /private/var/Keychains/keychain-2.db is world readable (chmod +r /private/var/Keychains/keychain-2.db if it isn't).

Dump all of the entitlements necessary to access the entries in your target's keychain.

    ./keychain_dumper -e > /var/tmp/entitlements.xml

Sign the obtained entitlements into keychain_dumper. (Please note the lack of a space between the "-S" flag and the path to the entitlements file).

	ldid -S/var/tmp/entitlements.xml keychain_dumper

You should now be able to dump the contents of all accessible entries in the keychain.

	./keychain_dumper

Some keychain entries are available regardless of whether the phone is locked or not, while other entries will only be accessible if the phone is unlocked.    

## Contact & Help

If you find a bug you can [open an issue](http://github.com/ptoomey3/Keychain-Dumper/issues).
