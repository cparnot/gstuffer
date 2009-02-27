//
//  MainController.m
//  gstuffer
//
//  Created by Charles Parnot on 7/11/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "GSMain.h"
#import "GSServers.h"
#import "GSMetajobs.h"
#import "GSLog.h"
#import "GSUserDefaults.h"

@implementation GSMain

static GSMain *_sharedMainController = nil;

#pragma mark Setup

+ (GSMain *)sharedMainController
{
	if ( _sharedMainController == nil )
		_sharedMainController = [[self alloc] init];
	return _sharedMainController;
}

+ (NSString *)defaultMetajobDirectory
{
	return [[[GSUserDefaults gstufferUserDefaults] objectForKey:@"MetajobsDirectory"] stringByExpandingTildeInPath];
}

- (id)init
{
	self = [super init];
	if ( self != nil ) {
		servers = [[GSServers alloc] init];
		metajobs = [[GSMetajobs alloc] init];
	}
	return self;
}

static argumentsParsed = NO;

- (BOOL)parseArgumentsWithArgc:(NSInteger)argc argv:(const char **)argv
{
	// parse can only be called once
	if ( argumentsParsed == YES ) {
		NSAssert1(0, @"arg parsing method %s should only be called once", _cmd);
		return NO;
	}
	argumentsParsed = YES;

	NSString *currentHostname = nil;
	NSString *currentPassword = nil;
	BOOL currentHostnameUsesKeychain = NO;
	NSString *interval = nil;
	NSString *file = nil;
	NSInteger verbose = 0;
	BOOL verboseSet = NO;

	NSInteger i = 0;
	BOOL success = YES;
	while ( ++i < argc ) {
		
		NSString *arg = [NSString stringWithUTF8String:argv[i]];
		
		// xgrid controller hostname
		if ( [arg isEqualToString:@"-h"] ) {
			i++;
			if ( i < argc ) {
				//save the current hostname, before starting a new one
				if ( currentHostname != nil )
					[servers addServerWithAddress:currentHostname password:currentPassword usingKeychain:currentHostnameUsesKeychain];
				//get ready for the next server
				currentPassword = nil;
				currentHostnameUsesKeychain = NO;
				currentHostname = [NSString stringWithUTF8String:argv[i]];
			}
			else
				success = NO;
		}
		
		// xgrid password w/o or w/ keychain storage
		else if ( [arg isEqualToString:@"-p"] || [arg isEqualToString:@"-k"] ) {
			i++;
			if ( i < argc ) {
				//set to the default hostname, in case no hostname was set
				currentPassword = [NSString stringWithUTF8String:argv[i]];
				if ( currentHostname == nil )
					currentHostname = @"localhost";
				if ( [arg isEqualToString:@"-k"] )
					currentHostnameUsesKeychain = YES;
			}
			else
				success = NO;
		}
		
		// interval = how often we should poll for new metajobs
		// IGNORED FOR NOW
		else if ( [arg isEqualToString:@"-i"] ) {
			i++;
			if ( i < argc )
				interval = [NSString stringWithUTF8String:argv[i]];
			else
				success = NO;
		}
		
		// interval = path to metajobs directory
		// IGNORED FOR NOW
		else if ( [arg isEqualToString:@"-m"] ) {
			i++;
			if ( i < argc )
				file = [NSString stringWithUTF8String:argv[i]];
			else
				success = NO;
		}
		if ( success == NO )
			break;

		else {
			if ( [arg length] < 2 || [[arg substringToIndex:1] isEqualToString:@"-"] == NO )
				success = NO;
			if ( [arg rangeOfString:@"v"].location != NSNotFound ) {
				verbose ++;
				verboseSet = YES;
			}
			if ( [arg rangeOfString:@"s"].location != NSNotFound ) {
				verbose --;
				verboseSet = YES;
			}
		}
	}
	
	if ( success == NO ) {
		[self printUsage];
		return NO;
	}
	
	//the last hostname needs to be added to the list, or the default used
	if ( currentHostname == nil )
		currentHostname = @"localhost";
	[servers addServerWithAddress:currentHostname password:currentPassword usingKeychain:currentHostnameUsesKeychain];
	
	// other parameters
	if ( interval != nil )
		[[GSUserDefaults gstufferUserDefaults] setObject:interval forParameterKey:@"MetajobsPollingTimeInterval"];
	if ( file != nil )
		[[GSUserDefaults gstufferUserDefaults] setObject:file forParameterKey:@"MetajobsDirectory"];
	if ( verboseSet == YES )
		[[GSUserDefaults gstufferUserDefaults] setObject:[NSNumber numberWithInteger:verbose] forParameterKey:@"GStufferVerboseLevel"];

	//display parameters
	if ( [[GSUserDefaults gstufferUserDefaults] integerForKey:@"GStufferVerboseLevel"] )
		[self printParameters];
		
	return YES;
}

