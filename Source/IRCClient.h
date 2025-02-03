#import <Foundation/Foundation.h>
#import "TCPClient.h"
#import "DelayedMessage.h"

@interface IRCClient : NSObject <TCPClientDelegate> {
    TCPClient *_tcpClient;
    NSString *_host;
    int _port;
    BOOL _isConnected;
	NSString *_pendingMessage;
}

#pragma mark - Getters/setters
- (id)init;
- (void)dealloc;

- (void)setHost:(NSString *)host;
- (NSString *)host;
- (void)setPort:(int)port;
- (int)port;

#pragma mark - Connection
- (BOOL)connect;
- (void)disconnect;
- (BOOL)isConnected;

#pragma mark - Private
- (NSString *)_getRandomNick;
- (NSString *)_getRandomUser;
- (NSString *)_getRandomString:(int)length;
- (BOOL)_sendMessage:(NSString *)message;
- (BOOL)_answerPing:(NSString *)pingMessage;
- (void)_sendConnectionUpdate:(NSString *)update withState:(NSNumber *)state;
- (BOOL)_processPrivateMessage:(NSString *)message;
- (NSDictionary *)_getFTPConnectionDetails:(NSString *)message;
- (void)_sendMessageWithDelay:(NSString *)message;

#pragma mark - TCPClientDelegate
- (void)tcpClientDidConnect:(id)client;
- (void)tcpClient:(id)client didReceiveData:(NSData *)data;
- (void)tcpClient:(id)client didFailWithError:(NSError *)error;
- (void)tcpClientDidDisconnect:(id)client;

@end
