#import "FTPBrowserController.h"
#import "FTPListParser.h"
#import "NetworkStatusEnum.h"

@interface FTPBrowserController (Private)
- (void)_loadDirectoryAtPath:(NSString *)path;
- (NSString *)_pathForColumn:(int)column;
NSMutableData *_downloadBuffer;
NSString *_downloadFilename;
@end

@implementation FTPBrowserController

- (void)_logBrowserState:(NSString *)context {
    NSLog(@"--------------------");
    NSLog(@"Browser State (%@)", context);
    NSLog(@"Selected column: %d", [_browser selectedColumn]);
    NSLog(@"Last column: %d", [_browser lastColumn]);
    NSLog(@"Current path components: %@", _currentPath);
    NSLog(@"Cache keys: %@", [_directoryCache allKeys]);
    NSLog(@"--------------------");
}

- (id)init {
	NSLog(@"BROWSER | init");
    self = [super init];
    if (self) {
        _ftpClient = nil;
        _directoryCache = [[NSMutableDictionary alloc] init];
        _currentPath = [[NSMutableArray alloc] init];
        _isLoading = NO;
        _downloadBuffer = [[NSMutableData alloc] init];
        _downloadFilename = nil;

        // Add root path
        [_currentPath addObject:@"/"];
    }
    return self;
}

- (void)dealloc {
	NSLog(@"BROWSER | dealloc");
    // Release retained objects
    [_ftpClient release];
    [_directoryCache release];
    [_currentPath release];
	[_browser release];
    [_downloadBuffer release];
    [_downloadFilename release];

    [super dealloc];
}

- (void)awakeFromNib {
	NSLog(@"BROWSER | awakeFromNib");
    // Configure browser
	[_browser retain];
    [_browser setDelegate:self];
    [_browser setMaxVisibleColumns:3];
    [_browser setAllowsMultipleSelection:NO];
    [_browser setAllowsEmptySelection:NO];
    [_browser setHasHorizontalScroller:YES];

    [_browser setDoubleAction:@selector(handleDoubleClick:)];

    // Load initial directory
    [self refresh];
}

- (void)setFTPClient:(FTPClient *)client {
	NSLog(@"BROWSER | setFTPClient %@ | _browser %@", client, _browser);
    if (_ftpClient != client) {
        [client retain];
        [_ftpClient release];
        _ftpClient = client;

        [_ftpClient setDelegate:self];
    }
}

- (void)refresh {
    // Clear cache and reload
    [_directoryCache removeAllObjects];
    [_currentPath removeAllObjects];
    [_currentPath addObject:@"/"];

    NSLog(@"BROWSER | refresh | _browser %@", _browser);
    [_browser loadColumnZero];
}

#pragma mark - Private Methods

- (void)_loadDirectoryAtPath:(NSString *)path {
    if (_isLoading) {
		NSLog(@"BROWSER | WARNING | _loadDirectoryAtPath(%@) already loading", path);
        return;
    }
    
    _isLoading = YES;
	
	NSLog(@"BROWSER | _loadDirectoryAtPath %@", path);
    
    // Check cache first
    NSArray *cachedListing = [_directoryCache objectForKey:path];
    if (cachedListing) {
		NSLog(@"BROWSER | _loadDirectoryAtPath | CACHE HIT %@", path);
        _isLoading = NO;
        return;
    }
    
    // Request directory listing from FTP client
    [_ftpClient listDirectory:path];
}