- (void)printParameters
{
	GSLog (@"Starting gstuffer with the following parameters:\n");
	GSLog (@"Controllers: %s\n", [[[servers valueForKeyPath:@"servers.address"] description] UTF8String]);
	GSLog (@"Passwords  : %s\n", [[[servers valueForKeyPath:@"servers.serverHook.password"] description] UTF8String]);
	GSLog (@"    -i = %d\n", (int)([[GSUserDefaults gstufferUserDefaults] integerForKey:@"MetajobsPollingTimeInterval"]));
	GSLog (@"    -m = %@\n", [[GSUserDefaults gstufferUserDefaults] objectForKey:@"MetajobsDirectory"]);
	GSLog (@"    -v = %s\n", [[GSUserDefaults gstufferUserDefaults] integerForKey:@"GStufferVerboseLevel"]?"YES":"NO");
	GSLog (@"    -s = %s\n", [[GSUserDefaults gstufferUserDefaults] integerForKey:@"GStufferVerboseLevel"]?"NO":"YES");
	GSLog (@"\n");
}

- (void)printUsage
{
	printf ("gstuffer version 1.0\n");
	printf ("A command-line tool to submit Xgrid jobs using the metajob syntax\n");
	printf ("Created by Charles Parnot, July 2008\n");
	printf ("\n");
	printf ("usage: gstuffer [ [-h hostname] [-p password | -k password] ]* [-i interval] [-m file]\n");
	printf ("\n");
	printf ("Result: aggregated report status for all controllers listed,\n");
	printf ("        with optional details for each agent, grids and controller\n");
	printf ("\n");
	
	//controllers
	printf ("    -h hostname  Bonjour name or address of an xgrid controller\n");
	printf ("                 (default is localhost)\n");
	printf ("    -p password  client password, only needed if one was set.\n");
	printf ("                 A hostname is attributed the first password found\n");
	printf ("                 after it in the list of arguments, if any.\n");
	printf ("    -k password  when -k is used instead of the -p flag, the password\n");
	printf ("                 will be saved in the user default Keychain, if available.\n");
	printf ("                 Once a password is stored, it will always be tried and you\n");
	printf ("                 do not need to include it in subsequence connections.\n");
	printf ("                 The password is stored and may overwrite a previous value\n");
	printf ("                 even if the connection fails.\n");
	
	//output format
	printf ("    -i interval  interval used to pool the metajob directory, in seconds\n");
	printf ("                 NOT IMPLEMENTED\n");
	printf ("    -o file      path to the metajob directory\n");
	printf ("                 NOT IMPLEMENTED\n");
	printf ("    -v           verbose, opposite of silent\n");
	printf ("    -s           silent, opposite of verbose\n");
	printf ("    -h           Prints this message (if no hostname follows)\n");

	printf ("\n");
	exit (0);
}

//- (void)loadFactoryDefaults
//{
//	//get the app factory defaults from the file GridStufferFactoryDefaults.plist in the resources
//	verbose = 1;
//	GSLog(@"%s", _cmd);
//	GSLog(@"bundle: %@", [NSBundle mainBundle]);
//	GSLog(@"defaults file: %@",[[NSBundle mainBundle] pathForResource:@"gstufferFactoryDefaults" ofType:@"plist"]);
//	verbose = 0;
//	NSDictionary *factory=[[[NSDictionary alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"gstufferFactoryDefaults" ofType:@"plist"]] autorelease];
//	[[GSUserDefaults gstufferUserDefaults] registerDefaults:factory];
//	
//}

#pragma mark Properties


- (NSManagedObjectContext *)managedObjectContext
{
	return [GEZManager managedObjectContext];
}


#pragma mark Lifecycle

- (void)startMetajobPolling
{
	
}

- (void)start
{
	[servers start];
	[metajobs start];
}

- (void)stop
{
	//[self log:@"done"];
	[self save];
}

- (void)save
{
	GSLog(@"saving...");
    NSError *error = nil;
    if ( [[self managedObjectContext] save:&error] == NO ) {
		NSArray *detailedErrors = [[error userInfo] objectForKey:NSDetailedErrorsKey];
		unsigned numErrors = [detailedErrors count];
		NSMutableString *errorString = [NSMutableString stringWithFormat:@"%u validation errors have occurred:\n", numErrors];
		unsigned i;
		for (i = 0; i < numErrors; i++) {
			[errorString appendFormat:@"%@\n", [[detailedErrors objectAtIndex:i] localizedDescription]];
		}
		GSLog(@"Error while attempting to save:\n%@", error);
		GSLog(@"%s", errorString);
	}
	//save again if changes made - temporary fix for a limitation in GEZProxy - this needs to be addressed in the framework!!
	if ( [[self managedObjectContext] hasChanges] == YES && [[self managedObjectContext] save:&error] == NO ) 
			GSLog(@"Error while attempting to save:\n%@", error);
	GSLog(@"saving done");
}

@end
