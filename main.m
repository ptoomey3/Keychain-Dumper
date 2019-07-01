/* 
 * Copyright (c) 2011, Neohapsis, Inc.
 * All rights reserved.
 *
 * Implementation by Patrick Toomey
 *
 * Redistribution and use in source and binary forms, with or without modification, 
 * are permitted provided that the following conditions are met: 
 *
 *  - Redistributions of source code must retain the above copyright notice, this list 
 *    of conditions and the following disclaimer. 
 *  - Redistributions in binary form must reproduce the above copyright notice, this 
 *    list of conditions and the following disclaimer in the documentation and/or 
 *    other materials provided with the distribution. 
 *  - Neither the name of Neohapsis nor the names of its contributors may be used to 
 *    endorse or promote products derived from this software without specific prior 
 *    written permission. 
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR 
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES 
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON 
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/Foundation.framework/Versions/C/Headers/NSTask.h"
#import "sqlite3.h"
#include "stdio.h"

#define KNRM  "\x1B[0m"
#define KRED  "\x1B[31m"
#define KGRN  "\x1B[32m"
#define KYEL  "\x1B[33m"
#define KBLU  "\x1B[34m"
#define KMAG  "\x1B[35m"
#define KCYN  "\x1B[36m"
#define KWHT  "\x1B[37m"

static NSString *selectedEntitlementConstant = @"none";
static NSString *databasePath = @"/var/Keychains/keychain-2.db";


void printToStdOut(NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    NSString *formattedString = [[NSString alloc] initWithFormat: format arguments: args];
    va_end(args);
    [[NSFileHandle fileHandleWithStandardOutput] writeData: [formattedString dataUsingEncoding: NSNEXTSTEPStringEncoding]];
	[formattedString release];
}

NSString *runProcess(NSString *executablePath, NSArray *args)
{
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = pipe.fileHandleForReading;

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = executablePath;
    task.arguments = args;
    task.standardOutput = pipe;
    task.standardError = [NSPipe pipe];
    [task launch];

    NSData *data = [file readDataToEndOfFile];
    [file closeFile];

    return [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
}

NSString *saveDataTemporarily(NSData *data)
{
    NSString *tmpPath = @"/tmp/data";
    [data writeToFile:tmpPath atomically:YES];
    return tmpPath;
}

NSString *runOpenSSLWithArgs(NSArray *args)
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *pathForFile = @"/usr/bin/openssl";
	if ([fileManager fileExistsAtPath:pathForFile])
	{
		return runProcess(@"/usr/bin/openssl", args);
	}
    else 
    {
    	printToStdOut(@"%s[ERROR] Cannot dump certificates, please install \"openssl\" with Cydia.\n%s",KRED, KWHT);
    	exit(0);
    }
}

NSString *runOpenSSLForConversion(NSString *prog, NSData *data)
{
    NSArray *args =  @[prog, @"-inform", @"der", @"-in", saveDataTemporarily(data), @"-outform", @"pem"];
    return runOpenSSLWithArgs(args);
}

NSString *runOpenSSLForPublicConversion(NSString *prog, NSData *data)
{
    NSArray *args =  @[prog, @"-RSAPublicKey_in", @"-inform", @"der", @"-in", saveDataTemporarily(data), @"-outform", @"pem"];
    return runOpenSSLWithArgs(args);
}

void printPrivateKeyPEM(NSData *data)
{
    printToStdOut(@"%@\n", runOpenSSLForConversion(@"rsa", data));
}

void printPublicKeyPEM(NSData *data)
{
    printToStdOut(@"%@\n", runOpenSSLForPublicConversion(@"rsa", data));
}

void printCertPEM(NSData *data)
{
    printToStdOut(@"%@\n", runOpenSSLForConversion(@"x509", data));
}



void printUsage()
{
    printToStdOut(@"Usage: keychain_dumper [-e]|[-h]|[-agnick]\n");
	printToStdOut(@"<no flags>: Dump Password Keychain Items (Generic Password, Internet Passwords)\n");
	printToStdOut(@"-a: Dump All Keychain Items (Generic Passwords, Internet Passwords, Identities, Certificates, and Keys)\n");
	printToStdOut(@"-e: Dump Entitlements\n");
	printToStdOut(@"-g: Dump Generic Passwords\n");
	printToStdOut(@"-n: Dump Internet Passwords\n");
	printToStdOut(@"-i: Dump Identities\n");
	printToStdOut(@"-c: Dump Certificates\n");
	printToStdOut(@"-k: Dump Keys\n");
	printToStdOut(@"-s: Dump Selected Entitlement Group\n");
}

void dumpKeychainEntitlements()
{
    const char *dbpath = [databasePath UTF8String];
    sqlite3 *keychainDB;
    sqlite3_stmt *statement;
	NSMutableString *entitlementXML = [NSMutableString stringWithString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                                       "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
                                       "<plist version=\"1.0\">\n"
                                       "\t<dict>\n"
                                       "\t\t<key>keychain-access-groups</key>\n"
                                       "\t\t<array>\n"];
    if (sqlite3_open(dbpath, &keychainDB) == SQLITE_OK)
    {
        const char *query_stmt = "select distinct agrp from genp union select distinct agrp from inet union select distinct agrp from cert union select distinct agrp from keys;";
		
        if (sqlite3_prepare_v2(keychainDB, query_stmt, -1, &statement, NULL) == SQLITE_OK)
        {
            while(sqlite3_step(statement) == SQLITE_ROW)
            {            
				NSString *group = [[NSString alloc] initWithUTF8String:(const char *) sqlite3_column_text(statement, 0)];
				
                [entitlementXML appendFormat:@"\t\t\t<string>%@</string>\n", group];
                [group release];
            }
            sqlite3_finalize(statement);
        }
        else
        {
            printToStdOut(@"Unknown error querying keychain database\n");
		}

        [entitlementXML appendString:@"\t\t</array>\n"
         "\t</dict>\n"
         "</plist>\n"];
		sqlite3_close(keychainDB);
		printToStdOut(@"%@", entitlementXML);
	}
	else
	{
		printToStdOut(@"Unknown error opening keychain database\n");
	}
}

NSString *listEntitlements()
{
	NSMutableArray *entitlementsArray = [[NSMutableArray alloc] init];
    const char *dbpath = [databasePath UTF8String];
    sqlite3 *keychainDB;
    sqlite3_stmt *statement;
    if (sqlite3_open(dbpath, &keychainDB) == SQLITE_OK)
    {
        const char *query_all = "select distinct agrp from genp union select distinct agrp from inet union select distinct agrp from cert union select distinct agrp from keys;";
        if (sqlite3_prepare_v2(keychainDB, query_all, -1, &statement, NULL) == SQLITE_OK)
        {	
        	printToStdOut(@"%s[INFO] Listing available Entitlement Groups:\n%s", KGRN, KWHT);
        	int index = 0;
            while(sqlite3_step(statement) == SQLITE_ROW)
            {            
				NSString *group = [[NSString alloc] initWithUTF8String:(const char *) sqlite3_column_text(statement, 0)];
                printToStdOut(@"Entitlement Group [%i]: %@\n",index, group);
                [entitlementsArray addObject:group];
                [group release];
                index += 1;
            }
            sqlite3_finalize(statement);
        }
        else
        {
            printToStdOut(@"%s[ERROR] Unknown error querying keychain database\n%s", KRED, KWHT);
            return @"none";
		}

		sqlite3_close(keychainDB);
	}
	else
	{	
		printToStdOut(@"%s[ERROR] Unknown error opening keychain database\n%s", KRED, KWHT);
		return @"none";
	}
	int userSelection;
	printToStdOut(@"%s[ACTION] Select Entitlement Group by Number: %s", KGRN, KWHT);
	scanf("%d", &userSelection);
	if (userSelection > [entitlementsArray count]-1 || userSelection < 0)
	{
		printToStdOut(@"%s[ERROR] Invalid selection, index out of range.\n%s", KRED, KWHT);
		exit(0);
	}
	NSString *selectedEntitlement = [entitlementsArray objectAtIndex:userSelection];
	printToStdOut(@"%s[INFO] %@ selected.\n%s", KYEL, selectedEntitlement, KWHT);
	return selectedEntitlement;
}

NSMutableArray *getCommandLineOptions(int argc, char **argv)
{
    NSMutableArray *arguments = [[NSMutableArray alloc] init];
	int argument;
	if (argc == 1)
    {
        [arguments addObject:(id)kSecClassGenericPassword];
		[arguments addObject:(id)kSecClassInternetPassword];
		return [arguments autorelease];
	}
	while ((argument = getopt (argc, argv, "aegnickhs")) != -1)
    {
        switch(argument)
        {	
        	case 's':
				selectedEntitlementConstant = listEntitlements();
				[arguments addObject:(id)kSecClassGenericPassword];
				[arguments addObject:(id)kSecClassInternetPassword];
				[arguments addObject:(id)kSecClassIdentity];
				[arguments addObject:(id)kSecClassCertificate];
				[arguments addObject:(id)kSecClassKey];
				return [arguments autorelease];
            case 'a':
                [arguments addObject:(id)kSecClassGenericPassword];
				[arguments addObject:(id)kSecClassInternetPassword];
				[arguments addObject:(id)kSecClassIdentity];
				[arguments addObject:(id)kSecClassCertificate];
				[arguments addObject:(id)kSecClassKey];
				return [arguments autorelease];
			case 'e':
				[arguments addObject:@"dumpEntitlements"];
				return [arguments autorelease];
			case 'g':
				[arguments addObject:(id)kSecClassGenericPassword];
				break;
			case 'n':
				[arguments addObject:(id)kSecClassInternetPassword];
				break;
			case 'i':
				[arguments addObject:(id)kSecClassIdentity];
				break;
			case 'c':
				[arguments addObject:(id)kSecClassCertificate];
				break;
			case 'k':
				[arguments addObject:(id)kSecClassKey];
				break;
			case 'h':
				printUsage();
				break;
			case '?':
			    printUsage();
			 	exit(EXIT_FAILURE);
			default:
				continue;
		}
	}
	return [arguments autorelease];
}

NSArray * getKeychainObjectsForSecClass(CFTypeRef kSecClassType)
{
    NSMutableDictionary *genericQuery = [[NSMutableDictionary alloc] init];
	[genericQuery setObject:(id)kSecClassType forKey:(id)kSecClass];
	[genericQuery setObject:(id)kSecMatchLimitAll forKey:(id)kSecMatchLimit];
	[genericQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnAttributes];
	[genericQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnRef];
	[genericQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
	NSArray *keychainItems = nil;
	if (SecItemCopyMatching((CFDictionaryRef)genericQuery, (CFTypeRef *)&keychainItems) != noErr)
	{
		keychainItems = nil;
	}
	[genericQuery release];
	return keychainItems;
}

NSString * getEmptyKeychainItemString(CFTypeRef kSecClassType)
{
	if (kSecClassType == kSecClassGenericPassword)
    {
		return @"[INFO] No Generic Password Keychain items found.\n[HINT] You should unlock your device!\n";
	}
	else if (kSecClassType == kSecClassInternetPassword)
    {
		return @"[INFO] No Internet Password Keychain items found.\n[HINT] You should unlock your device!\n";	
	} 
	else if (kSecClassType == kSecClassIdentity)
    {
		return @"[INFO] No Identity Keychain items found.\n[HINT] You should unlock your device!\n";
	}
	else if (kSecClassType == kSecClassCertificate)
    {
		return @"[INFO] No Certificate Keychain items found.\n[HINT] You should unlock your device!\n";	
	}
	else if (kSecClassType == kSecClassKey)
    {
		return @"[INFO] No Key Keychain items found.\n[HINT] You should unlock your device!\n";	
	}
	else
    {
		return @"[INFO] Unknown Security Class\n[HINT] You should unlock your device!\n";
	}
}

void printAccessibleAttribute(NSString *accessibleString)
{
	if ([accessibleString isEqualToString:@"dk"]) 
		printToStdOut(@"%sAccessible Attribute: kSecAttrAccessibleAlways, protection level 0\n%s", KRED, KWHT);
	else if ([accessibleString isEqualToString:@"ak"])
		printToStdOut(@"%sAccessible Attribute: kSecAttrAccessibleWhenUnlocked, protection level 2 (default)\n%s", KYEL, KWHT);
	else if ([accessibleString isEqualToString:@"ck"])
		printToStdOut(@"%sAccessible Attribute: kSecAttrAccessibleAfterFirstUnlock, protection level 1\n%s", KRED, KWHT);
	else if ([accessibleString isEqualToString:@"dku"])
		printToStdOut(@"%sAccessible Attribute: kSecAttrAccessibleAlwaysThisDeviceOnly, protection level 3\n%s", KBLU, KWHT);
	else if ([accessibleString isEqualToString:@"aku"])
		printToStdOut(@"%sAccessible Attribute: kSecAttrAccessibleWhenUnlockedThisDeviceOnly, protection level 5\n%s", KBLU, KWHT);
	else if ([accessibleString isEqualToString:@"cku"])
		printToStdOut(@"%sAccessible Attribute: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, protection level 4\n%s", KBLU, KWHT);
	else if ([accessibleString isEqualToString:@"akpu"])
		printToStdOut(@"%sAccessible Attribute: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, protection level 6\n%s",KGRN, KWHT);
	else
		printToStdOut(@"%sUnknown Accessible Attribute: %@\n%s", KRED, accessibleString, KWHT);
}

void printGenericPassword(NSDictionary *passwordItem)
{
    printToStdOut(@"Generic Password\n");
	printToStdOut(@"----------------\n");
	printToStdOut(@"Service: %@\n", [passwordItem objectForKey:(id)kSecAttrService]);
	printToStdOut(@"Account: %@\n", [passwordItem objectForKey:(id)kSecAttrAccount]);
	printToStdOut(@"Entitlement Group: %@\n", [passwordItem objectForKey:(id)kSecAttrAccessGroup]);
	printToStdOut(@"Label: %@\n", [passwordItem objectForKey:(id)kSecAttrLabel]);
	NSString* accessibleString = [passwordItem objectForKey:(id)kSecAttrAccessible];
	printAccessibleAttribute(accessibleString);
	printToStdOut(@"Description: %@\n", [passwordItem objectForKey:(id)kSecAttrDescription]); 
	printToStdOut(@"Comment: %@\n", [passwordItem objectForKey:(id)kSecAttrComment]); 
	printToStdOut(@"Synchronizable: %@\n", [passwordItem objectForKey:(id)kSecAttrSynchronizable]); 
	printToStdOut(@"Generic Field: %@\n", [[passwordItem objectForKey:(id)kSecAttrGeneric] description]); 
	NSData* passwordData = [passwordItem objectForKey:(id)kSecValueData];
	printToStdOut(@"Keychain Data: %@\n\n", [[NSString alloc] initWithData:passwordData encoding:NSUTF8StringEncoding]);
}

void printInternetPassword(NSDictionary *passwordItem)
{
    printToStdOut(@"Internet Password\n");
	printToStdOut(@"-----------------\n");
	printToStdOut(@"Server: %@\n", [passwordItem objectForKey:(id)kSecAttrServer]);
	printToStdOut(@"Account: %@\n", [passwordItem objectForKey:(id)kSecAttrAccount]);
	printToStdOut(@"Entitlement Group: %@\n", [passwordItem objectForKey:(id)kSecAttrAccessGroup]);
	printToStdOut(@"Label: %@\n", [passwordItem objectForKey:(id)kSecAttrLabel]);
	NSString* accessibleString = [passwordItem objectForKey:(id)kSecAttrAccessible];
	printAccessibleAttribute(accessibleString);
	NSData* passwordData = [passwordItem objectForKey:(id)kSecValueData];
	printToStdOut(@"Keychain Data: %@\n\n", [[NSString alloc] initWithData:passwordData encoding:NSUTF8StringEncoding]);
}

void printCertificate(NSDictionary *certificateItem)
{
    SecCertificateRef certificate = (SecCertificateRef)[certificateItem objectForKey:(id)kSecValueRef];
	CFStringRef summary;
	summary = SecCertificateCopySubjectSummary(certificate);
	printToStdOut(@"Certificate\n");
	printToStdOut(@"-----------\n");
	printToStdOut(@"Summary: %@\n", (NSString *)summary);
	CFRelease(summary);
	printToStdOut(@"Entitlement Group: %@\n", [certificateItem objectForKey:(id)kSecAttrAccessGroup]);
	printToStdOut(@"Label: %@\n", [certificateItem objectForKey:(id)kSecAttrLabel]);
	NSString* accessibleString = [certificateItem objectForKey:(id)kSecAttrAccessible];
	printAccessibleAttribute(accessibleString);
	printToStdOut(@"Serial Number: %@\n", [certificateItem objectForKey:(id)kSecAttrSerialNumber]);
	printToStdOut(@"Subject Key ID: %@\n", [certificateItem objectForKey:(id)kSecAttrSubjectKeyID]);
	printToStdOut(@"Subject Key Hash: %@\n\n", [certificateItem objectForKey:(id)kSecAttrPublicKeyHash]);
	printCertPEM(certificateItem[@"certdata"]);
}

void printKey(NSDictionary *keyItem)
{
    NSString *keyClass = @"Unknown";
    //NSLog(@"%@", keyItem); //Debugging purposes
	CFTypeRef _keyClass = [keyItem objectForKey:(id)kSecAttrKeyClass];
	CFTypeRef _keyType = [keyItem objectForKey:(id)kSecAttrKeyType];
	int keySize = [[keyItem objectForKey:(id)kSecAttrKeySizeInBits] intValue];
	int effectiveKeySize = [[keyItem objectForKey:(id)kSecAttrEffectiveKeySize] intValue];
	if ([[(id)_keyClass description] isEqual:(id)kSecAttrKeyClassPublic])
    {
		keyClass = @"Public";
	}
	else if ([[(id)_keyClass description] isEqual:(id)kSecAttrKeyClassPrivate])
    {
		keyClass = @"Private";
	}
	else if ([[(id)_keyClass description] isEqual:(id)kSecAttrKeyClassSymmetric])
    {
		keyClass = @"Symmetric";
	}
	printToStdOut(@"Key\n");
	printToStdOut(@"---\n");
	printToStdOut(@"Entitlement Group: %@\n", [keyItem objectForKey:(id)kSecAttrAccessGroup]);
	printToStdOut(@"Label: %@\n", [keyItem objectForKey:(id)kSecAttrLabel]);
	NSString* accessibleString = [keyItem objectForKey:(id)kSecAttrAccessible];
	printAccessibleAttribute(accessibleString);
	printToStdOut(@"Application Label: %@\n", [keyItem objectForKey:(id)kSecAttrApplicationLabel]);
	printToStdOut(@"Application Tag: %@\n", [keyItem objectForKey:(id)kSecAttrApplicationTag]);
	printToStdOut(@"Key Class: %@\n", keyClass);
	printToStdOut(@"Key Size: %@\n", [keyItem objectForKey:(id)kSecAttrKeySizeInBits]);
	printToStdOut(@"Effective Key Size: %@\n", [keyItem objectForKey:(id)kSecAttrEffectiveKeySize]);
	if ((keySize == effectiveKeySize) && (keySize != 0))
	{
		printToStdOut(@"Permanent Key: %@\n", [keyItem objectForKey:(id)kSecAttrIsPermanent]  == nil ? @"Empty" : CFBooleanGetValue((CFBooleanRef)[keyItem objectForKey:(id)kSecAttrIsPermanent]) == true ? @"True" :@"False");
		printToStdOut(@"For Encryption: %@\n", [keyItem objectForKey:(id)kSecAttrCanEncrypt] == nil ? @"Empty" : CFBooleanGetValue((CFBooleanRef)[keyItem objectForKey:(id)kSecAttrCanEncrypt]) == true ? @"True" :@"False");
		printToStdOut(@"For Decryption: %@\n", [keyItem objectForKey:(id)kSecAttrCanDecrypt] == nil ? @"Empty" : CFBooleanGetValue((CFBooleanRef)[keyItem objectForKey:(id)kSecAttrCanDecrypt]) == true ? @"True" :@"False");
		printToStdOut(@"For Key Derivation: %@\n", [keyItem objectForKey:(id)kSecAttrCanDerive] == nil ? @"Empty" : CFBooleanGetValue((CFBooleanRef)[keyItem objectForKey:(id)kSecAttrCanDerive]) == true ? @"True" :@"False");
		printToStdOut(@"For Signatures: %@\n", [keyItem objectForKey:(id)kSecAttrCanSign] == nil ? @"Empty" : CFBooleanGetValue((CFBooleanRef)[keyItem objectForKey:(id)kSecAttrCanSign]) == true ? @"True" :@"False");
		printToStdOut(@"For Signature Verification: %@\n", [keyItem objectForKey:(id)kSecAttrCanVerify] == nil ? @"Empty" : CFBooleanGetValue((CFBooleanRef)[keyItem objectForKey:(id)kSecAttrCanVerify]) == true ? @"True" :@"False");
		printToStdOut(@"For Key Wrapping: %@\n", [keyItem objectForKey:(id)kSecAttrCanWrap] == nil ? @"Empty" : CFBooleanGetValue((CFBooleanRef)[keyItem objectForKey:(id)kSecAttrCanWrap]) == true ? @"True" :@"False");
		printToStdOut(@"For Key Unwrapping: %@\n\n", [keyItem objectForKey:(id)kSecAttrCanUnwrap] == nil ? @"Empty" : CFBooleanGetValue((CFBooleanRef)[keyItem objectForKey:(id)kSecAttrCanUnwrap]) == true ? @"True" :@"False");
	 	if (([[(id)_keyType description]isEqual:(id)kSecAttrKeyTypeRSA])&&([[(id)_keyClass description] isEqual:(id)kSecAttrKeyClassPublic]))
	 	{
	 		printToStdOut(@"RSA public key data:\n");
	 		printPublicKeyPEM(keyItem[@"v_Data"]);
	 	}
	 	else if (([[(id)_keyType description]isEqual:(id)kSecAttrKeyTypeRSA])&&([[(id)_keyClass description] isEqual:(id)kSecAttrKeyClassPrivate]))
	 	{
	 		printToStdOut(@"RSA private key data:\n");
	 		printPrivateKeyPEM(keyItem[@"v_Data"]);
	 	}
	 	else 
	 	{
	 		printToStdOut(@"[INFO] Key data (EC, Symmetric, ...) output not implemented yet. Stay tuned.\n");
	 	}
	 }
	 else 
	 {
	 	printToStdOut(@"[INFO] Malformed key data detected. Check/Cleanup KeyChain manually.\n");
	 }
	 printToStdOut(@"\n");
}

void printIdentity(NSDictionary *identityItem)
{
	SecIdentityRef identity = (SecIdentityRef)[identityItem objectForKey:(id)kSecValueRef];
	SecCertificateRef certificate;
	SecIdentityCopyCertificate(identity, &certificate);
	NSMutableDictionary *identityItemWithCertificate = [identityItem mutableCopy];
	[identityItemWithCertificate setObject:(id)certificate forKey:(id)kSecValueRef];
	printToStdOut(@"Identity\n");
	printToStdOut(@"--------\n");
	printCertificate(identityItemWithCertificate);
	printKey(identityItemWithCertificate);
	[identityItemWithCertificate release];
}

void printResultsForSecClass(NSArray *keychainItems, CFTypeRef kSecClassType)
{
	if (keychainItems == nil)
    {
		printToStdOut(getEmptyKeychainItemString(kSecClassType));
		return;
	}
	NSDictionary *keychainItem;
	for (keychainItem in keychainItems)
    {
		if (kSecClassType == kSecClassGenericPassword)
        {	
        	if ([selectedEntitlementConstant isEqualToString:@"none"])
     		{
     			printGenericPassword(keychainItem);
     		}
			else 
			{
				if ([[keychainItem objectForKey:(id)kSecAttrAccessGroup] isEqualToString:selectedEntitlementConstant])
				{
					printGenericPassword(keychainItem);
				}
			}
		}	
		else if (kSecClassType == kSecClassInternetPassword)
        {
        	if ([selectedEntitlementConstant isEqualToString:@"none"])
     		{
     			printInternetPassword(keychainItem);
     		}
			else 
			{
				if ([[keychainItem objectForKey:(id)kSecAttrAccessGroup] isEqualToString:selectedEntitlementConstant])
				{
					printInternetPassword(keychainItem);
				}
			}
		}
		else if (kSecClassType == kSecClassIdentity)
        {
            if ([selectedEntitlementConstant isEqualToString:@"none"])
     		{
     			printIdentity(keychainItem);
     		}
			else 
			{
				if ([[keychainItem objectForKey:(id)kSecAttrAccessGroup] isEqualToString:selectedEntitlementConstant])
				{
					printIdentity(keychainItem);
				}
			}
		}
		else if (kSecClassType == kSecClassCertificate)
        {
			if ([selectedEntitlementConstant isEqualToString:@"none"])
     		{
     			printCertificate(keychainItem);
     		}
			else 
			{
				if ([[keychainItem objectForKey:(id)kSecAttrAccessGroup] isEqualToString:selectedEntitlementConstant])
				{
					printCertificate(keychainItem);
				}
			}
		}
		else if (kSecClassType == kSecClassKey)
        {
			if ([selectedEntitlementConstant isEqualToString:@"none"])
     		{
     			printKey(keychainItem);
     		}
			else 
			{
				if ([[keychainItem objectForKey:(id)kSecAttrAccessGroup] isEqualToString:selectedEntitlementConstant])
				{
					printKey(keychainItem);
				}
			}
		}
	}
	return;
}

int main(int argc, char **argv) 
{
	id pool=[NSAutoreleasePool new];
	NSArray* arguments;
	arguments = getCommandLineOptions(argc, argv);
	NSArray *passwordItems;	
	if ([arguments indexOfObject:@"dumpEntitlements"] != NSNotFound)
    {
		dumpKeychainEntitlements();
		exit(EXIT_SUCCESS);
	}
	NSArray *keychainItems = nil;
	for (id kSecClassType in (NSArray *) arguments)
    {
		keychainItems = getKeychainObjectsForSecClass((CFTypeRef)kSecClassType);
		printResultsForSecClass(keychainItems, (CFTypeRef)kSecClassType);
		[keychainItems release];	
	}
	[pool drain];
}
