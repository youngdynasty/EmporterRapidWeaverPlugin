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
    ERMainViewController *_viewController;
}

+ (NSHashTable *)_instances {
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
    
    [[[self class] _instances] removeObject:self];

    return self;
}

- (instancetype)init {
    self = [super init];
    if (self == nil)
        return nil;
    
    [[[self class] _instances] removeObject:self];

    return self;
}

- (void)dealloc {
    [[[self class] _instances] removeObject:self];
}

#pragma mark - RWPlugin / RWAbstractPlugin

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

+ (BOOL)initializeClass:(NSBundle *)aBundle {
    return YES;
}

- (NSViewController *)editingViewController {
    if (_viewController == nil) {
        NSURL *workingDirectory = [NSURL fileURLWithPath:[[self tempFilesDirectory:nil] stringByDeletingLastPathComponent] isDirectory:YES];
        ERTunnel *tunnel = [[ERTunnel alloc] initWithTempDocumentDirectoryURL:workingDirectory];
        _viewController = [[ERMainViewController alloc] initWithTunnel:tunnel document:self.document];
    }
    
    return _viewController;
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
