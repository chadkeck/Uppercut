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
	
	float _downloadProgress;
	unsigned long long _currentFileSize;
}

- (id)init;
- (void)dealloc;

// Public methods
- (void)setFTPClient:(FTPClient *)client;
- (void)refresh;
- (void)setDownloadDirectory:(NSString *)directory;

// Actions
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

@end
