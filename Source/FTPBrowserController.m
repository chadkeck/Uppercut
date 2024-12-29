#import "FTPBrowserController.h"
#import "FTPListParser.h"

@interface FTPBrowserController (Private)
- (void)_loadDirectoryAtPath:(NSString *)path;
- (NSString *)_pathForColumn:(int)column;
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
    
    // Load initial directory
    [self refresh];
}

- (void)setFTPClient:(FTPClient *)client {
	NSLog(@"BROWSER | setFTPClient %@ | _browser %@", client, _browser);
    if (_ftpClient != client) {
        [client retain];
        [_ftpClient release];
        _ftpClient = client;
        
        // Set ourselves as the delegate
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
    int i;

    // Build path from components up to this column
    for (i = 0; i <= column && i < [_currentPath count]; i++) {
        [path appendString:[_currentPath objectAtIndex:i]];
        if (i < column && ![[path substringFromIndex:[path length] - 1] isEqualToString:@"/"]) {
            [path appendString:@"/"];
        }
    }
	NSLog(@"BROWSER | _pathForColumn(%d) returns %@", column, path);
    return path;
}


- (void)ftpClient:(id)client didReceiveData:(NSData *)data forFile:(NSString *)filename {
//	NSLog(@"BROWSER | ftpClient didReceiveData: %@ for file %@", data, filename);
}
- (void)ftpClientDidConnect:(id)client {
	NSLog(@"BROWSER | ftpClientDidConnect");
}
- (void)ftpClientDidDisconnect:(id)client {
	NSLog(@"BROWSER | ftpClientDidDisconnect");
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
	} else {
		NSArray *entries = [_directoryCache objectForKey:path];
		NSDictionary *entry = findEntryWithFilename(entries, selectedItem);

		[[NSNotificationCenter defaultCenter] postNotificationName:@"fileClicked"
															object:self
														  userInfo:entry];
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
