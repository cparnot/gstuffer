//
//  GSLog.h
//  gstuffer
//
//  Created by Charles Parnot on 7/15/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// convenience macro
#define GSLog(format, args...) [[GSLog sharedLog] logFormat:format, ## args]

@interface GSLog : NSObject {

}

+ (GSLog *)sharedLog;
- (void)logFormat:(NSString *)format, ...;

@end
