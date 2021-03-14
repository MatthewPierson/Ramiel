//
//  Device.h
//  Ramiel
//
//  Created by Matthew Pierson on 9/02/21.
//  Copyright © 2021 moski. All rights reserved.
//

#include "libirecovery.h"
#import <Foundation/Foundation.h>

@interface Device : NSObject
// Device Object Properties
@property (nonatomic, readwrite) irecv_client_t client;
@property (assign, readwrite) irecv_device_t device;
@property (assign, readwrite) struct irecv_device_info device_info;
@property (assign, readwrite) irecv_error_t error;
@property (nonatomic, readwrite) NSString *model;
@property (nonatomic, readwrite) NSString *cpid;
@property (nonatomic, readwrite) NSString *bdid;
@property (nonatomic, readwrite) NSString *hardware_model;
@property (nonatomic, readwrite) NSString *srtg;
@property (nonatomic, readwrite) NSString *serial_string;
@property (nonatomic, readwrite) uint64_t ecid;
@property (nonatomic, readwrite) int closed;
// Init //
- (id)initDeviceID;
// Getters //
- (NSString *)getModel;
- (NSString *)getCpid;
- (NSString *)getBdid;
- (NSString *)getHardware_model;
- (NSString *)getSrtg;
- (NSString *)getSerial_string;
- (uint64_t)getEcid;
- (int)getClosedState;
- (irecv_client_t)getIRECVClient;
- (irecv_error_t)getIRECVError;
- (irecv_device_t)getIRECVDevice;
- (struct irecv_device_info)getIRECVDeviceInfo;
// Setters //
- (void)setModel:(NSString *)modelString;
- (void)setCpid:(NSString *)CPIDString;
- (void)setBdid:(NSString *)BDIDString;
- (void)setHardware_model:(NSString *)Hardware_ModelString;
- (void)setSrtg:(NSString *)SRTGString;
- (void)setSerial_string:(NSString *)Serial_string;
- (void)setEcid:(uint64_t)ECIDValue;
- (void)setClosedState:(int)closedState;
- (void)setIRECVClient:(irecv_client_t)client;
- (void)setIRECVError:(irecv_error_t)error;
- (void)setIRECVDevice:(irecv_device_t)device;
- (void)setIRECVDeviceInfo:(irecv_client_t)client;
// Interactive Functions //
- (irecv_error_t)sendImage:(NSString *)filePath;
- (irecv_error_t)sendCMD:(NSString *)cmd;
- (irecv_error_t)resetConnection;
- (int)runCheckm8;
// IRECV Related //
- (void)reclaimDeviceClient;   // Reclaim currently claimed device handle
- (void)resetDeviceConnection; // Reset currently claimed device handle
- (void)closeDeviceConnection; // Close currently claimed device handle
// Teardown //
- (void)teardown;
// Instance //
+ (instancetype)initDevice;
// End //
@end
