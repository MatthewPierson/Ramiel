//
//  IPSW.m
//  Ramiel
//
//  Created by Matthew Pierson on 9/02/21.
//  Copyright © 2021 moski. All rights reserved.
//

#import "IPSW.h"
#import <Foundation/Foundation.h>

@implementation IPSW

- (id)initIPSWID {
    self = [super self];
    if (self) {
        return self;
    }
    return NULL;
}
- (NSString *)getIpswPath {
    return self.ipswPath;
};
- (NSString *)getIosVersion {
    return self.iosVersion;
};
- (NSMutableArray *)getSupportedModels {
    return self.supportedModels;
};
- (BOOL)getReleaseBuild {
    return self.releaseBuild;
};
- (BOOL)getBootRamdisk {
    return self.bootRamdisk;
}
- (NSString *)getIbssName {
    return self.ibssName;
};
- (NSString *)getIbecName {
    return self.ibecName;
};
- (NSString *)getDeviceTreeName {
    return self.deviceTreeName;
};
- (NSString *)getTrustCacheName {
    return self.trustCacheName;
};
- (NSString *)getKernelName {
    return self.kernelName;
};
- (NSString *)getAopfwName {
    return self.aopfwName;
};
- (NSString *)getCallanName {
    return self.callanName;
};
- (NSString *)getTouchName {
    return self.touchName;
};
- (NSString *)getIspName {
    return self.ispName;
};
- (NSString *)getRestoreRamdiskName {
    return self.restoreRamdiskName;
};
- (NSString *)getBootargs {
    return self.bootargs;
};
- (NSString *)getCustomLogoPath {
    return self.customLogoPath;
};
- (void)teardown {
    [self setIpswPath:NULL];
    [self setIosVersion:NULL];
    [self setSupportedModels:NULL];
    [self setReleaseBuild:(BOOL)NULL];
    [self setIbssName:NULL];
    [self setIbecName:NULL];
    [self setDeviceTreeName:NULL];
    [self setTrustCacheName:NULL];
    [self setKernelName:NULL];
    [self setAopfwName:NULL];
    [self setCallanName:NULL];
    [self setTouchName:NULL];
    [self setIspName:NULL];
    [self setRestoreRamdiskName:NULL];
    [self setBootargs:NULL];
    [self setCustomLogoPath:NULL];
}
+ (instancetype)initIPSW {
    return [[IPSW alloc] initIPSWID];
}
@end
