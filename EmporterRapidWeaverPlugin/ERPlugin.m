//
//  ERPlugin.m
//  EmporterRapidWeaverPlugin
//
//  Created by Mike Pulaski on 25/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "ERPlugin.h"
#import "ERMainViewController.h"

@implementation ERPlugin {
    ERTunnel *_tunnel;
    ERMainViewController *_viewController;
}

+ (NSHashTable <ERPlugin *>*)_instances {
    static NSHashTable *instances = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        instances = [NSHashTable weakObjectsHashTable];
    });
    
    return instances;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self == nil)
        return nil;
    
    [self _sharedInit];
    
    return self;
}

- (instancetype)init {
    self = [super init];
    if (self == nil)
        return nil;
    
    [self _sharedInit];
    
    return self;
}

- (void)_sharedInit {
    [[[self class] _instances] addObject:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_windowWillClose:) name:NSWindowWillCloseNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self _pluginWasUnloaded];
}

- (void)_pluginWasUnloaded {
    if (_tunnel != nil) {
        [_tunnel dispose];
    }
    
    [[[self class] _instances] removeObject:self];
}

- (void)_windowWillClose:(NSNotification *)note {
    NSWindow *window = note.object;
    if (window != nil && window == self.window) {
        [self _pluginWasUnloaded];
    }
}

#pragma mark - RWPlugin / RWAbstractPlugin

+ (BOOL)initializeClass:(NSBundle *)aBundle { return YES; }

+ (BOOL)canCreateNewPage:(NSError **)errorRef currentPages:(NSArray *)currentPages {
    for (ERPlugin *instance in [[self class] _instances]) {
        if ([currentPages containsObject:instance.page]) {
            if (errorRef != NULL) {
                (*errorRef) = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteFileExistsError userInfo:@{NSLocalizedDescriptionKey: @"Only one Emporter page per project can be used at a time."}];
            }
            
            return NO;
        }
    }
    
    return YES;
}

- (ERTunnel *)tunnel {
    if (_tunnel == nil) {
        NSURL *workingDirectory = [NSURL fileURLWithPath:[[self tempFilesDirectory:nil] stringByDeletingLastPathComponent] isDirectory:YES];
        _tunnel = [[ERTunnel alloc] initWithTempDocumentDirectoryURL:workingDirectory];
    }
    
    return _tunnel;
}

- (NSWindow *)window {
    return self.document ? self.document.window : nil;
}

- (NSViewController *)editingViewController {
    if (_viewController == nil) {
        _viewController = [[ERMainViewController alloc] initWithTunnel:self.tunnel document:self.document];
    }
    
    return _viewController;
}

- (void)pluginWasDeselected {
    if (self.page == nil || ![self.allPagesUsingPlugin ?: @[] containsObject:self.page]) {
        [self _pluginWasUnloaded];
    }
}

#pragma mark - RWPluginExport (disabled)

- (id)contentHTML:(NSDictionary *)params { return nil; }
- (NSString *)pageContentHeaders:(NSDictionary *)params { return nil; }
- (NSMutableString *)updatePageTemplate:(NSMutableString *)pageTemplate params:(NSDictionary *)params depth:(NSInteger)depth { return nil; }
- (NSMutableDictionary *)contentOnlySubpageWithHTML:(NSString *)content name:(NSString *)name { return nil; }
- (NSMutableDictionary *)contentOnlySubpageWithData:(NSData *)content name:(NSString *)name { return nil; }
- (NSMutableDictionary *)contentOnlySubpageWithEntireHTML:(NSString *)content name:(NSString *)name { return nil; }
- (NSMutableDictionary *)customSubpageWithData:(NSData *)content name:(NSString *)name destination:(NSString *)destination { return nil; }
- (NSString *)sidebarHTML:(NSDictionary *)params { return nil; }
- (NSNumber *)normaliseImages { return @0U; }

#pragma mark - RWPluginMetadata

+ (NSBundle *)bundle { return [NSBundle bundleForClass:[self class]]; }
+ (NSString *)pluginName { return ERPlugin.bundle.infoDictionary[@"CFBundleName"]; }
+ (NSString *)pluginDescription { return @"Instantly live share your RapidWeaver previews over HTTPS"; }
+ (NSString *)pluginAuthor { return ERPlugin.bundle.infoDictionary[@"RWAddonAuthor"]; }
+ (NSImage *)pluginIcon { return [[NSImage alloc] initWithContentsOfFile:[self _pluginIconPath]]; }
+ (NSString *)_pluginIconPath { return [ERPlugin.bundle pathForImageResource:ERPlugin.bundle.infoDictionary[@"CFBundleIconFile"]]; }

@end
