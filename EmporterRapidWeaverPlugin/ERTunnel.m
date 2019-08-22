//
//  ERTunnel.m
//  EmporterRapidWeaverPlugin
//
//  Created by Mike Pulaski on 13/07/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "ERTunnel.h"
#import "ERPreviewServerManager.h"

@interface ERTunnel()
@property(nonatomic,nullable,setter=_setRemoteURL:) NSURL *remoteURL;
@property(nonatomic,setter=_setLocalURL:) NSURL *localURL;

@property(nonatomic,setter=_setState:) EmporterTunnelState state;
@property(nonatomic,nullable,setter=_setConflictReason:) NSString *conflictReason;

@property(nonatomic,setter=_setServiceState:) EmporterServiceState serviceState;
@property(nonatomic,nullable,setter=_setServiceConflictReason:) NSString *serviceConflictReason;

@property(nonatomic,setter=_setCurrentTunnel:) EmporterTunnel *_currentTunnel;
@end

#pragma mark -

@implementation ERTunnel
@synthesize _currentTunnel = _currentTunnel;

static void* kvoContext = &kvoContext;

+ (Emporter *)_emporter {
    // Emporter may return nil when it's not installed, but it may be installed in the near future
    // We need to make initialization thread-safe without using dispatch_once for the Emporter ref
    static Emporter *emporter = nil;
    static dispatch_semaphore_t semaphore = NULL;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        semaphore = dispatch_semaphore_create(1);
    });
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    if (emporter == nil) {
        emporter = [Emporter new];
    }
    dispatch_semaphore_signal(semaphore);
    
    return emporter;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype)init {
    [NSException raise:NSInternalInconsistencyException format:@"-[%@ %@] cannot be called directly", self.className, NSStringFromSelector(_cmd)];
    return nil;
}
#pragma clang diagnostic pop

- (instancetype)initWithTempDocumentDirectoryURL:(NSURL *)directoryURL {
    return [self initWithTempDocumentDirectoryURL:directoryURL propertyList:nil];
}

- (instancetype)initWithTempDocumentDirectoryURL:(NSURL *)directoryURL propertyList:(NSDictionary *)plist {
    return [self initWithTempDocumentDirectoryURL:directoryURL propertyList:plist previewManager:[ERPreviewServerManager defaultManager]];
}

- (instancetype)initWithTempDocumentDirectoryURL:(NSURL *)directoryURL propertyList:(NSDictionary *)plist previewManager:(ERPreviewServerManager *)previewManager {
    self = [super init];
    if (self == nil)
        return nil;
    
    _directoryURL = [directoryURL copy];
    _previewManager = previewManager;
    _name = plistValue(plist, @"name", [NSString class]);
    _state = EmporterTunnelStateDisconnected;
    
    Emporter *emporter = Emporter.isRunning ? ERTunnel._emporter : nil;
    if (emporter != nil) {
        _serviceState = emporter.serviceState;
        _serviceConflictReason = emporter.serviceConflictReason;
    } else {
        _serviceState = EmporterServiceStateSuspended;
    }
    
    [_previewManager addObserver:self forKeyPath:@"urls" options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew context:kvoContext];
    
    for (NSString *keyPath in [[self class] _keyPathActions]) {
        [self addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew context:kvoContext];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_emporterServiceStateDidChange:) name:EmporterServiceStateDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_emporterTunnelStateDidChange:) name:EmporterTunnelStateDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_emporterDidRemoveTunnel:) name:EmporterDidRemoveTunnelNotification object:nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(_applicationDidTerminate:) name:NSWorkspaceDidTerminateApplicationNotification object:nil];
    
    return self;
}

- (void)dealloc {
    for (NSString *keyPath in [[self class] _keyPathActions]) {
        [self removeObserver:self forKeyPath:keyPath];
    }
    
    [_previewManager removeObserver:self forKeyPath:@"urls"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
}

static id plistValue(NSDictionary *plist, NSString *key, Class class) {
    id value = plist ? plist[key] : nil;
    if (value != nil && ![value isKindOfClass:class]) {
        value = nil;
    }
    return value;
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingPropertyList {
    return [NSSet setWithObjects:@"name", nil];
}

- (NSDictionary *)propertyList {
    return @{@"name": self.name ?: [NSNull null]};
}

#pragma mark - KVO

+ (NSDictionary<NSString*, NSString*>*)_keyPathActions {
    static NSDictionary *bindingMap = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bindingMap = @{
                       @"localURL": NSStringFromSelector(@selector(_localURLDidChange)),
                       @"name": NSStringFromSelector(@selector(_nameDidChange)),
                       };
    });
    return bindingMap;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context != kvoContext) {
        return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
    
    if (object == _previewManager) {
        self.localURL = [_previewManager currentURLForDirectory:_directoryURL];
    } else if (object == self) {
        NSString *actionString = [[[self class] _keyPathActions] objectForKey:keyPath];
        if (actionString != nil) {
            SEL action = NSSelectorFromString(actionString);
            void (*performAction)(id, SEL) = (void *)[self methodForSelector:action];
            if (performAction != nil) {
                performAction(self, action);
            }
        }
    }
}

