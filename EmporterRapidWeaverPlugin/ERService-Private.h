//
//  ERService-Private.h
//  EmporterRapidWeaverPlugin
//
//  Created by Mike Pulaski on 22/08/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "ERService.h"

@class ERTunnel;

NS_ASSUME_NONNULL_BEGIN

@interface ERService()

- (EmporterTunnel *)_createTunnel:(ERTunnel *)tunnel error:(NSError **)outError;

@end

NS_ASSUME_NONNULL_END
