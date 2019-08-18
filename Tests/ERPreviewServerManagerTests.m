//
//  ERPreviewServerManagerTests.m
//  ERPreviewServerManagerTests
//
//  Created by Mike Pulaski on 26/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ERPreviewServerManager.h"

#define RW_BUNDLE_IDENTIFIER @"com.realmacsoftware.rapidweaver8"


@interface ERPreviewServerManagerTests : XCTestCase

@end

@implementation ERPreviewServerManagerTests {
    NSRunningApplication *_rapidWeaver;
    NSBundle *_bundle;
}

- (void)setUp {
    self.continueAfterFailure = NO;
    
    _bundle = [NSBundle bundleForClass:[self class]];
    
    // Terminate existing instances
    NSArray *runningInstances = [NSRunningApplication runningApplicationsWithBundleIdentifier:RW_BUNDLE_IDENTIFIER];
    
    if (runningInstances.count > 0) {
        XCTestExpectation *terminateExpectation = [self expectationForNotification:NSWorkspaceDidTerminateApplicationNotification object:nil notificationCenter:[[NSWorkspace sharedWorkspace] notificationCenter] handler:^BOOL(NSNotification *notification) {
            NSRunningApplication *app = notification.userInfo[NSWorkspaceApplicationKey];
            return [app.bundleIdentifier isEqualToString:RW_BUNDLE_IDENTIFIER];
        }];
        terminateExpectation.expectedFulfillmentCount = runningInstances.count;
        
        [runningInstances makeObjectsPerformSelector:@selector(forceTerminate)];
        [self waitForExpectations:@[terminateExpectation] timeout:10];
    }
    
    // Launch RapidWeaver
    XCTestExpectation *launchExpectation = [self expectationForNotification:NSWorkspaceDidLaunchApplicationNotification object:nil notificationCenter:[[NSWorkspace sharedWorkspace] notificationCenter] handler:^BOOL(NSNotification *notification) {
        NSRunningApplication *app = notification.userInfo[NSWorkspaceApplicationKey];
        if (![app.bundleIdentifier isEqualToString:RW_BUNDLE_IDENTIFIER]) {
            return NO;
        }
        
        self->_rapidWeaver = app;
        return YES;
    }];
    
    [[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:RW_BUNDLE_IDENTIFIER options:NSWorkspaceLaunchAndHide additionalEventParamDescriptor:nil launchIdentifier:NULL];
    [self waitForExpectations:@[launchExpectation] timeout:10];
}

- (void)tearDown {
    if (_rapidWeaver != nil) {
        [_rapidWeaver forceTerminate];
        _rapidWeaver = nil;
    }
}

- (void)testObservingLifecycle {
    ERPreviewServerManager *mgr = [[ERPreviewServerManager alloc] initWithRapidWeaver:_rapidWeaver];
    
    [self expectationForPredicate:[NSPredicate predicateWithFormat:@"isObserving = YES"] evaluatedWithObject:mgr handler:nil];
    [mgr resumeObserving];
    [self waitForExpectationsWithTimeout:2 handler:nil];
    
    [self expectationForPredicate:[NSPredicate predicateWithFormat:@"isObserving = NO"] evaluatedWithObject:mgr handler:nil];
    [mgr suspendObserving];
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testObservingURLs {
    ERPreviewServerManager *mgr = [[ERPreviewServerManager alloc] initWithRapidWeaver:_rapidWeaver];
    [mgr resumeObserving];
    [self addTeardownBlock:^{ [mgr suspendObserving]; }];

    XCTAssertTrue(mgr.urls.count == 0, @"Did not expect server URLs");
    
    NSArray *projectURLs = @[[_bundle URLForResource:@"Data/RandomPort" withExtension:@"rw8"]];
    [[NSWorkspace sharedWorkspace] openURLs:projectURLs withApplicationAtURL:_rapidWeaver.bundleURL options:NSWorkspaceLaunchAndHide configuration:@{} error:nil];
    
    [self expectationForPredicate:[NSPredicate predicateWithFormat:@"urls.@count >= 1"] evaluatedWithObject:mgr handler:nil];
    [self waitForExpectationsWithTimeout:5 handler:nil];
}

@end
