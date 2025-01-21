#import <Cocoa/Cocoa.h>
#import "IRCClient.h"

@interface InitialConnectionController : NSObject {
	IBOutlet NSProgressIndicator *spinner;
	IBOutlet NSTextField *statusTextField;
	IBOutlet NSButton *connectButton;

	IRCClient *_ircClient;
	BOOL _isConnecting;
}

#pragma mark - Public
- (void)reset;
- (void)showFailureStateWithMessage:(NSString *)message;

#pragma mark - UI Actions
- (IBAction)onClickConnect:(id)sender;

#pragma mark - Private
- (void)_installObservers;
- (void)_connectToEfnet;
- (void)_handleConnectionUpdate:(NSNotification *)notification;

@end
