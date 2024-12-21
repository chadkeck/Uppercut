#import <Cocoa/Cocoa.h>

#import "NetworkStatusEnum.h"

@interface NetworkStatusController : NSObject {
	IBOutlet NSTextField *connectionStatusTextField;
	IBOutlet NSImageView *connectionStatusImageView;
}

- (void)setConnectionState:(NetworkStatusState)state;

@end
