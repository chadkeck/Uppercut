#import "AppDelegate.h"
#import "Logger.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	[[Logger sharedInstance] log:@"Uppercut started"];
}

@end
