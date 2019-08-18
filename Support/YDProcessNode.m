//
//  YDProcessNode.m
//  EmporterRapidWeaverPlugin
//
//  Created by Mike Pulaski on 26/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#include <sys/sysctl.h>
#include <stdio.h>
#include <stdlib.h>
#include <libproc.h>
#include <sys/proc_info.h>

#import "YDProcessNode.h"

@interface YDProcessNode()
@property(nonatomic,weak,setter=_setParent:) YDProcessNode *parent;
@end


@implementation YDProcessNode {
    NSMutableArray *_children;
    NSString *_args;
}

+ (instancetype)currentRootNode {
    return [[self alloc] _initRootNode];
}

- (instancetype)init {
    [NSException raise:NSInternalInconsistencyException format:@"%@ cannot be initialized directly", self.className];
    return nil;
}

- (instancetype)_initWithProccess:(struct kinfo_proc)proc {
    self = [super init];
    if (self == nil)
        return nil;
    
    _name = [NSString stringWithCString:proc.kp_proc.p_comm encoding:NSUTF8StringEncoding];
    _pidValue = proc.kp_proc.p_pid;
    _parentPidValue = proc.kp_eproc.e_ppid;
    _children = [NSMutableArray array];
    
    return self;
}

- (instancetype)_initRootNode {
    struct kinfo_proc *procs = NULL;
    size_t procsLength;
    
    if (_YDProcessList(&procs, &procsLength) != noErr) {
        return nil;
    }
    
    self = [super init];
    if (self == nil)
        return nil;
    
    NSMutableDictionary *nodes = [NSMutableDictionary dictionary];
    
    for (int i = 0; i < procsLength; i++) {
        YDProcessNode *process = [[YDProcessNode alloc] _initWithProccess:procs[i]];
        nodes[@(process.pidValue)] = process;
    }
    
    _children = [NSMutableArray array];
    
    for (NSNumber *pid in nodes) {
        YDProcessNode *node = nodes[pid];
        YDProcessNode *parent = node.pidValue == 0 && node.parentPidValue == 0 ? self : nodes[@(node.parentPidValue)];
        
        if (parent != nil) {
            [parent _addChild:node];
        }
    }
    
    free(procs);
    
    return self;
}

- (BOOL)isEqual:(id)object {
    if (object == nil || ![object isKindOfClass:[self class]]) {
        return NO;
    }
    return ((YDProcessNode*)object)->_pidValue == _pidValue;
}

- (NSUInteger)hash {
    return @(_pidValue).hash;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ (%d > %d) - %ld children", _name, _parentPidValue, _pidValue, _children.count];
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"%@ (%d > %d) - %@", _name, _parentPidValue, _pidValue, [_children debugDescription]];
}

- (NSArray *)children {
    return [_children copy];
}

- (BOOL)isRunning {
    int name[3] = { CTL_KERN, KERN_PROCARGS2, _pidValue};
    return sysctl(name, 3, NULL, NULL, NULL, 0) == 0;
}

- (NSString *)arguments {
    if (_args == nil) {
        char *cargs = NULL;
        if (_YDProcessArgs(_pidValue, &cargs) == 0) {
            _args = [[NSString alloc] initWithBytesNoCopy:cargs length:strlen(cargs) encoding:NSASCIIStringEncoding freeWhenDone:YES];
        }
    }
    
    return _args;
}

- (void)_addChild:(YDProcessNode *)child {
    child.parent = self;
    
    NSUInteger idx = 0;
    
    for (YDProcessNode *sibling in _children) {
        if (sibling.pidValue > child.pidValue) {
            break;
        }
        idx++;
    }
    
    [_children insertObject:child atIndex:idx];
}

- (YDProcessNode *)childWithPid:(pid_t)pid {
    for (YDProcessNode *child in self.children) {
        if (child.pidValue == pid) {
            return child;
        } else {
            YDProcessNode *distantChild = [child childWithPid:pid];
            if (distantChild != nil) {
                return distantChild;
            }
        }
    }
    
    return nil;
}


