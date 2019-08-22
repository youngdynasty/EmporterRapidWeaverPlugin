//
//  ERTunnelViewController.m
//  EmporterRapidWeaverPlugin
//
//  Created by Mike Pulaski on 09/06/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "ERTunnelViewController.h"
#import "ERPreviewServerManager.h"

@interface ERTunnelViewController()
@property(nonatomic,readonly) BOOL isBusy;
@property(nonatomic,readonly) NSString *selectedTabIdentifier;
@end

@implementation ERTunnelViewController {
    IBOutlet NSTabView *__weak _tabView;
}

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
    
    return self;
}

#pragma mark - View / bindings

- (void)viewDidLayout {
    [super viewDidLayout];
    
    NSView *childView = [self.view.subviews firstObject];
    
    if (childView != nil) {
        CGFloat centerX = floor((NSWidth(self.view.bounds) - NSWidth(childView.bounds)) / 2);
        CGFloat centerY = floor((NSHeight(self.view.bounds) - NSHeight(childView.bounds)) / 2);
        
        childView.frame = NSOffsetRect(childView.bounds, centerX, centerY);
    }
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingSelectedTabIdentifier {
    return [NSSet setWithObjects:@"tunnel.localURL", @"tunnel.serviceState", @"tunnel.state", nil];
}

- (NSString *)selectedTabIdentifier {
    if (_tunnel.localURL == nil) {
        return @"noLocalURL";
    }
    
    switch (_tunnel.serviceState) {
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
    return [NSSet setWithObjects:@"tunnel.serviceState", @"tunnel.state", nil];
}

- (BOOL)isBusy {
    switch (_tunnel.state) {
        case EmporterTunnelStateInitializing:
        case EmporterTunnelStateConnecting:
            return YES;
        default:
            return _tunnel.serviceState == EmporterServiceStateConnecting;
    }
}

#pragma mark - Actions

- (IBAction)startSharing:(id)sender {
    NSError *error = nil;
    
    switch (_tunnel.serviceState) {
        case EmporterServiceStateSuspended:
        case EmporterServiceStateConflicted:
            [ERTunnel restartService:&error] && [_tunnel create:&error];
            break;
        default:
            [_tunnel create:&error];
            break;
    }
    
    if (error != nil) {
        [[NSAlert alertWithError:error] runModal];
    }
}

- (IBAction)stopSharing:(id)sender {
    [_tunnel dispose];
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
