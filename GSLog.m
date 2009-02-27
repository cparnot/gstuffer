//
//  GSLog.m
//  gstuffer
//
//  Created by Charles Parnot on 7/15/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "GSLog.h"
#import "GSMain.h"
#import "GSUserDefaults.h"

@implementation GSLog

GSLog *_sharedLog = nil;

+ (GSLog *)sharedLog
{
	if ( _sharedLog == nil )
		_sharedLog = [[GSLog alloc] init];
	return _sharedLog;
}

- (void)logFormat:(NSString *)format, ...
{
	if ( [[GSUserDefaults gstufferUserDefaults] integerForKey:@"GStufferVerboseLevel"] < 1 )
		return;
    va_list ap;
    va_start(ap,format);
	
	NSLogv(format, ap);
	//NSString *message = [[[NSString alloc] initWithFormat:format arguments:ap] autorelease];
	//printf("%s\n", [message UTF8String]);
}

@end
