#import "InitialConnectionController.h"

@implementation InitialConnectionController

- (void)awakeFromNib {
	_ircClient = [[IRCClient alloc] init];
	
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

- (void)reset {
	[spinner setHidden:YES];
	[statusTextField setHidden:YES];
	[statusTextField setStringValue:@""];
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
	[self _connectToEfnet];
	
	// TODO change connect button to Cancel and implement handler to cancel
	// connection
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
	[_ircClient connect];
}

@end
