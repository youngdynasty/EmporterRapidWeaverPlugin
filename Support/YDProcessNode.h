//
//  YDProcessNode.h
//  EmporterRapidWeaverPlugin
//
//  Created by Mike Pulaski on 26/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*! A class used to traverse processes hierarchically. */
@interface YDProcessNode : NSObject

/*! The current root node of the processes running locally. */
+ (instancetype)currentRootNode;

/*! The name of the process (may be truncated) */
@property(nonatomic,readonly) NSString *__nullable name;

/*! The pid value of the process */
@property(nonatomic,readonly) pid_t pidValue;

/*! The pid value of the parent process */
@property(nonatomic,readonly) pid_t parentPidValue;

/*! Is the process still running? */
@property(nonatomic,readonly) BOOL isRunning;

/*! The arguments passed to the process on launch. Lazily constructed (may be nil) */
@property(nonatomic,readonly) NSString *__nullable arguments;

/*! The parent process */
@property(nonatomic,readonly,weak) YDProcessNode *__nullable parent;

/*! Children of the process */
@property(nonatomic,readonly,copy) NSArray *children;

/*!
 Traverse children recursively to find a child for a pid
 \param pid The id for the process you wish to find
 \returns A child process or nil
 */
- (YDProcessNode *__nullable)childWithPid:(pid_t)pid;

@end

NS_ASSUME_NONNULL_END
