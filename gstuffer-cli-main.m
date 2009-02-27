
#import <Foundation/Foundation.h>
#import "GSMain.h"
#import "GSUserDefaults.h"

int main (int argc, const char * argv[])
{
	
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	BOOL success = [[GSMain sharedMainController] parseArgumentsWithArgc:argc argv:argv];
	
	if ( success == YES ) {
		[[GSMain sharedMainController] start];
		double processDuration = [[GSUserDefaults gstufferUserDefaults] doubleForKey:@"ProcessDurationTimeInterval"];
		[[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:processDuration]];
		[[GSMain sharedMainController] stop];
	}
		
    [pool drain];
    return 0;
}
