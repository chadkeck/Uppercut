#import "NetworkStatusController.h"

@implementation NetworkStatusController

- (void)setConnectionState:(NetworkStatusState)state {
	NSString *fileName;
	NSString *status;
	switch (state) {
		case NetworkStatusStateConnected:
			fileName = @"status-available";
			status = @"Connected";
			break;
		case NetworkStatusStateDisconnected:
			fileName = @"status-away";
			status = @"Disconnected";
			break;
		case NetworkStatusStateWaiting:
			fileName = @"status-idle";
			status = @"Connecting...";
			break;
		case NetworkStatusStateOff:
			fileName = @"status-offline";
			status = @"Offline";
			break;
	}
	NSString *file = [[NSBundle mainBundle] pathForResource:fileName ofType:@"tiff"];
	NSImage *image = [[NSImage alloc] initWithContentsOfFile:file];
	[connectionStatusImageView setImage:image];
	[connectionStatusTextField setStringValue:status];
}

@end
