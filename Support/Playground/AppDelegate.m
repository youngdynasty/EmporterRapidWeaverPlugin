//
//  AppDelegate.m
//  EmporterRapidWeaverPlayground
//
//  Created by Mike Pulaski on 26/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "AppDelegate.h"
#import "ERPreviewServerManager.h"
#import "ERMainViewController.h"
#import "Emporter.h"


@interface AppDelegate ()
@property (weak) IBOutlet NSWindow *window;
@end


@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSURL *directoryURL = [self _documentTempDirectoryURL];
    if (directoryURL == nil) {
        [NSApp terminate:nil];
    }
    
    ERTunnel *tunnel = [[ERTunnel alloc] initWithTempDocumentDirectoryURL:directoryURL];
    _window.contentViewController = [[ERMainViewController alloc] initWithTunnel:tunnel document:nil];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (NSURL *)_documentTempDirectoryURL {
    NSURL *directoryURL = nil;
    NSData *bookmarkData = [[NSUserDefaults standardUserDefaults] dataForKey:@"directoryURL"];
    
    if (bookmarkData != nil) {
        BOOL isStale = NO;
        NSError *error = nil;
        directoryURL = [NSURL URLByResolvingBookmarkData:bookmarkData options:0 relativeToURL:nil bookmarkDataIsStale:&isStale error:&error];
        
        if (directoryURL != nil) {
            if (![[NSFileManager defaultManager] fileExistsAtPath:directoryURL.path isDirectory:NULL]) {
                directoryURL = nil;
            }
        } else {
            NSLog(@"Could not resolve bookmark data: %@", error);
        }
    }
    
    while (![self _isDocumentTempDirectory:directoryURL]) {
        if (directoryURL != nil) {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.alertStyle = NSAlertStyleWarning;
            alert.messageText = @"Invalid directory";
            alert.informativeText = @"Please select a temporary directory for a RapidWeaver document.";
            
            [alert runModal];
        }
        
        NSOpenPanel *panel = [NSOpenPanel openPanel];
        panel.message = @"Select the RapidWeaver document's temporary directory";
        panel.allowedFileTypes = @[NSFileTypeDirectory];
        panel.canChooseDirectories = YES;
        
        if ([panel runModal] != NSModalResponseOK) {
            return nil;
        }
        
        directoryURL = panel.directoryURL;
    }
    
    bookmarkData = [directoryURL bookmarkDataWithOptions:NSURLBookmarkCreationSuitableForBookmarkFile includingResourceValuesForKeys:nil relativeToURL:nil error:nil];
    if (bookmarkData != nil) {
        NSLog(@"Saving bookmark data...");
        [[NSUserDefaults standardUserDefaults] setValue:bookmarkData forKey:@"directoryURL"];
    }
    
    return directoryURL;
}

- (BOOL)_isDocumentTempDirectory:(NSURL *)directoryURL {
    return directoryURL != nil && [directoryURL.path containsString:@"/T/com.realmacsoftware.rapidweaver"] && [directoryURL.lastPathComponent containsString:@"document-"];
}

@end