- (NSString *)_pathForColumn:(int)column {
    NSMutableString *path = [NSMutableString string];
    NSLog(@"BROWSER | _pathForColumn START");
    NSLog(@"  Column requested: %d", column);
    NSLog(@"  Current path array: %@", _currentPath);

    // Always start with root
    [path appendString:@"/"];

    // Don't include the root slash from _currentPath if it's there
    int startIndex = [[_currentPath objectAtIndex:0] isEqualToString:@"/"] ? 1 : 0;

    // Only process up to the requested column
    int endIndex = column + 1;
    if (endIndex > [_currentPath count]) {
        endIndex = [_currentPath count];
    }

    NSLog(@"  Processing components from index %d to %d", startIndex, endIndex);

    int i;
    for (i = startIndex; i < endIndex; i++) {
        NSString *component = [_currentPath objectAtIndex:i];

        // Skip empty components
        if ([component length] == 0) {
            continue;
        }

        // Skip if it's just a slash
        if ([component isEqualToString:@"/"]) {
            continue;
        }

        // Remove leading slash from component if present
        if ([component hasPrefix:@"/"]) {
            component = [component substringFromIndex:1];
        }

        // Add component with leading slash if needed
        if (![path hasSuffix:@"/"]) {
            [path appendString:@"/"];
        }
        [path appendString:component];
    }

    NSLog(@"  Final path: %@", path);
    NSLog(@"BROWSER | _pathForColumn END");
    return path;
}

- (void)ftpClient:(id)client didReceiveFileSize:(unsigned long long)size forFile:(NSString *)filename {
	[_downloadFilename release];
	_downloadFilename = [[filename lastPathComponent] retain];
	
    _currentFileSize = size;
    _downloadProgress = 0.0;

    // Format the size for display
    NSString *sizeString;
    if (size < 1024) {
        sizeString = [NSString stringWithFormat:@"%llu bytes", size];
    } else if (size < 1024 * 1024) {
        sizeString = [NSString stringWithFormat:@"%.1f KB", size / 1024.0];
    } else {
        sizeString = [NSString stringWithFormat:@"%.1f MB", size / (1024.0 * 1024.0)];
    }

    // Update the interface to show the starting download
//    NSString *filename = [_downloadFilename lastPathComponent];
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
        _downloadFilename, @"filename",
        sizeString, @"size",
        [NSNumber numberWithFloat:0.0], @"progress",
        nil];

    NSLog(@"BROWSER | didReceiveFileSize info (%@)", info);

    [[NSNotificationCenter defaultCenter] postNotificationName:@"downloadProgress"
                                                      object:self
                                                    userInfo:info];
}

- (void)ftpClient:(id)client didUpdateProgress:(double)progress bytesReceived:(unsigned long long)bytesReceived forFile:(NSString *)filename {
//	NSLog(@"BROWSER | didUpdateProgress | progress %.2f%% | forFile (%@):", progress * 100.0, filename);
	
	_downloadProgress = progress;

    // Calculate the amount downloaded
    NSString *progressString;

    if (bytesReceived < 1024ULL) {
        progressString = [NSString stringWithFormat:@"%llu bytes", bytesReceived];
    } else if (bytesReceived < 1024ULL * 1024ULL) {
		double kb = (double)bytesReceived / 1024.0;
        progressString = [NSString stringWithFormat:@"%.1f KB", kb];
    } else {
		double mb = (double)bytesReceived / (1024.0 * 1024.0);
        progressString = [NSString stringWithFormat:@"%.1f MB", mb];
    }

    // Update the interface with progress
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
        [_downloadFilename lastPathComponent], @"filename",
        progressString, @"downloaded",
        [NSNumber numberWithFloat:progress], @"progress",
        nil];

    NSLog(@"BROWSER | didUpdateProgress | progressString %@, info (%@)", progressString, info);

    [[NSNotificationCenter defaultCenter] postNotificationName:@"downloadProgress"
                                                      object:self
                                                    userInfo:info];
}

