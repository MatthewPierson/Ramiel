//
//  RamielView.h
//  Ramiel
//
//  Created by Matthew Pierson on 9/08/20.
//  Copyright © 2020 moski. All rights reserved.
//

#import "Device.h"
#import "IPSW.h"
#include "libirecovery.h"
#import <Cocoa/Cocoa.h>
#define FileHashDefaultChunkSizeForReadingData 4096

@interface RamielView : NSViewController

@property (weak) IBOutlet NSTextField *infoLabel;
@property (weak) IBOutlet NSTextField *modelLabel;
@property (strong, nonatomic) NSString *deviceModel;
@property (strong, nonatomic) NSString *deviceECID;
@property (strong, nonatomic) NSString *deviceAPNONCE;
@property (weak) IBOutlet NSTextField *titleLabel;
@property (weak) IBOutlet NSProgressIndicator *bootProgBar;
@property (weak) IBOutlet NSButton *bootButton;
@property (weak) IBOutlet NSButton *settingsButton;
@property (weak) IBOutlet NSTextField *downloadLabel;
@property (weak) IBOutlet NSTextField *secretLabel;
@property (weak) IBOutlet NSButton *selIPSWButton;
@property (weak) IBOutlet NSButton *dlIPSWButton;
@property (weak) IBOutlet NSComboBox *comboBoxList;
@property (weak) IBOutlet NSButton *dlButton;

+ (NSString *)img4toolCMD:(NSString *)cmd;
+ (NSString *)otherCMD:(NSString *)cmd;
+ (irecv_client_t)getClientExternal;
+ (IPSW *)getIpswInfoExternal;
+ (Device *)getConnectedDeviceInfo;
+ (void)errorHandler:(NSString *)errorMessage:(NSString *)errorTitle:(NSString *)detailedMessage;
+ (int)downloadFileFromIPSW:(NSString *)url:(NSString *)path:(NSString *)outpath;
+ (int)debugCheck;
+ (void)stopBackground;
+ (void)startBackground;

@end
