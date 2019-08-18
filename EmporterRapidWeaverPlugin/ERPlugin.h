//
//  ERPlugin.h
//  EmporterRapidWeaverPlugin
//
//  Created by Mike Pulaski on 25/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <RWKit/RWKit.h>
#import <RMKit/RMKit.h>

NS_ASSUME_NONNULL_BEGIN

/** ERPlugin is the principal class for the Emporter Rapid Weaver plugin. */
@interface ERPlugin : RWAbstractPlugin

@property (class,readonly) NSBundle *bundle;

@end

NS_ASSUME_NONNULL_END
