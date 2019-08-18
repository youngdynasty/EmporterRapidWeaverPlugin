//
//  ERMainViewController.m
//  EmporterRapidWeaverPlugin
//
//  Created by Mike Pulaski on 15/08/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "ERMainViewController.h"

#import "ERPreviewServerManager.h"
#import "ERTunnelViewController.h"
#import "ERWelcomeViewController.h"

@implementation ERMainViewController {
    ERTunnel *_tunnel;
}
@synthesize tunnelController = _tunnelController;
@synthesize welcomeController = _welcomeController;

static void* kvoContext = &kvoContext;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype)init {
    [NSException raise:NSInternalInconsistencyException format:@"-[%@ %@] cannot be called directly", self.className, NSStringFromSelector(_cmd)];
    return nil;
}

- (instancetype)initWithNibName:(NSNibName)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    [NSException raise:NSInternalInconsistencyException format:@"-[%@ %@] cannot be called directly", self.className, NSStringFromSelector(_cmd)];
    return nil;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    [NSException raise:NSInternalInconsistencyException format:@"-[%@ %@] cannot be called directly", self.className, NSStringFromSelector(_cmd)];
    return nil;
}

#pragma clang diagnostic pop

- (instancetype)initWithTunnel:(ERTunnel *)tunnel document:(NSDocument * _Nullable)document {
    self = [super initWithNibName:nil bundle:nil];
    if (self == nil)
        return nil;
    
    _tunnel = tunnel;
    _document = document;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_reloadChildViewControllers:) name:NSApplicationDidBecomeActiveNotification object:nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(_reloadChildViewControllers:) name:NSWorkspaceDidLaunchApplicationNotification object:nil];
    
    [self addObserver:self forKeyPath:@"document.fileURL" options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew context:kvoContext];
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
    
    [self removeObserver:self forKeyPath:@"document.fileURL"];
}

#pragma mark -

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context != kvoContext) {
        return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
    
    if ([keyPath isEqualToString:@"document.fileURL"]) {
        NSURL *fileURL = _document ? _document.fileURL : nil;
        _tunnel.defaultName = fileURL ? [[fileURL lastPathComponent] stringByDeletingPathExtension] : nil;
    }
}

- (void)loadView {
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 850, 550)];
    self.view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self _reloadChildViewControllers:nil];
}

#pragma mark - Child Controllers

- (void)_reloadChildViewControllers:(NSNotification *)notification {
    if ([Emporter isInstalled]) {
        [self _unmountWelcomeController];
        [self _mountTunnelController];
    } else {
        [self _mountWelcomeController];
        [self _unmountTunnelController];
    }
}

- (ERWelcomeViewController *)welcomeController {
    if (_welcomeController == nil) {
        _welcomeController = [[ERWelcomeViewController alloc] init];
    }
    
    return _welcomeController;
}

- (void)_mountWelcomeController {
    if (_welcomeController != nil && _welcomeController.parentViewController == self) {
        return;
    }
    
    _welcomeController.view.frame = self.view.bounds;
    [self.view addSubview:self.welcomeController.view];
    
    [self addChildViewController:self.welcomeController];
}

- (void)_unmountWelcomeController {
    if (_welcomeController == nil || _welcomeController.parentViewController != self) {
        return;
    }

    [_welcomeController removeFromParentViewController];
    [_welcomeController.view removeFromSuperview];
}

- (ERTunnelViewController *)tunnelController {
    if (_tunnelController == nil) {
        _tunnelController = [[ERTunnelViewController alloc] initWithTunnel:_tunnel];
    }
    
    return _tunnelController;
}

- (void)_mountTunnelController {
    if (_tunnelController != nil && _tunnelController.parentViewController == self) {
        return;
    }
    
    _tunnelController.view.frame = self.view.bounds;
    [self.view addSubview:self.tunnelController.view];
    
    [self addChildViewController:self.tunnelController];
}

- (void)_unmountTunnelController {
    if (_tunnelController == nil || _tunnelController.parentViewController != self) {
        return;
    }
    
    [_tunnelController removeFromParentViewController];
    [_tunnelController.view removeFromSuperview];
}

@end
