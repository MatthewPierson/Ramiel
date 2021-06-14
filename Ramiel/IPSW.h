//
//  IPSW.h
//  Ramiel
//
//  Created by Matthew Pierson on 9/02/21.
//  Copyright © 2021 moski. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface IPSW : NSObject
// IPSW Object Properties
@property (nonatomic, readwrite) NSString *ipswPath;
@property (nonatomic, readwrite) NSString *iosVersion;
@property (nonatomic, readwrite) NSMutableArray *supportedModels;
@property (nonatomic, readwrite) BOOL releaseBuild;
@property (nonatomic, readwrite) BOOL bootRamdisk;
@property (nonatomic, readwrite) NSString *ibssName;
@property (nonatomic, readwrite) NSString *ibecName;
@property (nonatomic, readwrite) NSString *ibootName;
@property (nonatomic, readwrite) NSString *deviceTreeName;
@property (nonatomic, readwrite) NSString *trustCacheName;
@property (nonatomic, readwrite) NSString *kernelName;
@property (nonatomic, readwrite) NSString *aopfwName;
@property (nonatomic, readwrite) NSString *callanName;
@property (nonatomic, readwrite) NSString *touchName;
@property (nonatomic, readwrite) NSString *ispName;
@property (nonatomic, readwrite) NSString *restoreRamdiskName;
@property (nonatomic, readwrite) NSString *bootargs;
@property (nonatomic, readwrite) NSString *customLogoPath;
// Init //
- (id)initIPSWID;
// Getters //
- (NSString *)getIpswPath;
- (NSString *)getIosVersion;
- (NSMutableArray *)getSupportedModels;
- (BOOL)getReleaseBuild;
- (BOOL)getBootRamdisk;
- (NSString *)getIbssName;
- (NSString *)getIbecName;
- (NSString *)getIbootName;
- (NSString *)getDeviceTreeName;
- (NSString *)getTrustCacheName;
- (NSString *)getKernelName;
- (NSString *)getAopfwName;
- (NSString *)getCallanName;
- (NSString *)getTouchName;
- (NSString *)getIspName;
- (NSString *)getRestoreRamdiskName;
- (NSString *)getBootargs;
- (NSString *)getCustomLogoPath;
// Setters //
- (void)setIpswPath:(NSString *)ipswPath;
- (void)setIosVersion:(NSString *)iosVersion;
- (void)setSupportedModels:(NSMutableArray *)supportedModels;
- (void)setReleaseBuild:(BOOL)releaseBuild;
- (void)setBootRamdisk:(BOOL)bootRamdisk;
- (void)setIbssName:(NSString *)ibssName;
- (void)setIbecName:(NSString *)ibecName;
- (void)setIbootName:(NSString *)ibootName;
- (void)setDeviceTreeName:(NSString *)deviceTreeName;
- (void)setTrustCacheName:(NSString *)trustCacheName;
- (void)setKernelName:(NSString *)kernelName;
- (void)setAopfwName:(NSString *)aopfwName;
- (void)setCallanName:(NSString *)callanName;
- (void)setTouchName:(NSString *)touchName;
- (void)setIspName:(NSString *)ispName;
- (void)setRestoreRamdiskName:(NSString *)restoreRamdiskName;
- (void)setBootargs:(NSString *)bootargs;
- (void)setCustomLogoPath:(NSString *)customLogoPath;
// Teardown //
- (void)teardown;
// Instance //
+ (instancetype)initIPSW;
// End //
@end
