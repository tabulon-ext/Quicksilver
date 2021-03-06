//
// NSURL_BLTRExtensions.m
// Quicksilver
//
// Created by Alcor on 7/13/04.
// Copyright 2004 Blacktree. All rights reserved.
//

#import "NSURL_BLTRExtensions.h"
#import "NSString_BLTRExtensions.h"

#include <Security/Security.h>
#define KEYCHAIN_PASS @"PasswordInKeychain"

NSString *QSPasswordForHostUserType(NSString *host, NSString *user, SecProtocolType type);
SecProtocolType QSProtocolTypeForString(NSString *protocol);

SecProtocolType QSProtocolTypeForString(NSString *protocol) {
	if ([protocol isEqualToString:@"ftp"]) return kSecProtocolTypeFTP;
	else if ([protocol isEqualToString:@"http"]) return kSecProtocolTypeHTTP;
	else if ([protocol isEqualToString:@"sftp"]) return kSecProtocolTypeFTPS;
	else if ([protocol isEqualToString:@"eppc"]) return kSecProtocolTypeEPPC;
	else if ([protocol isEqualToString:@"afp"]) return kSecProtocolTypeAFP;
	else if ([protocol isEqualToString:@"smb"]) return kSecProtocolTypeSMB;
	else if ([protocol isEqualToString:@"ssh"]) return kSecProtocolTypeSSH;
	else if ([protocol isEqualToString:@"telnet"]) return kSecProtocolTypeTelnet;
	return 0;
}

NSString *QSPasswordForHostUserScheme(NSString *host, NSString *user, NSString *scheme) {
	NSString *password = nil;

	SecProtocolType type = QSProtocolTypeForString(scheme);

	password = QSPasswordForHostUserType(host, user, type);

	if (!password && type == kSecProtocolTypeFTP)
		password = QSPasswordForHostUserType(host, user, kSecProtocolTypeFTPAccount); // Workaround for Transmit's old type usage
	if (!password)
		password = QSPasswordForHostUserType(host, user, 0);
	if (!password)
			NSLog(@"Couldn't find password. URL:%@ %@ %@", host, user, scheme);
	return password;
}

NSString *QSPasswordForHostUserType(NSString *host, NSString *user, SecProtocolType type) {
	const char 		*buffer;
	UInt32 			length = 0;
	OSErr			err;
	err = SecKeychainFindInternetPassword(NULL, (UInt32)[host length], [host UTF8String], 0, NULL, (UInt32)[user length], [user UTF8String], 0, NULL, 0, type, 0, &length, (void**)&buffer, NULL);
	if (err == noErr) {
		SecKeychainItemFreeContent(NULL, (void *)buffer);
		return [[NSString alloc] initWithCString:buffer encoding:NSUTF8StringEncoding];
	}
	return nil;
}

@implementation NSURL (Keychain)

- (NSString *)keychainPassword {
	return QSPasswordForHostUserScheme([self host], [self user], [self scheme]);
}

- (OSErr) addPasswordToKeychain {
	OSErr err;
	NSString *host = [self host], *user = [self user], *pass = [self password];

	SecProtocolType type = QSProtocolTypeForString([self scheme]);
	SecKeychainItemRef existing = NULL;
	err = SecKeychainFindInternetPassword(NULL, (UInt32)[host length], [host UTF8String], 0, NULL, (UInt32)[user length], [user UTF8String], 0, NULL, 0, type, 0, NULL, NULL, &existing);
	if (err) {
		return SecKeychainAddInternetPassword(NULL, (UInt32)[host length], [host UTF8String], 0, NULL, (UInt32)[user length], [user UTF8String], 0, NULL, 0, type, 0, (UInt32)[pass length], [pass UTF8String], NULL);
	} else {
		err = SecKeychainItemModifyContent(existing, NULL, (UInt32)[pass length], [pass UTF8String]);
		CFRelease(existing);
		return err;
	}
}

- (NSURL *)URLByInjectingPasswordFromKeychain {
	if ([[self password] isEqualToString:KEYCHAIN_PASS]) {
		NSString *pass = [self keychainPassword];
		if (pass)
			return [NSURL URLWithString:[[self absoluteString] stringByReplacingOccurrencesOfString:KEYCHAIN_PASS withString:pass]];
	}
	return self;
}

- (NSURL *)URLByReallyResolvingSymlinksInPath {
    NSURL *url = [self URLByResolvingSymlinksInPath];
    NSArray *parts = [url pathComponents];
    if ([parts[0] isEqualToString:@"/"] && [@[@"tmp", @"var", @"etc"] indexOfObject:parts[1]] != NSNotFound) {
        NSRange range;
        range.location = 1;
        range.length = [parts count] - 1;
        
        return [NSURL fileURLWithPathComponents:[@[@"/", @"private"] arrayByAddingObjectsFromArray:[parts subarrayWithRange:range]]];
    }
    return url;
}

@end

@implementation NSURL (QSBookmarkHelpers)
+ (instancetype)URLByResolvingBookmarkAtURL:(NSURL *)bookmarkURL options:(NSURLBookmarkResolutionOptions)options bookmarkDataIsStale:(BOOL *)isStale error:(NSError **)error {

    NSData *bookmarkData = [[self class] bookmarkDataWithContentsOfURL:bookmarkURL error:error];
    if (!bookmarkData) return nil;

    return [self URLByResolvingBookmarkData:bookmarkData options:options relativeToURL:nil bookmarkDataIsStale:isStale error:error];
}

- (BOOL)writeBookmarkToURL:(NSURL *)destinationURL options:(NSURLBookmarkFileCreationOptions)options error:(NSError **)error {
    NSData *bookmarkData = [self bookmarkDataWithOptions:NSURLBookmarkCreationSuitableForBookmarkFile|options
                          includingResourceValuesForKeys:nil
                                           relativeToURL:nil
                                                   error:error];
    if (bookmarkData == nil) {
        return NO;
    }
    return [NSURL writeBookmarkData:bookmarkData toURL:destinationURL options:options error:error];
}

- (NSData *)bookmarkData {
    return [self bookmarkDataWithOptions:NSURLBookmarkCreationSuitableForBookmarkFile
          includingResourceValuesForKeys:nil
                           relativeToURL:nil
                                   error:NULL];
}
@end
