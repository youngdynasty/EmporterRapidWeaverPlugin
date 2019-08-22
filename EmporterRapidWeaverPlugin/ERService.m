//
//  ERService.m
//  EmporterRapidWeaverPlugin
//
//  Created by Mike Pulaski on 22/08/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "ERService.h"
#import "ERService-Private.h"
#import "ERTunnel.h"

@interface ERService()
@property(nonatomic,readonly) Emporter *_emporter;
@property(nonatomic,setter=_setState:) EmporterServiceState state;
@property(nonatomic,nullable,setter=_setConflictReason:) NSString *conflictReason;
@end

@implementation ERService {
    Emporter *__emporter;
}

- (instancetype)init {
    self = [super init];
    if (self == nil)
        return nil;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_emporterServiceStateDidChange:) name:EmporterServiceStateDidChangeNotification object:nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(_applicationDidTerminate:) name:NSWorkspaceDidTerminateApplicationNotification object:nil];
    
    Emporter *emporter = [Emporter isRunning] ? self._emporter : nil;
    if (emporter != nil) {
        _state = emporter.serviceState;
        _conflictReason = emporter.serviceConflictReason;
    } else {
        _state = EmporterServiceStateSuspended;
    }
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
}

- (Emporter *)_emporter {
    if (__emporter == nil) {
        __emporter = [Emporter new];
    }
    return __emporter;
}

#pragma mark - Actions

- (BOOL)restart:(NSError **)outError {
    Emporter *emporter = self._emporter;
    
    if (emporter == nil) {
        if (outError != NULL) {
            (*outError) = [NSError errorWithDomain:NSPOSIXErrorDomain code:ESRCH userInfo:@{NSLocalizedDescriptionKey: @"Emporter is not installed."}];
        }
        return NO;
    }
    
    switch (_state) {
        case EmporterServiceStateConnected:
        case EmporterServiceStateConnecting:
            if (![emporter suspendService:outError]) {
                return NO;
            }
        default:
            return [emporter resumeService:outError];
    }
}

- (void)reveal {
    Emporter *emporter = self._emporter;
    if (emporter != nil) {
        [emporter activate];
    }
}

- (EmporterTunnel *)_createTunnel:(ERTunnel *)tunnel error:(NSError **)outError {
    NSError *error = nil;
    Emporter *emporter = self._emporter;
    EmporterTunnel *result = nil;
    
    if (tunnel.localURL == nil) {
        error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EPERM userInfo:@{NSLocalizedDescriptionKey: @"Preview server is not running."}];
    } else if (emporter == nil) {
        error = [NSError errorWithDomain:NSPOSIXErrorDomain code:ESRCH userInfo:@{NSLocalizedDescriptionKey: @"Emporter is not installed."}];
    } else {
        NSDictionary *tunnelProps = @{@"isTemporary": @(YES), @"name": tunnel.name ?: tunnel.defaultName ?: @""};
        result = [emporter createTunnelWithURL:tunnel.localURL properties:tunnelProps error:&error];
        
        if (result != nil) {
            if (![emporter bindTunnel:result toPid:NSProcessInfo.processInfo.processIdentifier error:&error]) {
                [result delete];
                result = nil;
            }
        }
    }
    
    if (outError != NULL) {
        (*outError) = error;
    }
    
    return result;
}

#pragma mark - Notifications

- (void)_emporterServiceStateDidChange:(NSNotification *)note {
    Emporter *emporter = self._emporter;
    if (note.object == emporter && emporter != nil) {
        self.state = emporter.serviceState;
        self.conflictReason = emporter.serviceConflictReason;
    }
}

- (void)_applicationDidTerminate:(NSNotification *)note {
    NSRunningApplication *app = note.userInfo[NSWorkspaceApplicationKey];
    if (app != nil && [app.bundleIdentifier containsString:@"net.youngdynasty.emporter"]) {
        self.state = EmporterServiceStateSuspended;
        self.conflictReason = nil;
    }
}

@end
