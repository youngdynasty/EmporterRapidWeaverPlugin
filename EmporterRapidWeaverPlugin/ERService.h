//
//  ERService.h
//  EmporterRapidWeaverPlugin
//
//  Created by Mike Pulaski on 22/08/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Emporter.h"

NS_ASSUME_NONNULL_BEGIN

/** The EREmporter class provides an interface to the Emporter application. */
@interface ERService : NSObject

/** The current state of the service. */
@property(nonatomic,readonly) EmporterServiceState state;

/** A human-readable message describing why the service is offline. This value is non-nil only when the state is \c EmporterServiceStateConflicted. */
@property(nonatomic,nullable,readonly) NSString *conflictReason;

/** Restart the Emporter service
 \param outError An optional pointer to an error which will be non-nil if the service could not be restarted.
 \returns YES if the service was restarted.
 */
- (BOOL)restart:(NSError **)outError;

/** Reveal the interface to the service. If Emporter is not running, it will be launched. */
- (void)reveal;

@end

NS_ASSUME_NONNULL_END
