//
//  ERTunnelViewController.m
//  EmporterRapidWeaverPlugin
//
//  Created by Mike Pulaski on 09/06/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "ERTunnelViewController.h"
#import "ERPreviewServerManager.h"

@implementation ERTunnelViewController {
    IBOutlet NSTabView *__weak _tabView;
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
    [_tunnel addObserver:self forKeyPath:@"localURL" options:NSKeyValueObservingOptionNew context:kvoContext];
    
    return self;
}

- (void)dealloc {
    [_tunnel removeObserver:self forKeyPath:@"localURL"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context != kvoContext) {
        return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
    
    [self _reloadViewState];
}

#pragma mark - View

- (void)awakeFromNib {
    [super awakeFromNib];
    [self _reloadViewState];
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

- (void)_reloadViewState {
    NSString *tabIdentifier = nil;
    
    if (_tunnel.localURL == nil) {
        tabIdentifier = @"noLocalURL";
    } else {
        // TODO: Add more cases
        tabIdentifier = @"connected";
    }
    
    if (_tabView != nil) {
        [_tabView selectTabViewItemWithIdentifier:tabIdentifier];
    }
}


#pragma mark - Actions

- (IBAction)stopSharing:(id)sender {
    [_tunnel suspend];
}

- (IBAction)startSharing:(id)sender {
    NSError *error = nil;
    if (![_tunnel resume:&error]) {
        [[NSAlert alertWithError:error] runModal];
    }
}

- (IBAction)openRemoteURL:(id)sender {
    _tunnel.remoteURL ? [[NSWorkspace sharedWorkspace] openURL:_tunnel.remoteURL] : NSBeep();
}

@end


@interface _ERTunnelStateTransformer : NSValueTransformer
@end

@implementation _ERTunnelStateTransformer : NSValueTransformer

+ (Class)transformedValueClass { return [NSString class]; }
+ (BOOL)allowsReverseTransformation { return NO; }

- (id)transformedValue:(id)value {
    switch ((EmporterTunnelState) [(NSNumber *)value integerValue]) {
        case EmporterTunnelStateInitializing:
            return @"Initializing";
        case EmporterTunnelStateDisconnecting:
            return @"Disconnecting";
        case EmporterTunnelStateDisconnected:
            return @"Disconnected";
        case EmporterTunnelStateConnecting:
            return @"Connecting";
        case EmporterTunnelStateConnected:
            return @"Connected";
        case EmporterTunnelStateConflicted:
            return @"Conflicted";
        default:
            return @"Unknown";
    }
}

@end
