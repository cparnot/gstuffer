//
//  MainController.h
//  gstuffer
//
//  Created by Charles Parnot on 7/11/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

/* Main Controller that takes care of the high-level setup, e.g. user defaults, core data stack, options, ... This is the equivalent of the AppDelegate for a GUI app */

#import <Cocoa/Cocoa.h>

@class GSServers;
@class GSMetajobs;

@interface GSMain : NSObject
{
	GSServers *servers;
	GSMetajobs *metajobs;
}

// singleton
+ (GSMain *)sharedMainController;

// properties
@property (readonly) NSManagedObjectContext *managedObjectContext;

// setup
- (BOOL)parseArgumentsWithArgc:(NSInteger)argc argv:(const char **)argv;
- (void)printUsage;
- (void)printParameters;
//- (void)loadFactoryDefaults;


// lifecycle
- (void)start;
- (void)stop;
- (void)save;

@end
