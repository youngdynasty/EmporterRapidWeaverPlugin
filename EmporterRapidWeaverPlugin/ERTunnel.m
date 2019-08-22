//
//  ERTunnel.m
//  EmporterRapidWeaverPlugin
//
//  Created by Mike Pulaski on 13/07/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "ERTunnel.h"
#import "ERService-Private.h"
#import "ERPreviewServerManager.h"


@interface ERTunnel()
@property(nonatomic,nullable,setter=_setRemoteURL:) NSURL *remoteURL;
@property(nonatomic,setter=_setLocalURL:) NSURL *localURL;

@property(nonatomic,setter=_setState:) EmporterTunnelState state;
@property(nonatomic,nullable,setter=_setConflictReason:) NSString *conflictReason;

@property(nonatomic,setter=_setCurrentTunnel:) EmporterTunnel *_currentTunnel;
@end

#pragma mark -

@implementation ERTunnel
@synthesize _currentTunnel = _currentTunnel;

static void* kvoContext = &kvoContext;

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
    
    static ERService *sharedService = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedService = [[ERService alloc] init];
    });

    _service = sharedService;
    
    [_previewManager addObserver:self forKeyPath:@"urls" options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew context:kvoContext];
    
    for (NSString *keyPath in [[self class] _keyPathActions]) {
        [self addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew context:kvoContext];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_emporterTunnelStateDidChange:) name:EmporterTunnelStateDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_emporterDidRemoveTunnel:) name:EmporterDidRemoveTunnelNotification object:nil];
    
    return self;
}

- (void)dealloc {
    for (NSString *keyPath in [[self class] _keyPathActions]) {
        [self removeObserver:self forKeyPath:keyPath];
    }
    
    [_previewManager removeObserver:self forKeyPath:@"urls"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
                       @"service.state": NSStringFromSelector(@selector(_serviceStateDidChange)),
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
    
    if (_currentTunnel == nil) {
        self._currentTunnel = [_service _createTunnel:self error:outError];
    }
    
    return _currentTunnel != nil;
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

- (void)_serviceStateDidChange {
    if (self.service.state == EmporterServiceStateSuspended) {
        [self dispose];
    }
}

- (BOOL)_isNotificationRelevantToTunnel:(NSNotification *)note{
    NSString *currentTunnelId = _currentTunnel != nil ? _currentTunnel.id : nil;
    return currentTunnelId != nil && [currentTunnelId isEqualToString:note.userInfo[EmporterTunnelIdentifierUserInfoKey]];
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

@end
