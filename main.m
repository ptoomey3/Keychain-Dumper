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
 *   of conditions and the following disclaimer. 
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
#import <Security/Security.h>
#import "sqlite3.h"

void printToStdOut(NSString *format, ...) 
{
    va_list args;
    va_start(args, format);
    NSString *formattedString = [[NSString alloc] initWithFormat: format arguments: args];
    va_end(args);
    [[NSFileHandle fileHandleWithStandardOutput] writeData: [formattedString dataUsingEncoding: NSNEXTSTEPStringEncoding]];
	[formattedString release];
}

NSString * convertKeychainBlobtoUTFString(id inputData)
{
	// if we got nothing back then we likely have a db entry that is empty that defaults to null
	if ( inputData == nil )
		return @"";
	//for some reason the return value from the keychain seems to always be either a NSData* or an NSSTRING*
	//if it doesn't have a "bytes" selector we will just assume it is a string
	if ( [inputData respondsToSelector:@selector(bytes)] == NO )
		return inputData;
	NSString *returnString = [[[NSString alloc] initWithBytes:[inputData bytes] length:[inputData length] encoding:NSUTF8StringEncoding] autorelease];
	if (returnString != nil)
		return returnString;
	else {
		return @"";
	}
	
}

NSString * getKeychainSecureData(NSDictionary * keychainItem, CFTypeRef kSecClassType) 
{
	NSMutableDictionary *keychainItemQuery = [NSMutableDictionary dictionaryWithDictionary:keychainItem];
	NSString *keychainData = nil;
	
	[keychainItemQuery setObject:(id)kSecClassType forKey:(id)kSecClass];
	[keychainItemQuery setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];
	[keychainItemQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
	
	NSData *keychainDataBlob = nil;
	
	if (SecItemCopyMatching((CFDictionaryRef)keychainItemQuery, (CFTypeRef *)&keychainDataBlob) == noErr)
	{
		keychainData = convertKeychainBlobtoUTFString(keychainDataBlob);
	}
	else
	{
		keychainData =  @"<Not Accessible>";
	}
	
	[keychainDataBlob release];
	
	return keychainData;
}

void dumpKeychainItems()
{
	NSMutableDictionary *genericPasswordQuery = [[NSMutableDictionary alloc] init];
	
	[genericPasswordQuery setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
	[genericPasswordQuery setObject:(id)kSecMatchLimitAll forKey:(id)kSecMatchLimit];
	[genericPasswordQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnAttributes];
	
	
	NSArray *keychainItems = nil;
	
	if (SecItemCopyMatching((CFDictionaryRef)genericPasswordQuery, (CFTypeRef *)&keychainItems) == noErr)
	{
		NSDictionary *keychainItem = nil;
		for (keychainItem in (NSArray *) keychainItems) {
			printToStdOut(@"Service: %@\n", [keychainItem objectForKey:(id)kSecAttrService]);
			printToStdOut(@"Account: %@\n", [keychainItem objectForKey:(id)kSecAttrAccount]);
			printToStdOut(@"Entitlement Group: %@\n", [keychainItem objectForKey:(id)kSecAttrAccessGroup]);
			printToStdOut(@"Label: %@\n", convertKeychainBlobtoUTFString([keychainItem objectForKey:(id)kSecAttrLabel]));
			printToStdOut(@"Generic Field: %@\n", convertKeychainBlobtoUTFString([keychainItem objectForKey:(id)kSecAttrGeneric]));
			printToStdOut(@"Keychain Data: %@\n\n", getKeychainSecureData(keychainItem, kSecClassGenericPassword));
			
		}
		
	}
	else
	{
		printToStdOut(@"No Generic Password Keychain items found. Please see the README.md to get started\n");
		
	}
	
	[keychainItems release];
    keychainItems = nil;
    
    NSMutableDictionary *internetPasswordQuery = [[NSMutableDictionary alloc] init];
	
	[internetPasswordQuery setObject:(id)kSecClassInternetPassword forKey:(id)kSecClass];
	[internetPasswordQuery setObject:(id)kSecMatchLimitAll forKey:(id)kSecMatchLimit];
	[internetPasswordQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnAttributes];
	
	
	if (SecItemCopyMatching((CFDictionaryRef)internetPasswordQuery, (CFTypeRef *)&keychainItems) == noErr)
	{
		NSDictionary *keychainItem = nil;
		for (keychainItem in (NSArray *) keychainItems) {
			printToStdOut(@"Server: %@\n", [keychainItem objectForKey:(id)kSecAttrServer]);
			printToStdOut(@"Account: %@\n", [keychainItem objectForKey:(id)kSecAttrAccount]);
			printToStdOut(@"Entitlement Group: %@\n", [keychainItem objectForKey:(id)kSecAttrAccessGroup]);
			printToStdOut(@"Label: %@\n", convertKeychainBlobtoUTFString([keychainItem objectForKey:(id)kSecAttrLabel]));
			printToStdOut(@"Keychain Data: %@\n\n", getKeychainSecureData(keychainItem, kSecClassInternetPassword));
			
		}
		
	}
	else
	{
		printToStdOut(@"No Internet Password Keychain items found. Please see the README.md to get started\n");
		
	}
	
	[keychainItems release];
    
	return;
}

void dumpKeychainEntitlements()
{
    NSString *databasePath = @"/var/Keychains/keychain-2.db";
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
        const char *query_stmt = "SELECT DISTINCT agrp FROM genp UNION SELECT DISTINCT agrp FROM inet";
		
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


int main(void) 
{
	id pool=[NSAutoreleasePool new];
	NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSArray *arguments = [processInfo arguments];
    BOOL dumpKeychainDatabase = NO;
    if ( [arguments count] > 2 || ( [arguments count] == 2 && [[arguments lastObject] isEqualToString:@"-e"] == NO ) )
    {
        printToStdOut(@"Usage: keychain_dumper [-e] %@ %d %d",  [arguments lastObject],[[arguments lastObject] isEqualToString:@"-e"], [arguments count] );
    }
    else if ( [arguments count] == 2 && [[arguments lastObject] isEqualToString:@"-e"] )
    {
		dumpKeychainEntitlements();
    }
    else
    {
		dumpKeychainItems();
    }
    
	[pool drain];
}

