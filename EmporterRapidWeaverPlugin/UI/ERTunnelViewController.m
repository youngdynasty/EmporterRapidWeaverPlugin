//
//  ERTunnelViewController.m
//  EmporterRapidWeaverPlugin
//
//  Created by Mike Pulaski on 09/06/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "ERTunnelViewController.h"
#import "ERPreviewServerManager.h"
#import "ERService.h"

@interface ERTunnelViewController()
@property(nonatomic) NSUInteger publishCount;
@property(nonatomic,readonly) BOOL isBusy;
@property(nonatomic,readonly) BOOL hideCreateButton;
@property(nonatomic,readonly) NSString *selectedTabIdentifier;
@end


@implementation ERTunnelViewController {
    __weak IBOutlet NSTabView * _tabView;
    __weak IBOutlet NSButton *_remoteURLButton;
}

static void* kvoContext = &kvoContext;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype)initWithNibName:(NSNibName)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    [NSException raise:NSInternalInconsistencyException format:@"-[%@ %@] cannot be called directly", self.className, NSStringFromSelector(_cmd)];
    return nil;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    [NSException raise:NSInternalInconsistencyException format:@"-[%@ %@] cannot be called directly", self.className, NSStringFromSelector(_cmd)];
    return nil;
}
#pragma clang diagnostic pop

- (instancetype)initWithTunnel:(ERTunnel *)tunnel {
    self = [super initWithNibName:@"ERTunnelViewController" bundle:[NSBundle bundleForClass:[self class]]];
    if (self == nil)
        return nil;
    
    _tunnel = tunnel;
    
    [self addObserver:self forKeyPath:@"tunnel.remoteURL" options:NSKeyValueObservingOptionNew context:kvoContext];
    
    return self;
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:@"tunnel.remoteURL"];
}

#pragma mark - View / bindings

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context != kvoContext) {
        return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
    
    if ([keyPath isEqualToString:@"tunnel.remoteURL"]) {
        [self _layoutRemoteURL];
    }
}

- (void)viewDidLayout {
    [super viewDidLayout];
    
    NSView *childView = [self.view.subviews firstObject];
    
    if (childView != nil) {
        CGFloat centerX = floor((NSWidth(self.view.bounds) - NSWidth(childView.bounds)) / 2);
        CGFloat centerY = floor((NSHeight(self.view.bounds) - NSHeight(childView.bounds)) / 2);
        
        childView.frame = NSOffsetRect(childView.bounds, centerX, centerY);
    }
}

- (void)_layoutRemoteURL {
    NSView *container = _remoteURLButton.superview;
    if (container != nil) {
        [_remoteURLButton sizeToFit];
        [_remoteURLButton setFrameOrigin:NSMakePoint(NSMidX(container.bounds) - NSMidX(_remoteURLButton.bounds), NSMinY(_remoteURLButton.frame))];
    }
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingSelectedTabIdentifier {
    return [NSSet setWithObjects:@"tunnel.localURL", @"tunnel.state", @"tunnel.service.state", nil];
}

- (NSString *)selectedTabIdentifier {
    if (_tunnel.localURL == nil) {
        return @"noLocalURL";
    }
    
    switch (_tunnel.service.state) {
        case EmporterServiceStateConflicted:
            return @"error";
        case EmporterServiceStateConnecting:
        case EmporterServiceStateSuspended:
            return @"suspended";
        case EmporterServiceStateConnected:
        default:
            switch (_tunnel.state) {
                case EmporterTunnelStateConflicted:
                    return @"error";
                case EmporterTunnelStateConnected:
                    return @"connected";
                default:
                    return @"suspended";
            }
    }
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingIsBusy {
    return [NSSet setWithObjects:@"publishCount", @"tunnel.state", @"tunnel.service.state", nil];
}

- (BOOL)isBusy {
    if (_publishCount > 0) {
        return YES;
    }
    
    switch (_tunnel.state) {
        case EmporterTunnelStateInitializing:
        case EmporterTunnelStateConnecting:
            return YES;
        default:
            return _tunnel.service.state == EmporterServiceStateConnecting;
    }
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingHideCreateButton {
    return [NSSet setWithObjects:@"isBusy", @"publishCount", @"tunnel.isPublished", nil];
}

- (BOOL)hideCreateButton {
    return self.isBusy && _publishCount == 0 && !_tunnel.isPublished;
}

#pragma mark - Actions

- (IBAction)startSharing:(id)sender {
    self.publishCount++;
    
    [_tunnel publishWithCompletionHandler:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error != nil) {
                NSError *normalizedError = error;
                
                if (!self._isRapidWeaverAtLeast8_3) {
                    NSDictionary *errorInfo = @{NSLocalizedDescriptionKey: @"RapidWeaver v8.3+ is required in order to share data with Emporter.",
                                                NSLocalizedRecoverySuggestionErrorKey: @"Please update to the latest version of RapidWeaver to continue.",
                                                NSUnderlyingErrorKey: error };
                    normalizedError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFeatureUnsupportedError userInfo:errorInfo];

                    NSLog(@"Emporter could not publish URL: %@", error);
                }
                
                [[NSAlert alertWithError:normalizedError] runModal];
            }
            
            self.publishCount--;
        });
    }];
}

- (IBAction)stopSharing:(id)sender {
    [_tunnel dispose];
}

- (IBAction)openRemoteURL:(id)sender {
    _tunnel.remoteURL ? [[NSWorkspace sharedWorkspace] openURL:_tunnel.remoteURL] : NSBeep();
}

- (IBAction)edit:(id)sender {
    [_tunnel edit];
}

- (IBAction)openEmporter:(id)sender {
    [_tunnel.service reveal];
}

#pragma mark -

- (BOOL)_isRapidWeaverAtLeast8_3 {
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary] ?: @{};
    NSString *versionString = infoDictionary[(NSString *)kCFBundleVersionKey] ?: @"";
    NSCharacterSet *nonNumericCharacters = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    
    return [[versionString  stringByTrimmingCharactersInSet:nonNumericCharacters] integerValue] >= 20799;
}

@end