#pragma mark - State

- (BOOL)create:(NSError **)outError {
    dispatch_assert_queue(dispatch_get_main_queue());
    
    NSError *error = nil;
    Emporter *emporter = ERTunnel._emporter;
    
    if (_localURL == nil) {
        error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EPERM userInfo:@{NSLocalizedDescriptionKey: @"Preview server is not running."}];
    } else if (emporter == nil) {
        error = [NSError errorWithDomain:NSPOSIXErrorDomain code:ESRCH userInfo:@{NSLocalizedDescriptionKey: @"Emporter is not installed."}];
    } else if (_currentTunnel == nil) {
        // FIXME: There's a race condition (outside of our control) if Emporter is not running; we should launch and wait
        
        NSDictionary *tunnelProps = @{@"isTemporary": @(YES), @"name": _name ?: _defaultName ?: @""};
        EmporterTunnel *tunnel = [emporter createTunnelWithURL:_localURL properties:tunnelProps error:&error];
        
        if (tunnel != nil) {
            if ([emporter bindTunnel:tunnel toPid:NSProcessInfo.processInfo.processIdentifier error:&error]) {
                self._currentTunnel = tunnel;
            } else {
                [tunnel delete];
            }
        }
    }
    
    if (outError != NULL) {
        (*outError) = error;
    }
    
    return error == nil;
}

- (void)dispose {
    dispatch_assert_queue(dispatch_get_main_queue());
    
    if ([Emporter isRunning] && _currentTunnel != nil) {
        [_currentTunnel delete];
    }
    
    self._currentTunnel = nil;
    self.remoteURL = nil;
    self.conflictReason = nil;
    self.state = EmporterTunnelStateDisconnected;
}

#pragma mark - Synchronization

- (void)_localURLDidChange {
    dispatch_assert_queue(dispatch_get_main_queue());
    
    if (_currentTunnel != nil) {
        NSNumber *port = _localURL != nil ? _localURL.port : nil;
        if (port != nil) {
            _currentTunnel.proxyPort = port;
        }
    }
}

- (void)_nameDidChange {
    dispatch_assert_queue(dispatch_get_main_queue());
    
    if (_currentTunnel != nil) {
        _currentTunnel.name = _name ?: _defaultName ?: @"";
    }
}

- (BOOL)_isNotificationRelevant:(NSNotification *)note {
    return note.object == ERTunnel._emporter;
}

- (BOOL)_isNotificationRelevantToTunnel:(NSNotification *)note{
    if (![self _isNotificationRelevant:note]) {
        return NO;
    }
    
    NSString *currentTunnelId = _currentTunnel != nil ? _currentTunnel.id : nil;
    return currentTunnelId != nil && [currentTunnelId isEqualToString:note.userInfo[EmporterTunnelIdentifierUserInfoKey]];
}

- (void)_emporterServiceStateDidChange:(NSNotification *)note {
    Emporter *emporter = ERTunnel._emporter;
    if ([self _isNotificationRelevant:note] && emporter != nil) {
        self.serviceState = emporter.serviceState;
        self.serviceConflictReason = emporter.serviceConflictReason;
    }
}

- (void)_emporterTunnelStateDidChange:(NSNotification *)note {
    if ([self _isNotificationRelevantToTunnel:note] && _currentTunnel != nil) {
        self.state = _currentTunnel.state;
        self.conflictReason = _currentTunnel.conflictReason;
        self.remoteURL = _currentTunnel.remoteUrl != nil ? [NSURL URLWithString:_currentTunnel.remoteUrl] : nil;
    }
}

- (void)_emporterDidRemoveTunnel:(NSNotification *)note {
    if ([self _isNotificationRelevantToTunnel:note]) {
        [self dispose];
    }
}

- (void)_applicationDidTerminate:(NSNotification *)note {
    NSRunningApplication *app = note.userInfo[NSWorkspaceApplicationKey];
    if (app != nil && [app.bundleIdentifier containsString:@"net.youngdynasty.emporter"]) {
        self.serviceState = EmporterServiceStateSuspended;
        self.serviceConflictReason = nil;
        self._currentTunnel = nil;
        
        self.state = EmporterTunnelStateDisconnected;
        self.conflictReason = nil;
    }
}

@end

@implementation ERTunnel(Service)

+ (BOOL)restartService:(NSError **)outError {
    Emporter *emporter = ERTunnel._emporter;
    
    if (emporter == nil) {
        if (outError != NULL) {
            (*outError) = [NSError errorWithDomain:NSPOSIXErrorDomain code:ESRCH userInfo:@{NSLocalizedDescriptionKey: @"Emporter is not installed."}];
        }
        return NO;
    }

    switch (emporter.serviceState) {
        case EmporterServiceStateConnected:
        case EmporterServiceStateConnecting:
            if (![emporter suspendService:outError]) {
                return NO;
            }
        default:
            return [emporter resumeService:outError];
    }
}

@end
