#import <Foundation/Foundation.h>
#import "IRCClientDelegate.h"
#import "TCPClient.h"

@interface IRCClient : NSObject {
    TCPClient *_client;
    NSString *_host;
    int _port;
    BOOL _isConnected;
	NSTimer *_debounceTimer;
	id<IRCClientDelegate> _delegate;
}

// Method declarations
- (id)init;
- (void)dealloc;

- (void)setHost:(NSString *)host;
- (NSString *)host;
- (void)setPort:(int)port;
- (int)port;

- (BOOL)connect;
- (void)disconnect;
- (BOOL)sendMessage:(NSString *)message;
- (BOOL)isConnected;

#pragma mark - Private
- (NSString *)_getRandomNick;
- (NSString *)_getRandomUser;
- (NSString *)_getRandomString:(int)length;
- (BOOL)answerPing:(NSString *)pingMessage;

#pragma mark - IRCClientDelegate
- (void)setDelegate:(id<IRCClientDelegate>)delegate;

#pragma mark - TCPClientDelegate
- (void)tcpClientDidConnect:(id)client;
- (void)tcpClient:(id)client didReceiveData:(NSData *)data;
- (void)tcpClient:(id)client didFailWithError:(NSError *)error;
- (void)tcpClientDidDisconnect:(id)client;

@end
