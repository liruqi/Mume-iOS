//
//  PotatsoManager.m
//  Potatso
//
//  Created by LEI on 4/4/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

#import "Potatso.h"

NSString *sharedGroupIdentifier = @"group.info.liruqi.potatso";

@implementation Potatso

+ (NSURL *)sharedUrl {
    return [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:sharedGroupIdentifier];
}

+ (NSURL *)sharedDatabaseUrl {
    return [[self sharedUrl] URLByAppendingPathComponent:@"potatso.realm" isDirectory:NO];
}

+ (NSUserDefaults *)sharedUserDefaults {
    return [[NSUserDefaults alloc] initWithSuiteName:sharedGroupIdentifier];
}

+ (NSURL * _Nonnull)sharedGeneralConfUrl {
    return [[Potatso sharedUrl] URLByAppendingPathComponent:@"general.xxx"  isDirectory:NO];
}

+ (NSURL *)sharedProxyConfUrl {
    return [[Potatso sharedUrl] URLByAppendingPathComponent:@"proxy.xxx"  isDirectory:NO];
}

+ (NSURL *)sharedHttpProxyConfUrl {
    return [[Potatso sharedUrl] URLByAppendingPathComponent:@"http.xxx"  isDirectory:NO];
}

+ (NSURL * _Nonnull)sharedLogUrl {
    return [[Potatso sharedUrl] URLByAppendingPathComponent:@"tunnel.log"  isDirectory:NO];
}

@end
