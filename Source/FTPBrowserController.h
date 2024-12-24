#import <Cocoa/Cocoa.h>
#import "FTPClient.h"

@interface FTPBrowserController : NSObject <FTPClientDelegate> {
    IBOutlet NSBrowser *_browser;
    FTPClient *_ftpClient;

    // Cache for directory listings
    NSMutableDictionary *_directoryCache;

    // Track current path components
    NSMutableArray *_currentPath;

    // Loading state
    BOOL _isLoading;
}

- (id)init;
- (void)dealloc;

// Public methods
- (void)setFTPClient:(FTPClient *)client;
- (void)refresh;

// Actions
- (IBAction)browserSelectionDidChange:(id)sender;

#pragma mark - FTPClientDelegate
- (void)ftpClient:(id)client didReceiveDirectoryListing:(NSArray *)entries;
- (void)ftpClient:(id)client didReceiveData:(NSData *)data forFile:(NSString *)filename;
- (void)ftpClient:(id)client didFailWithError:(NSError *)error;
- (void)ftpClientDidConnect:(id)client;
- (void)ftpClientDidDisconnect:(id)client;
- (void)ftpClientDidAuthenticate:(id)client;

@end
