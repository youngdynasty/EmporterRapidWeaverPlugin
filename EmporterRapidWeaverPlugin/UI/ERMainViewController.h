//
//  ERMainViewController.h
//  EmporterRapidWeaverPlugin
//
//  Created by Mike Pulaski on 15/08/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ERTunnel.h"

@class ERPreviewServerManager;
@class ERTunnelViewController;
@class ERWelcomeViewController;

NS_ASSUME_NONNULL_BEGIN

/** The main view controller which is responsible for showing and managing the plugin's view controllers stack. */
@interface ERMainViewController : NSViewController

/** Initialize an instance of \c ERMainViewController with the given tunnel derived optionally from a document. This is the designated initializer.
 \param tunnel A tunnel used to derive the view stack.
 \param document The document used to derive the tunnel (if any).
 \returns A new instance of \c ERMainViewController. */
- (instancetype)initWithTunnel:(ERTunnel *)tunnel document:(NSDocument *__nullable)document NS_DESIGNATED_INITIALIZER;

/** The tunnel used to derive the view stack. */
@property(nonatomic,readonly) ERTunnel *tunnel;

/** The document used to provide default values for views within the stack. */
@property(nonatomic,nullable,weak) NSDocument *document;

/** A lazily-loaded view controller to present the tunnel. */
@property(nonatomic,readonly) ERTunnelViewController *tunnelController;

/** A lazily-loaded view controller to welcome new users. */
@property(nonatomic,readonly) ERWelcomeViewController *welcomeController;

@end

NS_ASSUME_NONNULL_END
