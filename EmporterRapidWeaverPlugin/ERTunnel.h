//
//  ERTunnel.h
//  EmporterRapidWeaverPlugin
//
//  Created by Mike Pulaski on 13/07/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Emporter.h"

@class ERPreviewServerManager;

NS_ASSUME_NONNULL_BEGIN

/** ERTunnel binds Emporter tunnels to RapidWeaver projects. */
@interface ERTunnel : NSObject

/** Initialize \c ERTunnel with a document's temporary directory URL.
 
 \param directoryURL A document's temporary directory URL.
 
 \returns A new instance of \c ERTunnel.
 */
- (instancetype)initWithTempDocumentDirectoryURL:(NSURL *)directoryURL;

/** Initialize \c ERTunnel with a document's temporary directory URL along with state derived from a property list.
 
 \param directoryURL A document's temporary directory URL.
 \param plist A property list used to derive state.
 
 \returns A new instance of \c ERTunnel.
 */
- (instancetype)initWithTempDocumentDirectoryURL:(NSURL *)directoryURL propertyList:(NSDictionary *__nullable)plist;

/** Initialize \c ERTunnel with a document's temporary directory URL along with state derived from a property list and the preview server manager.
 
 This is the designated initializer.
 
 \param directoryURL A document's temporary directory URL.
 \param plist A property list used to derive state.
 \param previewManager An instance of \c ERPreviewServerManager used to resolve local URLs for the document.
 
 \returns A new instance of \c ERTunnel.
 */
- (instancetype)initWithTempDocumentDirectoryURL:(NSURL *)directoryURL propertyList:(NSDictionary *__nullable)plist previewManager:(ERPreviewServerManager *)previewManager NS_DESIGNATED_INITIALIZER;

/** A document's temporary work directory. */
@property(nonatomic,readonly) NSURL *directoryURL;

/** A KVO-compliant property list which can be used to archive state. */
@property(nonatomic,readonly) NSDictionary *propertyList;

/** An instance of \c ERPreviewServerManager used to resolve local URLs. */
@property(nonatomic,readonly) ERPreviewServerManager *previewManager;

/** A user-defined name used to create Emporter's URL. */
@property(nonatomic,nullable,copy) NSString *name;

/** A default name used to create Emporter's URL if a user-defined one is not given (i.e. the name of the RW document/project). */
@property(nonatomic,nullable,copy) NSString *defaultName;

/** The local URL, managed by RW, used to preview a project. */
@property(nonatomic,nullable,readonly) NSURL *localURL;

/** The remote URL, managed by Emporter, used to preview a project. */
@property(nonatomic,nullable,readonly) NSURL *remoteURL;

/** The current state of the tunnel. */
@property(nonatomic,readonly) EmporterTunnelState state;

/** A human-readable message describing why a remote URL could not be created. This value is non-nil only when the state is \c EmporterTunnelStateConflicted. */
@property(nonatomic,nullable,readonly) NSString *conflictReason;

/** The current state of the service. */
@property(nonatomic,readonly) EmporterServiceState serviceState;

/** A human-readable message describing why the service is offline. This value is non-nil only when the serviceState is \c EmporterServiceStateConflicted. */
@property(nonatomic,readonly) NSString *serviceConflictReason;

/** Create the tunnel in Emporter. */
- (BOOL)create:(NSError **__nullable)outError;

/** Dispose the current tunnel in Emporter. */
- (void)dispose;

@end


@interface ERTunnel(Service)
/** Restart the Emporter service
 \param outError An optional pointer to an error which will be non-nil if the service could not be restarted.
 \returns YES if the service was restarted.
 */
+ (BOOL)restartService:(NSError **)outError;
@end

NS_ASSUME_NONNULL_END
