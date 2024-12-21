#import "Controller.h"

@implementation Controller

- (void)awakeFromNib {
	_client = [[TCPClient alloc] init];
	[_client setDelegate:self];
	[_client setHost:@"localhost"];
	[_client setPort:1234];
}

- (void)dealloc {
	[_client release];
	[super dealloc];
}

- (IBAction)onClick:(id)sender {
	[_client setHost:[hostField stringValue]];
	[_client setPort:[portField intValue]];

	if (![_client isConnected]) {
		[_client connect];
		[networkStatusController setConnectionState:NetworkStatusStateWaiting];
	} else {
		[_client disconnect];
	}
}

// TCPClientDelegate methods
- (void)tcpClientDidConnect:(id)client {
	[connectButton setTitle:@"Disconnect"];
	[networkStatusController setConnectionState:NetworkStatusStateConnected];
	
	// Example of sending data
	NSString *message = @"Hello, server!";
	NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
	[_client sendData:data];
}

- (void)tcpClient:(id)client didReceiveData:(NSData *)data {
	NSString *message = [[NSString alloc] initWithData:data 
											  encoding:NSUTF8StringEncoding];
	NSLog(@"Received message: %@", message);
	[message release];
}

- (void)tcpClient:(id)client didFailWithError:(NSError *)error {
	NSLog(@"Connection failed with error: %@", error);
	[connectButton setTitle:@"Connect"];
	[networkStatusController setConnectionState:NetworkStatusStateDisconnected];
}

- (void)tcpClientDidDisconnect:(id)client {
	[connectButton setTitle:@"Connect"];
	[networkStatusController setConnectionState:NetworkStatusStateDisconnected];
}
@end