// From https://developer.apple.com/library/archive/qa/qa2001/qa1123.html
static int _YDProcessList(struct kinfo_proc **procList, size_t *procCount)
// Returns a list of all BSD processes on the system.  This routine
// allocates the list and puts it in *procList and a count of the
// number of entries in *procCount.  You are responsible for freeing
// this list (use "free" from System framework).
// On success, the function returns 0.
// On error, the function returns a BSD errno value.
{
    int                 err;
    struct kinfo_proc*  result;
    bool                done;
    static const int    name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    // Declaring name as const requires us to cast it when passing it to
    // sysctl because the prototype doesn't include the const modifier.
    size_t              length;
    
    assert( procList != NULL);
    assert(*procList == NULL);
    assert(procCount != NULL);
    
    *procCount = 0;
    
    // We start by calling sysctl with result == NULL and length == 0.
    // That will succeed, and set length to the appropriate length.
    // We then allocate a buffer of that size and call sysctl again
    // with that buffer.  If that succeeds, we're done.  If that fails
    // with ENOMEM, we have to throw away our buffer and loop.  Note
    // that the loop causes use to call sysctl with NULL again; this
    // is necessary because the ENOMEM failure case sets length to
    // the amount of data returned, not the amount of data that
    // could have been returned.
    
    result = NULL;
    done = false;
    do {
        assert(result == NULL);
        
        // Call sysctl with a NULL buffer.
        
        length = 0;
        err = sysctl( (int *) name, (sizeof(name) / sizeof(*name)) - 1,
                     NULL, &length,
                     NULL, 0);
        if (err == -1) {
            err = errno;
        }
        
        // Allocate an appropriately sized buffer based on the results
        // from the previous call.
        
        if (err == 0) {
            result = malloc(length);
            if (result == NULL) {
                err = ENOMEM;
            }
        }
        
        // Call sysctl again with the new buffer.  If we get an ENOMEM
        // error, toss away our buffer and start again.
        
        if (err == 0) {
            err = sysctl( (int *) name, (sizeof(name) / sizeof(*name)) - 1,
                         result, &length,
                         NULL, 0);
            if (err == -1) {
                err = errno;
            }
            if (err == 0) {
                done = true;
            } else if (err == ENOMEM) {
                assert(result != NULL);
                free(result);
                result = NULL;
                err = 0;
            }
        }
    } while (err == 0 && ! done);
    
    // Clean up and establish post conditions.
    
    if (err != 0 && result != NULL) {
        free(result);
        result = NULL;
    }
    *procList = result;
    if (err == 0) {
        *procCount = length / sizeof(struct kinfo_proc);
    }
    
    assert( (err == 0) == (*procList != NULL) );
    
    return err;
}

// From htop 2.x / ps (with small modifications to silence warnings)
static int _YDProcessArgs(pid_t pid, char **result) {
    int mib[3], argmax, nargs, c = 0;
    size_t size;
    char *procargs = NULL, *sp, *np, *cp;
    
    /* Get the maximum process arguments size. */
    mib[0] = CTL_KERN;
    mib[1] = KERN_ARGMAX;
    
    size = sizeof( argmax );
    if ( sysctl( mib, 2, &argmax, &size, NULL, 0 ) == -1 ) {
        goto ERROR;
    }
    
    /* Allocate space for the arguments. */
    procargs = (char*) malloc( argmax );
    if ( procargs == NULL ) {
        goto ERROR;
    }
    
    mib[0] = CTL_KERN;
    mib[1] = KERN_PROCARGS2;
    mib[2] = pid;
    
    size = ( size_t ) argmax;
    if ( sysctl( mib, 3, procargs, &size, NULL, 0 ) == -1 ) {
        goto ERROR;
    }
    
    memcpy( &nargs, procargs, sizeof( nargs ) );
    cp = procargs + sizeof( nargs );
    
    /* Skip the saved exec_path. */
    for ( ; cp < &procargs[size]; cp++ ) {
        if ( *cp == '\0' ) {
            /* End of exec_path reached. */
            break;
        }
    }
    if ( cp == &procargs[size] ) {
        goto ERROR;
    }
    
    /* Skip trailing '\0' characters. */
    for ( ; cp < &procargs[size]; cp++ ) {
        if ( *cp != '\0' ) {
            /* Beginning of first argument reached. */
            break;
        }
    }
    if ( cp == &procargs[size] ) {
        goto ERROR;
    }
    /* Save where the argv[0] string starts. */
    sp = cp;
    
    /*
     * Iterate through the '\0'-terminated strings and convert '\0' to ' '
     * until a string is found that has a '=' character in it (or there are
     * no more strings in procargs).  There is no way to deterministically
     * know where the command arguments end and the environment strings
     * start, which is why the '=' character is searched for as a heuristic.
     */
    for ( np = NULL; c < nargs && cp < &procargs[size]; cp++ ) {
        if ( *cp == '\0' ) {
            c++;
            if ( np != NULL ) {
                /* Convert previous '\0'. */
                *np = ' ';
            }
            /* Note location of current '\0'. */
            np = cp;
        }
    }
    
    /*
     * sp points to the beginning of the arguments/environment string, and
     * np should point to the '\0' terminator for the string.
     */
    if ( np == NULL || np == sp || sp == NULL ) {
        /* Empty or unterminated string. */
        goto ERROR;
    }
    
    /* Clean up. */
    free(procargs);
    
    if (result != NULL) {
        (*result) = strdup(sp);
    }
    
    return 0;
    
ERROR:
    if (procargs != NULL) {
        free(procargs);
    }
    
    return -1;
}

@end
