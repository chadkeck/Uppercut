#import "Controller.h"

@implementation Controller

- (void)awakeFromNib {
	_client = [[TcpClient alloc] init];
	[_client setDelegate:self];
	[_client setHost:@"localhost"];
	[_client setPort:1234];
}

- (void)dealloc {
	[_client release];
	[super dealloc];
}

- (IBAction)onClick:(id)sender {
	//NSLog(@"click: %@", [textField stringValue]);
	[textField setStringValue:@"Hello, World"];
	
	[_client setHost:[hostField stringValue]];
	[_client setPort:[portField intValue]];

	if (![_client isConnected]) {
		[_client connect];
		[connectButton setTitle:@"Connecting..."];
	} else {
		[_client disconnect];
	}
}

// TcpClientDelegate methods
- (void)tcpClientDidConnect:(id)client {
	[connectButton setTitle:@"Disconnect"];

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
}

- (void)tcpClientDidDisconnect:(id)client {
	[connectButton setTitle:@"Connect"];
}
@end
