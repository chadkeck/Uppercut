#import <Cocoa/Cocoa.h>
#import "FTPClient.h"

@interface FTPBrowserController : NSObject <FTPClientDelegate> {
    IBOutlet NSBrowser *_browser;
    FTPClient *_ftpClient;
	
	NSString *_downloadDirectory;

    // Cache for directory listings
    NSMutableDictionary *_directoryCache;

    // Track current path components
    NSMutableArray *_currentPath;

    // Loading state
    BOOL _isLoading;
}

- (id)init;
- (void)dealloc;

#pragma mark - Public methods
- (void)connectToFTP:(NSString *)host withUsername:(NSString *)username password:(NSString *)password;
- (void)refresh;
- (void)setDownloadDirectory:(NSString *)directory;
- (void)cancelCurrentDownload;

#pragma mark - UI Actions
- (IBAction)browserSelectionDidChange:(id)sender;

#pragma mark - FTPClientDelegate
- (void)ftpClient:(id)client didReceiveDirectoryListing:(NSArray *)entries;
- (void)ftpClient:(id)client didReceiveData:(NSData *)data forFile:(NSString *)filename;
- (void)ftpClient:(id)client didReceiveFileSize:(unsigned long long)size forFile:(NSString *)filename;
- (void)ftpClient:(id)client didUpdateProgress:(double)progress bytesReceived:(unsigned long long)bytesReceived forFile:(NSString *)filename;
- (void)ftpClient:(id)client didFailWithError:(NSError *)error;
- (void)ftpClientDidConnect:(id)client;
- (void)ftpClientDidDisconnect:(id)client;
- (void)ftpClientDidAuthenticate:(id)client;

#pragma mark - Private
- (void)_cleanupDownload;

@end
