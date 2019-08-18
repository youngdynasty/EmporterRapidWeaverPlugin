//
//  ERTunnelViewController.h
//  EmporterRapidWeaverPlugin
//
//  Created by Mike Pulaski on 09/06/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "ERTunnel.h"

NS_ASSUME_NONNULL_BEGIN

/** A view controller used to present an instance of \c ERTunnel. */
@interface ERTunnelViewController : NSViewController

/** Initialize an instance of \c ERTunnelViewController with the given tunnel. This is the designated initializer.
 \param tunnel A tunnel used to derive the view stack.
 \returns A new instance of \c ERTunnelViewController. */
- (instancetype)initWithTunnel:(ERTunnel *)tunnel NS_DESIGNATED_INITIALIZER;

/** The tunnel used to derive the view stack. */
@property(nonatomic,readonly) ERTunnel *tunnel;

@end

NS_ASSUME_NONNULL_END
