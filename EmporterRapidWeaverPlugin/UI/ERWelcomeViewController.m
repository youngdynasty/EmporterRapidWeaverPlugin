//
//  ERWelcomeViewController.m
//  EmporterRapidWeaverPlugin
//
//  Created by Mike Pulaski on 15/08/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "ERWelcomeViewController.h"
#import "Emporter.h"

@implementation ERWelcomeViewController

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype)initWithNibName:(NSNibName)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    [NSException raise:NSInternalInconsistencyException format:@"-[%@ %@] cannot be called directly", self.className, NSStringFromSelector(_cmd)];
    return nil;
}
#pragma clang diagnostic pop

- (instancetype)init {
    return [super initWithNibName:@"ERWelcomeViewController" bundle:[NSBundle bundleForClass:[self class]]];
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

- (IBAction)downloadEmporter:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[Emporter appStoreURL]];
}

@end
