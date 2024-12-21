#import <Foundation/Foundation.h>
#import "TCPClientDelegate.h"

@interface TCPClient : NSObject {
    CFSocketRef _socket;
    NSString *_host;
    int _port;
    id<TCPClientDelegate> _delegate;
    CFRunLoopSourceRef _runLoopSource;
    BOOL _isConnected;
}

// Method declarations
- (id)init;
- (void)dealloc;
- (void)setDelegate:(id<TCPClientDelegate>)delegate;
- (id<TCPClientDelegate>)delegate;
- (void)setHost:(NSString *)host;
- (NSString *)host;
- (void)setPort:(int)port;
- (int)port;
- (BOOL)connect;
- (void)disconnect;
- (BOOL)sendData:(NSData *)data;
- (BOOL)isConnected;

@end
