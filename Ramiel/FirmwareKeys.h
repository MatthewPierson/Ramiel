//
//  FirmwareKeys.h
//  Ramiel
//
//  Created by Matthew Pierson on 28/03/21.
//  Copyright © 2021 moski. All rights reserved.
//

#import "Device.h"
#import "IPSW.h"
#import <Foundation/Foundation.h>

@interface FirmwareKeys : NSObject
// FirmwareKeys Object Properties //
@property (nonatomic, readwrite) NSString *ibssIV;
@property (nonatomic, readwrite) NSString *ibssKEY;
@property (nonatomic, readwrite) NSString *ibecIV;
@property (nonatomic, readwrite) NSString *ibecKEY;
@property (nonatomic, readwrite) NSString *kernelIV;
@property (nonatomic, readwrite) NSString *kernelKEY;
@property (nonatomic, readwrite) NSString *devicetreeIV;
@property (nonatomic, readwrite) NSString *devicetreeKEY;
@property (nonatomic, readwrite) NSString *restoreRamdiskIV;
@property (nonatomic, readwrite) NSString *restoreRamdiskKEY;
@property (nonatomic, readwrite) NSString *ibootIV;
@property (nonatomic, readwrite) NSString *ibootKEY;
@property (nonatomic, readwrite) Boolean isUsingLocalKeys;
// Init //
- (id)initFirmwareKeysID;
// Getters //
- (NSString *)getIbssIV;
- (NSString *)getIbssKEY;
- (NSString *)getIbecIV;
- (NSString *)getIbecKEY;
- (NSString *)getKernelIV;
- (NSString *)getKernelKEY;
- (NSString *)getDevicetreeIV;
- (NSString *)getDevicetreeKEY;
- (NSString *)getRestoreRamdiskIV;
- (NSString *)getRestoreRamdiskKEY;
- (NSString *)getIbootIV;
- (NSString *)getIbootKEY;
- (Boolean)getUsingLocalKeys;
// Setters //
- (void)setIbssIV:(NSString *)ibssIV;
- (void)setIbssKEY:(NSString *)ibssKEY;
- (void)setIbecIV:(NSString *)ibecIV;
- (void)setIbecKEY:(NSString *)ibecKEY;
- (void)setKernelIV:(NSString *)kernelIV;
- (void)setKernelKEY:(NSString *)kernelKEY;
- (void)setDevicetreeIV:(NSString *)devicetreeIV;
- (void)setDevicetreeKEY:(NSString *)devicetreeKEY;
- (void)setRestoreRamdiskIV:(NSString *)restoreRamdiskIV;
- (void)setRestoreRamdiskKEY:(NSString *)restoreRamdiskKEY;
- (void)setIbootIV:(NSString *)ibootIV;
- (void)setIbootKEY:(NSString *)ibootKEY;
- (void)setIsUsingLocalKeys:(Boolean)isUsingLocalKeys;
// Other Methods //
- (Boolean)checkLocalKeys:(Device *)device:(IPSW *)ipsw;
- (Boolean)writeFirmwareKeysToFile:(Device *)device:(IPSW *)ipsw;
- (Boolean)readFirmwareKeysFromFile:(Device *)device:(IPSW *)ipsw;
- (void)backupAllKeysForModel:(Device *)device;
- (Boolean)fetchKeysFromWiki:(Device *)device:(IPSW *)ipsw:(NSDictionary *)manifest;
// Teardown //
- (void)teardown;
// Instance //
+ (instancetype)initFirmwareKeys;
// End //
@end
