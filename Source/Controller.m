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

- (void)setConnectionLightState:(NetworkStatusState)state {
	NSString *fileName;
	switch (state) {
		case NetworkStatusStateConnected:
			fileName = @"status-available";
			break;
		case NetworkStatusStateDisconnected:
			fileName = @"status-away";
			break;
		case NetworkStatusStateWaiting:
			fileName = @"status-idle";
			break;
		case NetworkStatusStateOff:
			fileName = @"status-offline";
			break;

	}
	NSString *file = [[NSBundle mainBundle] pathForResource:fileName ofType:@"tiff"];
	NSImage *image = [[NSImage alloc] initWithContentsOfFile:file];
	[connectionStatusImageView setImage:image];
}

- (IBAction)onClick:(id)sender {
	[_client setHost:[hostField stringValue]];
	[_client setPort:[portField intValue]];

	if (![_client isConnected]) {
		[_client connect];
		[connectionStatusTextField setStringValue:@"Connecting..."];
	} else {
		[_client disconnect];
	}
}

// TcpClientDelegate methods
- (void)tcpClientDidConnect:(id)client {
	[connectButton setTitle:@"Disconnect"];
	[connectionStatusTextField setStringValue:@"Connected"];
	[self setConnectionLightState:NetworkStatusStateConnected];

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
	[self setConnectionLightState:NetworkStatusStateDisconnected];
	[connectButton setTitle:@"Connect"];
	[connectionStatusTextField setStringValue:@"Disconnected"];
}

- (void)tcpClientDidDisconnect:(id)client {
	[self setConnectionLightState:NetworkStatusStateDisconnected];
	[connectButton setTitle:@"Connect"];
	[connectionStatusTextField setStringValue:@"Disconnected"];
}
@end
