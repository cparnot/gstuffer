//
//  GSUserDefaults.h
//  gstuffer
//
//  Created by Charles Parnot on 7/27/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/* wrapper for NSUserDefaults that allows setting user defaults via the command-line parameters as well */

@interface GSUserDefaults : NSObject
{
	NSMutableDictionary *parameters;
	BOOL factoryDefaultsLoaded;
}

+ (GSUserDefaults *)gstufferUserDefaults;

- (void)loadFactoryDefaults;

// equivalent to the NSUserDefaults methods, except it may take into account temporary values set up for that particular process
- (id)objectForKey:(NSString *)parameterKey;
- (double)doubleForKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key;
- (NSInteger)integerForKey:(NSString *)key;

// contrary to the NSUserDefaults method, changing an object here does not make that defaults persistent, and is only valid for the duration of the process
- (void)setObject:(id)object forParameterKey:(NSString *)parameterKey;

@end