- (void)ftpClient:(id)client didReceiveData:(NSData *)data forFile:(NSString *)filename {
    if (!filename) return;

    // Only set filename if not already set
    if (!_downloadFilename) {
        [_downloadFilename release];
        _downloadFilename = [[filename lastPathComponent] retain];
        [_downloadBuffer setLength:0];
        NSLog(@"Starting download of file: %@", _downloadFilename);
    }

    // Append the data to our buffer
    [_downloadBuffer appendData:data];
//    NSLog(@"Received %d bytes of data", [data length]);

    // Check if this is the end of the transfer (data length of 0)
    if ([data length] == 0) {
        // Get user's home directory
        NSString *homeDir = NSHomeDirectory();

        // Construct path to Downloads folder
        NSString *downloadsPath = [homeDir stringByAppendingPathComponent:@"Downloads"];

        // Create Downloads directory if it doesn't exist
        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL isDirectory = NO;

        if (![fileManager fileExistsAtPath:downloadsPath isDirectory:&isDirectory]) {
            // Try to create Downloads directory
            if (![fileManager createDirectoryAtPath:downloadsPath attributes:nil]) {
                NSLog(@"Could not create Downloads directory, falling back to Documents");

                // Fall back to Documents directory
                downloadsPath = [homeDir stringByAppendingPathComponent:@"Documents"];

                // If somehow Documents doesn't exist either, use Desktop
                if (![fileManager fileExistsAtPath:downloadsPath isDirectory:&isDirectory]) {
                    downloadsPath = [homeDir stringByAppendingPathComponent:@"Desktop"];
                }
            }
        }

        // Create full save path
        NSString *savePath = [downloadsPath stringByAppendingPathComponent:_downloadFilename];

        // If file already exists, append a number to the filename
        int counter = 1;
        NSString *baseFilename = [[_downloadFilename stringByDeletingPathExtension] retain];
        NSString *extension = [[_downloadFilename pathExtension] retain];

        while ([fileManager fileExistsAtPath:savePath]) {
            NSString *newFilename;
            if ([extension length] > 0) {
                newFilename = [NSString stringWithFormat:@"%@ (%d).%@",
                             baseFilename, counter, extension];
            } else {
                newFilename = [NSString stringWithFormat:@"%@ (%d)",
                             baseFilename, counter];
            }
            savePath = [downloadsPath stringByAppendingPathComponent:newFilename];
            counter++;
        }

        [baseFilename release];
        [extension release];

        // Save the file
        if ([fileManager createFileAtPath:savePath contents:_downloadBuffer attributes:nil]) {
            NSLog(@"File saved successfully to: %@", savePath);

            // Notify the user where the file was saved
            NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                                savePath, @"path",
                                _downloadFilename, @"filename",
                                nil];

            [[NSNotificationCenter defaultCenter] postNotificationName:@"fileDownloaded"
                                                              object:self
                                                            userInfo:info];
        } else {
            NSLog(@"Error saving file to: %@", savePath);

            // Notify about the error
            NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"Could not save the downloaded file", @"error",
                                _downloadFilename, @"filename",
                                nil];

            [[NSNotificationCenter defaultCenter] postNotificationName:@"fileDownloadError"
                                                              object:self
                                                            userInfo:info];
        }

        // Clean up
        [_downloadBuffer setLength:0];
        [_downloadFilename release];
        _downloadFilename = nil;
        NSLog(@"Download complete and buffer cleared");
    }
}

- (void)ftpClientDidConnect:(id)client {
	NSLog(@"BROWSER | ftpClientDidConnect");
	
	NSNumber *numState = [NSNumber numberWithInt:NetworkStatusStateConnected];
	NSDictionary *connectionInfo = [NSDictionary dictionaryWithObjectsAndKeys:
		@"FTP Connected", @"update",
		numState, @"state",
		nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"connectionUpdate"
													object:self
												  userInfo:connectionInfo];
}
- (void)ftpClientDidDisconnect:(id)client {
	NSLog(@"BROWSER | ftpClientDidDisconnect");
	
	NSNumber *numState = [NSNumber numberWithInt:NetworkStatusStateDisconnected];
	NSDictionary *connectionInfo = [NSDictionary dictionaryWithObjectsAndKeys:
		@"FTP Disconnected", @"update",
		numState, @"state",
		nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"connectionUpdate"
													object:self
												  userInfo:connectionInfo];
}
- (void)ftpClientDidAuthenticate:(id)client {
	NSLog(@"BROWSER | ftpClientDidAuthenticate");
	[_ftpClient listDirectory:@""];
}

