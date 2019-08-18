//
//  ERPreviewServerManager.m
//  EmporterRapidWeaverPlugin
//
//  Created by Mike Pulaski on 26/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "ERPreviewServerManager.h"
#import "YDProcessNode.h"


@interface ERPreviewServerManager()
@property(nonatomic,readonly) dispatch_queue_t _q;
@property(nonatomic,setter=_setForkSource:) dispatch_source_t _forkSource;
@property(nonatomic,setter=_setServerProcessNodes:) NSSet *_serverProcessNodes;
@property(nonatomic,setter=_setUrls:) NSSet *urls;
@property(nonatomic,setter=_setIsObserving:) BOOL isObserving;
@property(nonatomic,setter=_setLastObserverPollDate:) NSDate *lastObserverPollDate;
@end


@implementation ERPreviewServerManager
@synthesize _q = _q;
@synthesize _forkSource = _forkSource;
@synthesize _serverProcessNodes = _serverProcessNodes;

static void* _qContext = &_qContext;

+ (instancetype)defaultManager {
    static ERPreviewServerManager *defaultManager = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        NSRunningApplication *rw = [NSRunningApplication currentApplication];
        
        if (![rw.bundleIdentifier hasPrefix:@"com.realmacsoftware.rapidweaver"]) {
            // Support for our playground
            rw = [[NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.realmacsoftware.rapidweaver8"] firstObject];
            
            if (rw == nil) {
                [NSException raise:NSInternalInconsistencyException format:@"RapidWeaver is not running"];
            }
        }
        
        defaultManager = [[self alloc] initWithRapidWeaver:rw];
        [defaultManager resumeObserving];
    });
    
    return defaultManager;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype)init {
    [NSException raise:NSInternalInconsistencyException format:@"-[%@ %@] cannot be called directly", self.className, NSStringFromSelector(_cmd)];
    return nil;
}
#pragma clang diagnostic pop

- (instancetype)initWithRapidWeaver:(NSRunningApplication *)rapidWeaver {
    self = [super init];
    if (self == nil)
        return nil;
    
    _rapidWeaver = rapidWeaver;
    
    _serverProcessNodes = [NSSet set];
    _urls = [NSSet set];
    
    _q = dispatch_queue_create("net.youngdynasty.rw-server-manager", NULL);
    dispatch_queue_set_specific(_q, _qContext, _qContext, NULL);
    
    return self;
}

- (void)dealloc {
    if (_forkSource != nil) {
        dispatch_source_cancel(_forkSource);
    }
}

- (void)_sync:(void(^)(void))block {
    if (dispatch_get_specific(_qContext) == NULL) {
        dispatch_sync(_q, block);
    } else {
        block();
    }
}

#pragma mark - Observation

- (BOOL)isObserving {
    return _forkSource != nil;
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingIsObserving { return [NSSet setWithObjects:@"_forkSource", nil]; }

- (void)resumeObserving {
    // Use main thread for KVO / protected access to _forkSource
    if (![NSThread isMainThread]) {
        return dispatch_async(dispatch_get_main_queue(), ^{ [self resumeObserving]; });
    }
    
    if (_forkSource == nil) {
        __weak ERPreviewServerManager *weakSelf = self;
        dispatch_block_t forkHandler = ^{
            ERPreviewServerManager *strongSelf = weakSelf;
            (strongSelf != nil) && [strongSelf _reloadServerProcessNodes];
        };
        
        self._forkSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_PROC, _rapidWeaver.processIdentifier, DISPATCH_PROC_FORK, _q);
        dispatch_source_set_registration_handler(_forkSource, forkHandler);
        dispatch_source_set_event_handler(_forkSource, forkHandler);
        dispatch_resume(_forkSource);
    }
}

- (void)suspendObserving {
    // Use main thread for KVO / protected access to _forkSource
    if (![NSThread isMainThread]) {
        return dispatch_async(dispatch_get_main_queue(), ^{ [self suspendObserving]; });
    }
    
    if (_forkSource != nil) {
        dispatch_source_cancel(_forkSource);
        self._forkSource = nil;
    }
}

#pragma mark - URL management

- (BOOL)_reloadServerProcessNodes {
    dispatch_assert_queue(_q);
    
    YDProcessNode *rwProcessNode = [[YDProcessNode currentRootNode] childWithPid:_rapidWeaver.processIdentifier];
    if (rwProcessNode == nil) {
        return NO;
    }
    
    NSMutableSet *serverNodes = [NSMutableSet set];
    for (YDProcessNode *node in rwProcessNode.children) {
        if ([node.name isEqualToString:@"php"]) {
            [serverNodes addObject:node];
        }
    }
    self._serverProcessNodes = [serverNodes copy];
    
    return YES;
}

- (void)_setServerProcessNodes:(NSSet *__nonnull)serverProcessNodes {
    dispatch_assert_queue(_q);
    
    if (![_serverProcessNodes isEqualToSet:serverProcessNodes]) {
        _serverProcessNodes = serverProcessNodes;
        [self _serverProcessNodesDidChange];
    }
}

- (void)_serverProcessNodesDidChange {
    dispatch_assert_queue(_q);
    
    NSMutableSet *urls = [NSMutableSet set];
    for (YDProcessNode *node in _serverProcessNodes) {
        NSURL *url = NSURLFromRWPreviewServerArguments(node.arguments ?: @"");
        if (url != nil) {
            [urls addObject:url];
        }
    }
    
    // Update state in main thread (for KVO)
    dispatch_async(dispatch_get_main_queue(), ^{
        self.urls = [urls copy];
    });
}

- (NSURL *)currentURLForDirectory:(NSURL *)directory {
    __block NSURL *url = nil;
    [self _sync:^{
        url = [self _currentURLForPath:directory.path];
    }];
    return url;
}

- (NSURL *)_currentURLForPath:(NSString *)path  {
    for (YDProcessNode *node in _serverProcessNodes) {
        if ([node.arguments ?: @"" containsString:path]) {
            return NSURLFromRWPreviewServerArguments(node.arguments ?: @"");
        }
    }
    
    return [path hasPrefix:@"/private/"] ? [self _currentURLForPath:[path substringFromIndex:8]] : nil;
}

static NSURL *NSURLFromRWPreviewServerArguments(NSString *args) {
    NSRange serverFlag = [args rangeOfString:@"-S"];
    if (serverFlag.location == NSNotFound) {
        return nil;
    }
    
    NSString *serverArg = [[args substringFromIndex:NSMaxRange(serverFlag)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSRange terminationRange = [serverArg rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]];
    
    if (terminationRange.location != NSNotFound) {
        serverArg = [serverArg substringToIndex:terminationRange.location];
    }
    
    NSRange portRange = [serverArg rangeOfString:@":" options:NSBackwardsSearch];
    if (portRange.location == NSNotFound) {
        return nil;
    }
    
    NSInteger port = [[serverArg substringFromIndex:NSMaxRange(portRange)] integerValue];
    if (port == 0) {
        return nil;
    }
    
    return [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%ld", port]];
}

@end
