#import <Foundation/Foundation.h>
#import "TCPClient.h"
#import "FTPClientDelegate.h"

typedef enum {
    FTPTransferModeActive = 0,
    FTPTransferModePassive = 1
} FTPTransferMode;

@interface FTPClient : NSObject <TCPClientDelegate> {
    TCPClient *_commandClient;  // For FTP commands
    TCPClient *_dataClient;     // For data transfers

    NSString *_host;
    int _port;
    NSString *_username;
    NSString *_password;

    BOOL _isConnected;
    BOOL _isAuthenticated;
	BOOL _isCancelled;
    FTPTransferMode _transferMode;

    // For parsing responses
    NSMutableString *_responseBuffer;
	
	NSString *_currentFile;

    id<FTPClientDelegate> _delegate;
}

// Initialization and cleanup
- (id)init;
- (void)dealloc;

// Connection settings
- (void)setHost:(NSString *)host;
- (NSString *)host;
- (void)setPort:(int)port;
- (int)port;
- (void)setUsername:(NSString *)username;
- (void)setPassword:(NSString *)password;
- (void)setTransferMode:(FTPTransferMode)mode;

// Connection management
- (BOOL)connect;
- (void)disconnect;
- (BOOL)isConnected;
- (void)cancelCurrentTransfer;

// FTP Commands
- (void)authenticate;
- (void)listDirectory:(NSString *)path;
- (void)changeDirectory:(NSString *)path;
- (void)downloadFile:(NSString *)path;
- (void)abortTransfer;

// Delegate
- (void)setDelegate:(id<FTPClientDelegate>)delegate;

// Private
- (void)_notifyAbortComplete;

@end