#pragma mark - NSBrowser Delegate Methods

- (int)browser:(NSBrowser *)sender numberOfRowsInColumn:(int)column {
    NSString *path = [self _pathForColumn:column];
    NSArray *listing = [_directoryCache objectForKey:path];

    if (!listing) {
        // If we don't have the listing yet, request it and show one row for "Loading..."
        [self _loadDirectoryAtPath:path];
        return 1;
    }

    return [listing count];
}

- (void)browser:(NSBrowser *)sender willDisplayCell:(id)cell atRow:(int)row column:(int)column {
	NSLog(@"BROWSER | willDisplayCell at row %d and column %d", row, column);
    NSString *path = [self _pathForColumn:column];
    NSArray *listing = [_directoryCache objectForKey:path];
	
//	NSLog(@"CELL | _directoryCache %@", _directoryCache);
//	NSLog(@"CELL | path %@ | listing %@", path, listing);

    if (!listing) {
        // Show loading state
        [cell setStringValue:@"Loading..."];
        [cell setLeaf:YES];
        return;
    }

    if (row < [listing count]) {
        NSDictionary *entry = [listing objectAtIndex:row];
        NSString *filename = [entry objectForKey:@"filename"];
        BOOL isDirectory = [[entry objectForKey:@"isDirectory"] boolValue];
		
		NSLog(@"CELL | filename %@", filename);

        [cell setStringValue:filename];
        [cell setLeaf:!isDirectory];

		/*
        // Set a different font for directories
        if (isDirectory) {
            NSFont *boldFont = [NSFont boldSystemFontOfSize:12.0];
            [cell setFont:boldFont];
        } else {
            NSFont *regularFont = [NSFont systemFontOfSize:12.0];
            [cell setFont:regularFont];
        }
		*/
		NSFont *regularFont = [NSFont systemFontOfSize:12.0];
		[cell setFont:regularFont];
    }
}

- (BOOL)browser:(NSBrowser *)sender selectRow:(int)row inColumn:(int)column {
    NSString *path = [self _pathForColumn:column];
    NSArray *listing = [_directoryCache objectForKey:path];
	
	[self _logBrowserState:@"Before selection"];

    if (!listing || row >= [listing count]) {
        return NO;
    }

    NSDictionary *entry = [listing objectAtIndex:row];
    BOOL isDirectory = [[entry objectForKey:@"isDirectory"] boolValue];

    // Update the path
    NSString *name = [entry objectForKey:@"name"];

    // Update current path array
    while ([_currentPath count] > column + 1) {
        [_currentPath removeLastObject];
    }
    [_currentPath addObject:name];

    // If this is a directory, preload the next column
    if (isDirectory) {
        NSString *newPath = [self _pathForColumn:column + 1];
        [self _loadDirectoryAtPath:newPath];
    }

    return YES;
}

- (NSString *)browser:(NSBrowser *)sender titleOfColumn:(int)column {
    if (column == 0) {
        return @"Root";
    }

    if (column < [_currentPath count]) {
        return [_currentPath objectAtIndex:column - 1];
    }

    return @"[unknown]";
}

- (BOOL)browser:(NSBrowser *)sender isColumnValid:(int)column {
    NSString *path = [self _pathForColumn:column];
    return [_directoryCache objectForKey:path] != nil;
}

id findEntryWithFilename(NSArray *array, NSString *filename) {
    NSEnumerator *enumerator = [array objectEnumerator];
    id entry;
	   
    while ((entry = [enumerator nextObject])) {
		if ([[entry valueForKey:@"filename"] isEqualToString:filename]) {
			return entry;
		}
	}
	return nil;
}

