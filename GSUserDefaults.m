//
//  GSUserDefaults.m
//  gstuffer
//
//  Created by Charles Parnot on 7/27/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "GSUserDefaults.h"


@implementation GSUserDefaults

GSUserDefaults *_gstufferUserDefaults = nil;

+ (GSUserDefaults *)gstufferUserDefaults
{
	if ( _gstufferUserDefaults == nil )
		_gstufferUserDefaults = [[GSUserDefaults alloc] init];
	return _gstufferUserDefaults;
}

- (id)init
{
	self = [super init];
	if ( self != nil ) {
		parameters = [[NSMutableDictionary alloc] init];
		factoryDefaultsLoaded = NO;
		[self loadFactoryDefaults];
	}
	return self;
}

- (void)dealloc
{
	[parameters release];
	[super dealloc];
}

- (void)loadFactoryDefaults
{
	if ( factoryDefaultsLoaded )
		return;
	//get the app factory defaults from the file GridStufferFactoryDefaults.plist in the resources
	NSMutableDictionary *factory=[[[NSMutableDictionary alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"gstufferFactoryDefaults" ofType:@"plist"]] autorelease];
	// special treatment to expand the tilde
	[factory setObject:[[factory objectForKey:@"MetajobsDirectory"] stringByStandardizingPath] forKey:@"MetajobsDirectory"];
	[[NSUserDefaults standardUserDefaults] registerDefaults:factory];
	factoryDefaultsLoaded = YES;
}


// equivalent to the NSUserDefaults method, except it may take into account temporary values set up for that particular process
- (id)objectForKey:(NSString *)parameterKey
{
	id result = [parameters objectForKey:parameterKey];
	if ( result == nil )
		result = [[NSUserDefaults standardUserDefaults] objectForKey:parameterKey];
	NSAssert1(result != nil, @"Could not retrieve valid object for user defaults key %@", parameterKey);
	return result;
}

- (double)doubleForKey:(NSString *)key
{
	return [[self objectForKey:key] doubleValue];
}

- (BOOL)boolForKey:(NSString *)key
{
	return [[self objectForKey:key] boolValue];
}

- (NSInteger)integerForKey:(NSString *)key
{
	return [[self objectForKey:key] integerValue];
}

// contrary to the NSUserDefaults method, changing an object here does not make that defaults persistent, and is only valid for the duration of the process
- (void)setObject:(id)object forParameterKey:(NSString *)key
{
	[parameters setObject:object forKey:key];
}

@end
