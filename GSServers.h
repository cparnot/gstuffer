//
//  servers.h
//  gstuffer
//
//  Created by Charles Parnot on 7/14/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface GSServers : NSObject 
{
	NSMutableSet *servers;
	NSMutableDictionary *passwords;
}


- (void)addServerWithAddress:(NSString *)address password:(NSString *)password usingKeychain:(BOOL)shouldUseKeychain;
- (void)start;
- (void)stop;

@end
