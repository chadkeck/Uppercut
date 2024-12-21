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

	if (![_client isConnected]) {
		[_client connect];
	} else {
		[_client disconnect];
	}
}

// TcpClientDelegate methods
- (void)tcpClientDidConnect:(id)client {
//   [_connectButton setTitle:@"Disconnect"];

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
//	[_connectButton setTitle:@"Connect"];
}

- (void)tcpClientDidDisconnect:(id)client {
//	  [_connectButton setTitle:@"Connect"];
}
@end
