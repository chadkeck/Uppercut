#import "Controller.h"
#import "Logger.h"

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

- (IBAction)onClickConnect:(id)sender {	
	[_client setHost:[hostField stringValue]];
	[_client setPort:[portField intValue]];

	if (![_client isConnected]) {
		[_client connect];
		[networkStatusController setConnectionState:NetworkStatusStateWaiting];
	} else {
		[_client disconnect];
	}
}

- (IBAction)onClickSendData:(id)sender {
	NSLog(@"send data clicked");
		
	// send data
	NSString *message = [[sendDataTextField stringValue] stringByAppendingString:@"\r\n"];
	NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
	[_client sendData:data];
	[[Logger sharedInstance] log:[NSString stringWithFormat:@"Sent message: %@", message]];
	
	// clear the input field
	[sendDataTextField setStringValue:@""];
}

// TCPClientDelegate methods
- (void)tcpClientDidConnect:(id)client {
	[connectButton setTitle:@"Disconnect"];
	[hostField setEnabled:FALSE];
	[portField setEnabled:FALSE];
	[networkStatusController setConnectionState:NetworkStatusStateConnected];

}

- (void)tcpClient:(id)client didReceiveData:(NSData *)data {
	NSString *message = [[NSString alloc] initWithData:data 
											  encoding:NSUTF8StringEncoding];
	NSLog(@"Received message: %@", message);
	
	[dataTextView setString:message];
	
	[message release];
}

- (void)tcpClient:(id)client didFailWithError:(NSError *)error {
	NSLog(@"Connection failed with error: %@", error);
	[connectButton setTitle:@"Connect"];
	[hostField setEnabled:TRUE];
	[portField setEnabled:TRUE];
	[networkStatusController setConnectionState:NetworkStatusStateDisconnected];
}

- (void)tcpClientDidDisconnect:(id)client {
	[connectButton setTitle:@"Connect"];
	[hostField setEnabled:TRUE];
	[portField setEnabled:TRUE];
	[networkStatusController setConnectionState:NetworkStatusStateDisconnected];
}
@end
