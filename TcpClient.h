#import <Foundation/Foundation.h>
#import "TcpClientDelegate.h"

@interface TcpClient : NSObject {
    CFSocketRef _socket;
    NSString *_host;
    int _port;
    id<TcpClientDelegate> _delegate;
    CFRunLoopSourceRef _runLoopSource;
    BOOL _isConnected;
}

// Method declarations
- (id)init;
- (void)dealloc;
- (void)setDelegate:(id<TcpClientDelegate>)delegate;
- (id<TcpClientDelegate>)delegate;
- (void)setHost:(NSString *)host;
- (NSString *)host;
- (void)setPort:(int)port;
- (int)port;
- (BOOL)connect;
- (void)disconnect;
- (BOOL)sendData:(NSData *)data;
- (BOOL)isConnected;

@end