- (void)handleDoubleClick:(id)sender {
    NSLog(@"BROWSER | handleDoubleClick");

    NSString *path = [self _pathForColumn:[_browser selectedColumn]];
    NSString *selectedItem = [[_browser selectedCell] stringValue];

    if (selectedItem && [selectedItem isEqualToString:@"Loading..."]) return;

    // Only handle file downloads on double-click
    if ([[_browser selectedCell] isLeaf]) {
        NSString *fullPath = [NSString stringWithFormat:@"%@/%@", path, selectedItem];
        [_ftpClient downloadFile:fullPath];

/*
		NSArray *entries = [_directoryCache objectForKey:path];
		NSDictionary *entry = findEntryWithFilename(entries, selectedItem);

		[[NSNotificationCenter defaultCenter] postNotificationName:@"fileClicked"
															object:self
														  userInfo:entry];
*/
    }
}

- (void)browserSelectionDidChange:(id)sender {
    NSString *path = [self _pathForColumn:[_browser selectedColumn]];
    NSString *selectedItem = [[_browser selectedCell] stringValue];
	NSLog(@"BROWSER | browserSelectionDidChange | selectedItem %@", selectedItem);

    if (selectedItem && [selectedItem isEqualToString:@"Loading..."]) return;
	
	int selectedColumn = [_browser selectedColumn];
	int nextColumn = selectedColumn + 1;

    // Update current path
    while ([_currentPath count] > nextColumn) {
		NSLog(@"BROWSER | removing last object from (%@)", _currentPath);
        [_currentPath removeLastObject];
    }
	NSLog(@"BROWSER | adding object to _currentPath (%@)", selectedItem);
    [_currentPath addObject:selectedItem];

    // Load the next directory if this is a directory
    if (![[_browser selectedCell] isLeaf]) {
        NSString *newPath = [self _pathForColumn:nextColumn];
        [self _loadDirectoryAtPath:newPath];
	}
}

#pragma mark - FTPClientDelegate Methods

- (void)ftpClient:(id)client didReceiveDirectoryListing:(NSArray *)entries {
	NSLog(@"BROWSER | didReceiveDirectoryListing: %@", entries);
	
	[self _logBrowserState:@"Before adding new directory listing"];
	
    // Convert entries into dictionaries with name and isDirectory
    NSMutableArray *listing = [NSMutableArray array];
    NSEnumerator *enumerator = [entries objectEnumerator];
    NSString *entry;
    
    while ((entry = [enumerator nextObject])) {
//            // Skip . and .. entries
//            if ([name isEqualToString:@"."] || [name isEqualToString:@".."]) {
//                continue;
//            }
		
		NSDictionary *fileInfo = [FTPListParser dictionaryFromLine:entry];
		if (fileInfo) {
//			NSLog(@"BROWSER | didReceiveDirectoryListing: parsed fileInfo %@", fileInfo);
			[listing addObject:fileInfo];
		} else {
			NSLog(@"WARN | couldn't parse %@", entry);
		}
		
    }
	NSLog(@"BROWSER | listing %@", listing);
    
    // Store in cache
    NSString *path = [self _pathForColumn:[_browser selectedColumn]+1];
    [_directoryCache setObject:listing forKey:path];
	
	NSLog(@"BROWSER | added %d files/dirs to cache at path %@", [listing count], path);
	
//	NSLog(@"BROWSER | _directoryCache %@", _directoryCache);
    
    _isLoading = NO;
    
    // Reload the browser column
//	NSLog(@"BROWSER | reloadColumn %d", [_browser selectedColumn]);
	[_browser reloadColumn:[_browser lastColumn]];
//    [_browser reloadColumn:[_browser selectedColumn]+1];


	
	[self _logBrowserState:@"After adding new"];
}

- (void)ftpClient:(id)client didFailWithError:(NSError *)error {
	NSLog(@"BROWSER | fptClient didFailWithError %@", error);
	
    _isLoading = NO;
    
    // Show error in browser
	// FIXME: should maybe use the column method we defined here, not matrixInColumn
    NSBrowserCell *cell = [[_browser matrixInColumn:[_browser selectedColumn]] cellAtRow:0 column:0];
    [cell setStringValue:@"Error loading directory"];
    [cell setLeaf:YES];
}

@end
