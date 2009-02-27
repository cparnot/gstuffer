//
//  servers.m
//  gstuffer
//
//  Created by Charles Parnot on 7/14/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "GSServers.h"
#import "GSLog.h"

@implementation GSServers

- (id)init
{
	self = [super init];
	if ( self != nil ) {
		servers = [[NSMutableSet alloc] init];
		passwords = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[self stop];
	[servers release];
	[passwords release];
	[super dealloc];
}

#pragma mark Setup

- (void)addServerWithAddress:(NSString *)address password:(NSString *)password usingKeychain:(BOOL)shouldUseKeychain
{
	GEZServer *server = [GEZServer serverWithAddress:address];
	if ( password != nil )
		[passwords setObject:password forKey:address];
	if ( shouldUseKeychain )
		[server setShouldStorePasswordInKeychain:YES];
	[servers addObject:server];
}

- (void)start
{
	GSLog(@"initiating connections to %d xgrid controllers...", [servers count]);
	for ( GEZServer *server in servers ) {
		GSLog(@"initiating connection to '%@' ...", [server address]);
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverWillConnect:) name:GEZServerWillAttemptConnectionNotification object:server];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverDidConnect:) name:GEZServerDidConnectNotification object:server];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverDidLoad:) name:GEZServerDidLoadNotification object:server];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverDidNotConnect:) name:GEZServerDidNotConnectNotification object:server];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverDidDisconnect:) name:GEZServerDidDisconnectNotification object:server];
		NSString *password = [passwords objectForKey:[server address]];
		if ( password != nil )
			[server connectWithPassword:password];
		else
			[server connect];
	}
	GSLog(@"waiting for connections...");
}


- (void)stop
{
	GSLog(@"disconnecting from all %d xgrid controllers...", [servers count]);
	[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:nil];
	for ( GEZServer *server in servers ) {
		GSLog(@"disconnecting '%@' ...", [server address]);
		[server disconnect];
	}
}

#pragma mark Servers

- (void)serverWillConnect:(NSNotification *)notification
{
	GSLog(@"%@ %s", [[notification object] address], _cmd);
}

- (void)serverDidConnect:(NSNotification *)notification
{
	GSLog(@"%@ %s", [[notification object] address], _cmd);
}

- (void)serverDidLoad:(NSNotification *)notification
{
	GSLog(@"%@ %s", [[notification object] address], _cmd);
}

- (void)serverDidNotConnect:(NSNotification *)notification
{
	GSLog(@"%@ %s", [[notification object] address], _cmd);
}

- (void)serverDidDisconnect:(NSNotification *)notification
{
	GSLog(@"%@ %s", [[notification object] address], _cmd);
}


@end
