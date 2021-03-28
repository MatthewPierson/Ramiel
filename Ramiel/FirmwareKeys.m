//
//  FirmwareKeys.m
//  Ramiel
//
//  Created by Matthew Pierson on 28/03/21.
//  Copyright © 2021 moski. All rights reserved.
//

#import "FirmwareKeys.h"
#import "RamielView.h"
#import <Foundation/Foundation.h>

@implementation FirmwareKeys

- (id)initFirmwareKeysID {
    self = [super self];
    if (self) {
        [self setIbssIV:@"N/A"];
        [self setIbssKEY:@"N/A"];
        [self setIbecIV:@"N/A"];
        [self setIbecKEY:@"N/A"];
        [self setKernelIV:@"N/A"];
        [self setKernelKEY:@"N/A"];
        [self setDevicetreeIV:@"N/A"];
        [self setDevicetreeKEY:@"N/A"];
        return self;
    }
    return NULL;
}

- (NSString *)getIbssIV {
    return self.ibssIV;
};
- (NSString *)getIbssKEY {
    return self.ibssKEY;
};
- (NSString *)getIbecIV {
    return self.ibecIV;
};
- (NSString *)getIbecKEY {
    return self.ibecKEY;
};
- (NSString *)getKernelIV {
    return self.kernelIV;
};
- (NSString *)getKernelKEY {
    return self.kernelKEY;
};
- (NSString *)getDevicetreeIV {
    return self.devicetreeIV;
};
- (NSString *)getDevicetreeKEY {
    return self.devicetreeKEY;
};
- (Boolean)getUsingLocalKeys {
    return self.isUsingLocalKeys;
}
- (Boolean)checkLocalKeys:(Device *)device
                         :(IPSW *)ipsw{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    BOOL isDir;
    [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/Ramiel/Firmware_Keys/%@/%@/%@/", documentsDirectory, ipsw.getIosVersion, device.getModel, device.getHardware_model] isDirectory:&isDir];
    if (isDir) {
        return TRUE;
    }
    return FALSE;
}
- (Boolean)writeFirmwareKeysToFile:(Device *)device
                                  :(IPSW *)ipsw {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    [[NSFileManager defaultManager] createDirectoryAtPath:[NSString stringWithFormat:@"%@/Ramiel/Firmware_Keys/%@/%@/%@", documentsDirectory, ipsw.getIosVersion, device.getModel, device.getHardware_model] withIntermediateDirectories:YES attributes:nil error:nil];
    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/Ramiel/Firmware_Keys/%@/%@/%@/keys", documentsDirectory, ipsw.getIosVersion, device.getModel, device.getHardware_model]]) {
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/Ramiel/Firmware_Keys/%@/%@/%@/keys", documentsDirectory, ipsw.getIosVersion, device.getModel, device.getHardware_model] error:nil];
    }
    NSMutableDictionary *dataToWrite = [[NSMutableDictionary alloc] initWithCapacity:8];
    [dataToWrite setObject:self.getIbssIV forKey:@"iBSS_IV"];
    [dataToWrite setObject:self.getIbssKEY forKey:@"iBSS_KEY"];
    [dataToWrite setObject:self.getIbecIV forKey:@"iBEC_IV"];
    [dataToWrite setObject:self.getIbecKEY forKey:@"iBEC_KEY"];
    [dataToWrite setObject:self.getKernelIV forKey:@"Kernel_IV"];
    [dataToWrite setObject:self.getKernelKEY forKey:@"Kernel_KEY"];
    [dataToWrite setObject:self.getDevicetreeIV forKey:@"Devicetree_IV"];
    [dataToWrite setObject:self.getDevicetreeKEY forKey:@"Devicetree_KEY"];
    return [dataToWrite writeToFile:[NSString stringWithFormat:@"%@/Ramiel/Firmware_Keys/%@/%@/%@/keys", documentsDirectory, ipsw.getIosVersion, device.getModel, device.getHardware_model] atomically:YES];
}
- (Boolean)readFirmwareKeysFromFile:(Device *)device
                                   :(IPSW *)ipsw {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/Ramiel/Firmware_Keys/%@/%@/%@/keys", documentsDirectory, ipsw.getIosVersion, device.getModel, device.getHardware_model]]) {
        NSDictionary *keysFile = [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/Ramiel/Firmware_Keys/%@/%@/%@/keys", documentsDirectory, ipsw.getIosVersion, device.getModel, device.getHardware_model]];
        self.ibssIV = [keysFile objectForKey:@"iBSS_IV"];
        self.ibssKEY = [keysFile objectForKey:@"iBSS_KEY"];
        self.ibecIV = [keysFile objectForKey:@"iBEC_IV"];
        self.ibecKEY = [keysFile objectForKey:@"iBEC_KEY"];
        self.devicetreeIV = [keysFile objectForKey:@"Devicetree_IV"];
        self.devicetreeKEY = [keysFile objectForKey:@"Devicetree_KEY"];
        self.kernelIV = [keysFile objectForKey:@"Kernel_IV"];
        self.kernelKEY = [keysFile objectForKey:@"Kernel_KEY"];
        self.isUsingLocalKeys = TRUE;
        return TRUE;
    }
    self.isUsingLocalKeys = FALSE;
    return FALSE;
}
- (void)backupAllKeysForModel:(Device *)device
                                :(IPSW *)ipsw {
    // Need to figure out a way to get the BuildCodeName for every iOS version without downloading each versions BuildManifest
    // ipsw.me v4 api can give us keys but most are missing so :(
    // For now leave this stubbed and I'll look at it more in the future
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Error: Backing up all keys for a device model from theiphonewiki is not currently implemented. Please check back later"];
    alert.window.titlebarAppearsTransparent = TRUE;
    [alert runModal];
    return;
}
- (Boolean)fetchKeysFromWiki:(Device *)device
                            :(IPSW *)ipsw
                            :(NSDictionary *)manifest{
    NSArray *buildID = [manifest objectForKey:@"BuildIdentities"];
    NSURL *wikiURL =
        [NSURL URLWithString:[NSString stringWithFormat:@"https://www.theiphonewiki.com/wiki/%@_%@_(%@)",
                                                        buildID[0][@"Info"][@"BuildTrain"],
                                                        [manifest objectForKey:@"ProductBuildVersion"],
                                                        [device getModel]]];
    NSURLRequest *request = [NSURLRequest requestWithURL:wikiURL];
    NSError *wikiError = NULL;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&wikiError];
    if (wikiError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [RamielView errorHandler:
                @"Error while getting firmware keys":
                    [NSString stringWithFormat:@"Encountered an error while attempting to fetch keys from "
                                               @"theiphonewiki.\nError Description: %@\nError Code: %ld",
                                               [wikiError localizedDescription], (long)wikiError.code
            ]:[NSString stringWithFormat:@"Full Error Message: %@", wikiError]];
            
        });
        return FALSE;
    }
    if (data != NULL) {

        NSString *dataString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        if ([RamielView debugCheck])
            NSLog(@"Got response from theiphonewiki: %@", dataString);
        if ([dataString containsString:@"There is currently no text in this page"]) { // No keys but still
                                                                                      // valid page
            dispatch_async(dispatch_get_main_queue(), ^{
                [RamielView errorHandler:
                    @"No firmware keys found":
                        @"Please check detailed log for more information":
                            [NSString
                                stringWithFormat:@"Theiphonewiki didn't have keys for this device + "
                                                 @"firmware combination. Please ensure that the page at "
                                                 @"the following URL doesn't contain keys, if it does open "
                                                 @"an issue on GitHub and send me this log\n\n%@",
                                                 [wikiURL absoluteURL]]];
                
            });
            return FALSE;
        }
        if ([dataString containsString:@"/>&#160;("]) {

            NSArray *model1 = [dataString componentsSeparatedByString:@"/>&#160;("];

            model1 = [model1[1] componentsSeparatedByString:@")&"];

            if ([[model1[0] uppercaseString]
                    isEqual:[[device getHardware_model] uppercaseString]]) { // Make sure we get the
                                                                                 // right keys

                NSArray *ibecIVSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-ibec-iv\">"];
                NSArray *ibecIVSplit2 = [ibecIVSplit1[1] componentsSeparatedByString:@"</code></li>"];

                [self setIbecIV:ibecIVSplit2[0]];

                NSArray *ibssIVSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-ibss-iv\">"];
                NSArray *ibssIVSplit2 = [ibssIVSplit1[1] componentsSeparatedByString:@"</code></li>"];

                [self setIbssIV:ibssIVSplit2[0]];

                NSArray *ibecKEYSplit1 =
                    [dataString componentsSeparatedByString:@"id=\"keypage-ibec-key\">"];
                NSArray *ibecKEYSplit2 = [ibecKEYSplit1[1] componentsSeparatedByString:@"</code></li>"];

                [self setIbecKEY:ibecKEYSplit2[0]];

                NSArray *ibssKEYSplit1 =
                    [dataString componentsSeparatedByString:@"id=\"keypage-ibss-key\">"];
                NSArray *ibssKEYSplit2 = [ibssKEYSplit1[1] componentsSeparatedByString:@"</code></li>"];

                [self setIbssKEY:ibssKEYSplit2[0]];
                return TRUE;

            } else {

                NSArray *ibecIVSplit1 =
                    [dataString componentsSeparatedByString:@"id=\"keypage-ibec2-iv\">"];
                NSArray *ibecIVSplit2 = [ibecIVSplit1[1] componentsSeparatedByString:@"</code></li>"];

                [self setIbecIV:ibecIVSplit2[0]];

                NSArray *ibssIVSplit1 =
                    [dataString componentsSeparatedByString:@"id=\"keypage-ibss2-iv\">"];
                NSArray *ibssIVSplit2 = [ibssIVSplit1[1] componentsSeparatedByString:@"</code></li>"];

                [self setIbssIV:ibssIVSplit2[0]];

                NSArray *ibecKEYSplit1 =
                    [dataString componentsSeparatedByString:@"id=\"keypage-ibec2-key\">"];
                NSArray *ibecKEYSplit2 = [ibecKEYSplit1[1] componentsSeparatedByString:@"</code></li>"];

                [self setIbecKEY:ibecKEYSplit2[0]];

                NSArray *ibssKEYSplit1 =
                    [dataString componentsSeparatedByString:@"id=\"keypage-ibss2-key\">"];
                NSArray *ibssKEYSplit2 = [ibssKEYSplit1[1] componentsSeparatedByString:@"</code></li>"];

                [self setIbssKEY:ibssKEYSplit2[0]];
                return TRUE;
            }

        } else {

            NSArray *ibecIVSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-ibec-iv\">"];
            NSArray *ibecIVSplit2 = [ibecIVSplit1[1] componentsSeparatedByString:@"</code></li>"];

            [self setIbecIV:ibecIVSplit2[0]];

            NSArray *ibssIVSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-ibss-iv\">"];
            NSArray *ibssIVSplit2 = [ibssIVSplit1[1] componentsSeparatedByString:@"</code></li>"];

            [self setIbssIV:ibssIVSplit2[0]];

            NSArray *ibecKEYSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-ibec-key\">"];
            NSArray *ibecKEYSplit2 = [ibecKEYSplit1[1] componentsSeparatedByString:@"</code></li>"];

            [self setIbecKEY:ibecKEYSplit2[0]];

            NSArray *ibssKEYSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-ibss-key\">"];
            NSArray *ibssKEYSplit2 = [ibssKEYSplit1[1] componentsSeparatedByString:@"</code></li>"];

            [self setIbssKEY:ibssKEYSplit2[0]];
            
            return TRUE;
        }
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [RamielView errorHandler:
                @"Failed to get firmware keys":@"Please check detailed log for more information"
                                    :[NSString stringWithFormat:@"%@", data]];
        });
        return FALSE;
    }
    return FALSE;
}
- (void)teardown {
    [self setIbssIV:NULL];
    [self setIbssKEY:NULL];
    [self setIbecIV:NULL];
    [self setIbecKEY:NULL];
    [self setKernelIV:NULL];
    [self setKernelKEY:NULL];
    [self setDevicetreeIV:NULL];
    [self setDevicetreeKEY:NULL];
    [self setIsUsingLocalKeys:NULL];
}
+ (instancetype)initFirmwareKeys {
    return [[FirmwareKeys alloc] initFirmwareKeysID];
}

@end
