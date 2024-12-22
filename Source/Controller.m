#import "Controller.h"
#import "Logger.h"

@implementation Controller

- (void)awakeFromNib {
	_client = [[TCPClient alloc] init];
	[_client setDelegate:self];
	[_client setHost:@"localhost"];
	[_client setPort:1234];
	
	// FIXME: there must be a better place to put this, like applicationDidFinishLaunching
	[[Logger sharedInstance] log:@"Uppercut started"];
}

- (void)dealloc {
	[_client release];
	[super dealloc];
}

- (IBAction)onClickConnect:(id)sender {
	NSString *host = [hostField stringValue];
	int port = [portField intValue];
	
	// TODO: some validation on host and port
	
	[_client setHost:[hostField stringValue]];
	[_client setPort:[portField intValue]];
	
	if (![_client isConnected]) {
		[[Logger sharedInstance] log:[NSString stringWithFormat:@"Connecting to %@:%d", host, port]];

		[_client connect];
		[networkStatusController setConnectionState:NetworkStatusStateWaiting];
	} else {
		[_client disconnect];
	}
}

- (IBAction)onClickSendData:(id)sender {
	NSLog(@"send data clicked");
	
	if (![_client isConnected]) {
		return;
	}
		
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
	[[Logger sharedInstance] log:@"Connected"];
	
	[connectButton setTitle:@"Disconnect"];
	[hostField setEnabled:FALSE];
	[portField setEnabled:FALSE];
	[networkStatusController setConnectionState:NetworkStatusStateConnected];

}

- (void)tcpClient:(id)client didReceiveData:(NSData *)data {
	NSString *message = [[NSString alloc] initWithData:data 
											  encoding:NSUTF8StringEncoding];

	// check for disconnect
	if ([data length] == 0) {
		[self tcpClientDidDisconnect:client];
	} else {
		[[Logger sharedInstance] log:[NSString stringWithFormat:@"Received message: %@", message]];
	
		[dataTextView setString:message];
	}
	
	[message release];
}

- (void)tcpClient:(id)client didFailWithError:(NSError *)error {
	NSLog(@"Connection failed with error: %@", error);
	[[Logger sharedInstance] log:[NSString stringWithFormat:@"Connection failed with error: %@", error]];

	[connectButton setTitle:@"Connect"];
	[hostField setEnabled:TRUE];
	[portField setEnabled:TRUE];
	[networkStatusController setConnectionState:NetworkStatusStateDisconnected];
}

- (void)tcpClientDidDisconnect:(id)client {
	[[Logger sharedInstance] log:@"Disconnected"];
	
	[connectButton setTitle:@"Connect"];
	[hostField setEnabled:TRUE];
	[portField setEnabled:TRUE];
	[networkStatusController setConnectionState:NetworkStatusStateDisconnected];
}
@end
