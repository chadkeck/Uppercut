#import "InitialConnectionController.h"

@implementation InitialConnectionController

NSString *kConnectButtonText = @"Connect to xbins";
NSString *kConnectButtonCancelText = @"Cancel";

- (void)awakeFromNib {
	_ircClient = [[IRCClient alloc] init];
	_isConnecting = NO;
	
	[spinner setHidden:YES];
	[statusTextField setHidden:YES];
	
	[self _installObservers];
}

- (void)dealloc {
	[_ircClient release];
	
	[super dealloc];
}

- (void)_installObservers {
	[[NSNotificationCenter defaultCenter] addObserver:self
											selector:@selector(_handleConnectionUpdate:)
												name:@"connectionUpdate"
											  object:nil];
}

- (void)showFailureStateWithMessage:(NSString *)message {
	_isConnecting = NO;
	[spinner setHidden:YES];
	[statusTextField setHidden:NO];
	[statusTextField setStringValue:message];
	[connectButton setTitle:kConnectButtonText];
}

- (void)reset {
	_isConnecting = NO;
	[spinner setHidden:YES];
	[statusTextField setHidden:YES];
	[statusTextField setStringValue:@""];
	[connectButton setTitle:kConnectButtonText];
}

- (void)_handleConnectionUpdate:(NSNotification *)notification {
	NSDictionary *connectionInfo = [notification userInfo];
	NSLog(@"INITIAL CONNECTION CONTROLLER | Received 'connectionUpdate' with %@", connectionInfo);
//	NSNumber *numState = [connectionInfo objectForKey:@"state"];
	NSString *update = [connectionInfo objectForKey:@"update"];

	[spinner startAnimation:nil];
	[spinner setHidden:NO];
	
	[statusTextField setHidden:NO];
	[statusTextField setStringValue:update];
}


- (IBAction)onClickConnect:(id)sender {
	if (!_isConnecting) {
		_isConnecting = YES;
		[self _connectToEfnet];
		[connectButton setTitle:kConnectButtonCancelText];
	} else {
		[_ircClient disconnect];
		[self reset];
	}
}

- (void)_connectToEfnet {
    NSArray *efnetServers = [NSArray arrayWithObjects:
		@"irc.efnet.nl", // banned
		@"irc.deft.com", // banned
		@"irc.servercentral.net",
		@"irc.underworld.no",
		@"efnet.port80.se", // fails to resolve hostname
		@"efnet.deic.eu",
		@"irc.swepipe.se",
		@"irc.efnet.fr",
		@"irc.choopa.net",
		nil];

	int randomIndex = arc4random() % [efnetServers count];
	[_ircClient setHost:[efnetServers objectAtIndex:randomIndex]];
	[_ircClient setPort:6667];
	BOOL connectOk = [_ircClient connect];
	if (!connectOk) {
		[self performSelectorOnMainThread:@selector(showFailureStateWithMessage:) 
                withObject:@"Failed to connect. Try again." waitUntilDone:NO];
//		[self showFailureStateWithMessage:@"Failed to connect. Try again."];
	}
}

@end
