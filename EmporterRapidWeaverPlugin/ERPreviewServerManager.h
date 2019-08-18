//
//  ERPreviewServerManager.h
//  EmporterRapidWeaverPlugin
//
//  Created by Mike Pulaski on 26/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@class RWAbstractPlugin;

/** A helper class used to observe preview servers managed by RapidWeaver. */
@interface ERPreviewServerManager : NSObject

/** The default manager; lazily loaded. Raises an exception if RapidWeaver isn't running. */
+ (instancetype)defaultManager;

/** The designated initializer to inspect preview server URLs for a running instance of RapidWeaver.
 @param rapidWeaver A running instance of RapidWeaver.
 @returns A new \c ERPreviewServerManager instance in a suspended state. */
- (instancetype)initWithRapidWeaver:(NSRunningApplication *)rapidWeaver NS_DESIGNATED_INITIALIZER;

/** The instance of RapidWeaver which is running the preview server URLs. */
@property(nonatomic,readonly) NSRunningApplication *rapidWeaver;

/** Returns YES if URL changes are being observed. */
@property(nonatomic,readonly) BOOL isObserving;

/** Resume URL observer. */
- (void)resumeObserving;

/** Suspend URL observer. */
- (void)suspendObserving;

/** KVO-compliant set of preview server URLs which will update automatically while observing. */
@property(nonatomic,readonly) NSSet<NSURL*> *urls;

/** Find the current preview URL for the given directory (typically the temporary directory). */
- (NSURL *__nullable)currentURLForDirectory:(NSURL *)directory;

@end

NS_ASSUME_NONNULL_END
