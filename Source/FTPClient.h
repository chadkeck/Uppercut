#import <Foundation/Foundation.h>
#import <CFNetwork/CFNetwork.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import "FTPClientDelegate.h"

typedef enum {
    FTPModeActive,
    FTPModePassive
} FTPMode;

typedef enum {
    FTPTransferTypeASCII,
    FTPTransferTypeBinary
} FTPTransferType;

@interface FTPClient : NSObject {
    CFReadStreamRef commandStream;
    CFWriteStreamRef commandWriteStream;
    CFReadStreamRef dataStream;
    CFWriteStreamRef dataWriteStream;
    CFSocketRef listenSocket;
    
    NSString *hostname;
    int commandPort;
    int dataPort;
	NSString *username;
	NSString *password;
    FTPMode mode;
    FTPTransferType transferType;
    
    id<FTPClientDelegate> delegate;
    BOOL isConnected;
	BOOL isAuthenticated;
    NSMutableData *receivedData;
    NSMutableData *fileData;
    
    NSString *currentDirectory;
    NSString *pendingFilename;
}

- (id)initWithHostname:(NSString *)host port:(int)portNumber username:(NSString *)user password:(NSString *)pass mode:(FTPMode)ftpMode;
- (void)setDelegate:(id<FTPClientDelegate>)aDelegate;
- (BOOL)connect;
- (void)disconnect;
- (void)authenticate;
- (BOOL)sendCommand:(NSString *)command;
- (void)setTransferType:(FTPTransferType)type;
- (void)changeToDirectory:(NSString *)directory;
- (void)listDirectory;
- (void)downloadFile:(NSString *)filename;

@end
