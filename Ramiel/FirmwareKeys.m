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
        [self setRestoreRamdiskIV:@"N/A"];
        [self setRestoreRamdiskKEY:@"N/A"];
        [self setIbootIV:@"N/A"];
        [self setIbootKEY:@"N/A"];
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
- (NSString *)getRestoreRamdiskIV {
    return self.restoreRamdiskIV;
};
- (NSString *)getRestoreRamdiskKEY {
    return self.restoreRamdiskKEY;
};
- (NSString *)getIbootIV {
    return self.ibootIV;
}
- (NSString *)getIbootKEY {
    return self.ibootKEY;
}
- (Boolean)getUsingLocalKeys {
    return self.isUsingLocalKeys;
}
- (Boolean)checkLocalKeys:(Device *)device:(IPSW *)ipsw {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    BOOL isDir;
    [[NSFileManager defaultManager]
        fileExistsAtPath:[NSString stringWithFormat:@"%@/Ramiel/Firmware_Keys/%@/%@/%@/", documentsDirectory,
                                                    ipsw.getIosVersion, device.getModel, device.getHardware_model]
             isDirectory:&isDir];
    if (isDir) {
        return TRUE;
    }
    return FALSE;
}
- (Boolean)writeFirmwareKeysToFile:(Device *)device:(IPSW *)ipsw {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    [[NSFileManager defaultManager]
              createDirectoryAtPath:[NSString stringWithFormat:@"%@/Ramiel/Firmware_Keys/%@/%@/%@", documentsDirectory,
                                                               ipsw.getIosVersion, device.getModel,
                                                               device.getHardware_model]
        withIntermediateDirectories:YES
                         attributes:nil
                              error:nil];
    if ([[NSFileManager defaultManager]
            fileExistsAtPath:[NSString stringWithFormat:@"%@/Ramiel/Firmware_Keys/%@/%@/%@/keys", documentsDirectory,
                                                        ipsw.getIosVersion, device.getModel,
                                                        device.getHardware_model]]) {
        [[NSFileManager defaultManager]
            removeItemAtPath:[NSString stringWithFormat:@"%@/Ramiel/Firmware_Keys/%@/%@/%@/keys", documentsDirectory,
                                                        ipsw.getIosVersion, device.getModel, device.getHardware_model]
                       error:nil];
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
    [dataToWrite setObject:self.getRestoreRamdiskIV forKey:@"Ramdisk_IV"];
    [dataToWrite setObject:self.getRestoreRamdiskKEY forKey:@"Ramdisk_KEY"];
    [dataToWrite setObject:self.getIbootIV forKey:@"iBoot_IV"];
    [dataToWrite setObject:self.getIbootKEY forKey:@"iBoot_KEY"];
    return [dataToWrite
        writeToFile:[NSString stringWithFormat:@"%@/Ramiel/Firmware_Keys/%@/%@/%@/keys", documentsDirectory,
                                               ipsw.getIosVersion, device.getModel, device.getHardware_model]
         atomically:YES];
}
- (Boolean)readFirmwareKeysFromFile:(Device *)device:(IPSW *)ipsw {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    if ([[NSFileManager defaultManager]
            fileExistsAtPath:[NSString stringWithFormat:@"%@/Ramiel/Firmware_Keys/%@/%@/%@/keys", documentsDirectory,
                                                        ipsw.getIosVersion, device.getModel,
                                                        device.getHardware_model]]) {
        NSDictionary *keysFile = [NSDictionary
            dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/Ramiel/Firmware_Keys/%@/%@/%@/keys",
                                                                    documentsDirectory, ipsw.getIosVersion,
                                                                    device.getModel, device.getHardware_model]];
        [self setIbssIV:[keysFile objectForKey:@"iBSS_IV"]];
        [self setIbssKEY:[keysFile objectForKey:@"iBSS_KEY"]];
        [self setIbecIV:[keysFile objectForKey:@"iBEC_IV"]];
        [self setIbecKEY:[keysFile objectForKey:@"iBEC_KEY"]];
        [self setDevicetreeIV:[keysFile objectForKey:@"Devicetree_IV"]];
        [self setDevicetreeKEY:[keysFile objectForKey:@"Devicetree_KEY"]];
        [self setKernelIV:[keysFile objectForKey:@"Kernel_IV"]];
        [self setKernelKEY:[keysFile objectForKey:@"Kernel_KEY"]];
        [self setRestoreRamdiskIV:[keysFile objectForKey:@"Ramdisk_IV"]];
        [self setRestoreRamdiskKEY:[keysFile objectForKey:@"Ramdisk_KEY"]];
        [self setIbootIV:[keysFile objectForKey:@"iBoot_IV"]];
        [self setIbootKEY:[keysFile objectForKey:@"iBoot_KEY"]];
        self.isUsingLocalKeys = TRUE;
        return TRUE;
    }
    self.isUsingLocalKeys = FALSE;
    return FALSE;
}
- (void)backupAllKeysForModel:(Device *)device {
    IPSW *ipsw = [[IPSW alloc] initIPSWID];
    NSMutableArray *savedVersions = [[NSMutableArray alloc] init];
    NSURL *wikiBuildTrainURL = [NSURL URLWithString:@"https://www.theiphonewiki.com/wiki/Firmware_Codenames"];
    NSURLRequest *request = [NSURLRequest requestWithURL:wikiBuildTrainURL];
    NSError *wikiError = NULL;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&wikiError];
    if (wikiError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [RamielView errorHandler:
                @"Error: Got an error while requesting Firmare_Codenames page.":
                    [NSString stringWithFormat:@"Error message: %@", wikiError.localizedDescription
            ]:[NSString stringWithFormat:@"%@", wikiError]];
        });
        return;
    }
    if (data != NULL) {
        NSString *dataString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        NSString *test = [NSArray
            arrayWithObject:[dataString
                                componentsSeparatedByString:
                                    @"<span class=\"mw-headline\" id=\"iOS.2FiPadOS\">iOS/iPadOS</span>"]][0][1];
        test = [test componentsSeparatedByString:@"<span id=\"iOS_(Apple_TV)\"></span>"][0];
        test = [test componentsSeparatedByString:@"<span class=\"mw-headline\" id=\"7.x\">7.x</span>"][1];
        NSArray *codeNames = [test componentsSeparatedByString:@"<tr>"];
        NSMutableArray *finalCodeNames = [[NSMutableArray alloc] init];
        NSMutableArray *finalCodeNamesVersion = [[NSMutableArray alloc] init];
        for (int i = 2; i < codeNames.count; i++) {
            if ([codeNames[i] containsString:@"rowspan"]) {
                NSArray *cringe = [codeNames[i] componentsSeparatedByString:@"\n"];
                NSString *version;
                if ([cringe[1] containsString:@"<td>"]) {
                    version = [cringe[1] stringByReplacingOccurrencesOfString:@"<td>" withString:@""];
                } else {
                    version = [cringe[1] componentsSeparatedByString:@"\">"][1];
                }
                NSString *buildname;
                if ([cringe[3] containsString:@"<td>"]) {
                    buildname =
                        [[cringe[3] componentsSeparatedByString:@"<td>"][1] stringByReplacingOccurrencesOfString:@"\n"
                                                                                                      withString:@""];
                    [finalCodeNames addObject:buildname];
                    [finalCodeNamesVersion addObject:version];
                } else {
                    buildname =
                        [[cringe[3] componentsSeparatedByString:@"\">"][1] stringByReplacingOccurrencesOfString:@"\n"
                                                                                                     withString:@""];
                    int rowCount = [[[cringe[3] componentsSeparatedByString:@"\">"][0]
                        componentsSeparatedByString:@"=\""][1] intValue];
                    [finalCodeNames addObject:buildname];
                    [finalCodeNamesVersion addObject:version];
                    for (int k = 0; k < (rowCount - 1); k++) {
                        i++;
                        if (![codeNames[i] containsString:@"<small>"]) {
                            [finalCodeNames addObject:buildname];
                            cringe = [codeNames[i] componentsSeparatedByString:@"\n"];
                            NSString *version = [cringe[1] stringByReplacingOccurrencesOfString:@"<td>" withString:@""];
                            [finalCodeNamesVersion addObject:version];
                        }
                    }
                }
            } else {
                if (!([codeNames[i] containsString:@"Version"] ||
                      [codeNames[i] containsString:@"<small>"])) { // Make sure
                    NSArray *cringe = [codeNames[i] componentsSeparatedByString:@"\n"];
                    NSString *version = [cringe[1] stringByReplacingOccurrencesOfString:@"<td>" withString:@""];
                    NSString *buildname = [cringe[3] stringByReplacingOccurrencesOfString:@"<td>" withString:@""];
                    [finalCodeNames addObject:buildname];
                    [finalCodeNamesVersion addObject:version];
                }
            }
        }
        NSURLRequest *request =
            [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://api.ipsw.me/v4/"
                                                                                         @"device/%@?type=ipsw",
                                                                                         [device getModel]]]];
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
        NSError *jsonError;
        NSDictionary *parsedThing = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        NSMutableArray *buildids = [[NSMutableArray alloc] init];
        NSMutableArray *firms = [[NSMutableArray alloc] init];
        if (parsedThing == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [RamielView errorHandler:
                    @"Failed to get list of iOS versions":@"Please ensure you have an internet connection"
                                                         :[NSString stringWithFormat:@"%@", data]];
            });
            return;
        } else {
            NSArray *firmwares = parsedThing[@"firmwares"];
            int dictSize = (int)firmwares.count;
            for (int i = 0; i < dictSize; i++) {
                [buildids addObject:(NSString *)[NSString stringWithFormat:@"%@", firmwares[i][@"buildid"]]];
                [firms addObject:(NSString *)[NSString stringWithFormat:@"%@", firmwares[i][@"version"]]];
            }
        }
        for (int i = 0; i < finalCodeNamesVersion.count; i++) {
            NSString *buildid;
            for (int k = 0; k < buildids.count; k++) {
                if ([finalCodeNamesVersion[i] containsString:firms[k]]) {
                    buildid = buildids[k];
                    [ipsw setIosVersion:firms[k]];
                    break;
                }
            }
            if (buildid != nil) {
                NSDictionary *manifest = @{@"codename": finalCodeNames[i], @"buildid": buildid};
                NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                NSString *documentsDirectory = [paths objectAtIndex:0];
                if (![[NSFileManager defaultManager]
                        fileExistsAtPath:[NSString stringWithFormat:@"%@/Ramiel/Firmware_Keys/%@/%@/%@/keys",
                                                                    documentsDirectory, ipsw.getIosVersion,
                                                                    device.getModel, device.getHardware_model]]) {
                    if ([self fetchKeysFromWiki:device:ipsw:manifest]) {
                        if ([self writeFirmwareKeysToFile:device:ipsw]) {
                            [savedVersions addObject:[ipsw getIosVersion]];
                        }
                    } else {
                        // Failed to get keys, maybe inform user here?
                        NSLog(@"failed to get keys for version %@", ipsw.getIosVersion);
                    }
                }
            }
            // Reset keys data before looping again
            [self teardown];
            [self setIbssIV:@"N/A"];
            [self setIbssKEY:@"N/A"];
            [self setIbecIV:@"N/A"];
            [self setIbecKEY:@"N/A"];
            [self setKernelIV:@"N/A"];
            [self setKernelKEY:@"N/A"];
            [self setDevicetreeIV:@"N/A"];
            [self setDevicetreeKEY:@"N/A"];
            [self setRestoreRamdiskIV:@"N/A"];
            [self setRestoreRamdiskKEY:@"N/A"];
            [self setIbootIV:@"N/A"];
            [self setIbootKEY:@"N/A"];
        }
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [RamielView errorHandler:
                @"Error: Got null data back while requesting Firmware_Codenames page.":
                    @"Please check that theiphonewiki site is not down.":@"N/A"];
        });
        return;
    }
    NSString *text = @"";
    for (int i = 0; i < savedVersions.count; i++) {
        if (i == savedVersions.count - 1) {
            text = [NSString stringWithFormat:@"%@ %@", text, savedVersions[i]];
        } else {
            text = [NSString stringWithFormat:@"%@ %@,", text, savedVersions[i]];
        }
    }
    if (savedVersions.count == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAlert *alert = [[NSAlert alloc] init];
            [alert
                setMessageText:@"FirmwareKeys: All firmware keys have been backed up previously, no work to be done."];
            [alert setInformativeText:text];
            alert.window.titlebarAppearsTransparent = TRUE;
            [alert runModal];
        });
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"FirmwareKeys: Backed up firmware keys for the following iOS versions:"];
        [alert setInformativeText:text];
        alert.window.titlebarAppearsTransparent = TRUE;
        [alert runModal];
    });
    return;
}
- (Boolean)fetchKeysFromWiki:(Device *)device:(IPSW *)ipsw:(NSDictionary *)manifest {
    NSString *codename;
    NSString *buildid;
    if ([manifest objectForKey:@"codename"]) {
        codename = [manifest objectForKey:@"codename"];
        buildid = [manifest objectForKey:@"buildid"];
    } else {
        NSArray *buildID = [manifest objectForKey:@"BuildIdentities"];
        codename = buildID[0][@"Info"][@"BuildTrain"];
        buildid = [manifest objectForKey:@"ProductBuildVersion"];
    }
    NSURL *wikiURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.theiphonewiki.com/wiki/%@_%@_(%@)",
                                                                     codename, buildid, [device getModel]]];
    NSURLRequest *request = [NSURLRequest requestWithURL:wikiURL];
    NSError *wikiError = NULL;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&wikiError];
    if (wikiError && ![manifest objectForKey:@"local"]) {
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
        if ([RamielView debugCheck]) {
            NSLog(@"Got response from theiphonewiki: %@", dataString);
        }
        if ([dataString containsString:@"There is currently no text in this page"] &&
            ![manifest objectForKey:@"local"]) { // No keys but still
                                                 // valid page
            dispatch_async(dispatch_get_main_queue(), ^{
                [RamielView errorHandler:
                    @"No firmware keys found":@"Please check detailed log for more information"
                                             :[NSString stringWithFormat:
                                                            @"Theiphonewiki didn't have keys for this device + "
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

                NSArray *ibecKEYSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-ibec-key\">"];
                NSArray *ibecKEYSplit2 = [ibecKEYSplit1[1] componentsSeparatedByString:@"</code></li>"];

                [self setIbecKEY:ibecKEYSplit2[0]];

                NSArray *ibssKEYSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-ibss-key\">"];
                NSArray *ibssKEYSplit2 = [ibssKEYSplit1[1] componentsSeparatedByString:@"</code></li>"];

                [self setIbssKEY:ibssKEYSplit2[0]];

                if ([[ipsw getIosVersion] containsString:@"7."] || [[ipsw getIosVersion] containsString:@"8."] ||
                    [[ipsw getIosVersion] containsString:@"9."]) {

                    NSArray *devicetreeIVSplit1 =
                        [dataString componentsSeparatedByString:@"id=\"keypage-devicetree-iv\">"];
                    NSArray *devicetreeIVSplit2 = [devicetreeIVSplit1[1] componentsSeparatedByString:@"</code>"];

                    [self setDevicetreeIV:devicetreeIVSplit2[0]];

                    NSArray *devicetreeKEYSplit1 =
                        [dataString componentsSeparatedByString:@"id=\"keypage-devicetree-key\">"];
                    NSArray *devicetreeKEYSplit2 = [devicetreeKEYSplit1[1] componentsSeparatedByString:@"</code>"];

                    [self setDevicetreeKEY:devicetreeKEYSplit2[0]];

                    NSArray *kernelIVSplit1 =
                        [dataString componentsSeparatedByString:@"id=\"keypage-kernelcache-iv\">"];
                    NSArray *kernelIVSplit2 = [kernelIVSplit1[1] componentsSeparatedByString:@"</code>"];

                    [self setKernelIV:kernelIVSplit2[0]];

                    NSArray *kernelKEYSplit1 =
                        [dataString componentsSeparatedByString:@"id=\"keypage-kernelcache-key\">"];
                    NSArray *kernelKEYSplit2 = [kernelKEYSplit1[1] componentsSeparatedByString:@"</code>"];

                    [self setKernelKEY:kernelKEYSplit2[0]];

                    NSArray *restoreRamdiskIVSplit1 =
                        [dataString componentsSeparatedByString:@"id=\"keypage-restoreramdisk-iv\">"];
                    NSArray *restoreRamdiskIVSplit2 =
                        [restoreRamdiskIVSplit1[1] componentsSeparatedByString:@"</code>"];

                    [self setRestoreRamdiskIV:restoreRamdiskIVSplit2[0]];

                    NSArray *restoreRamdiskKEYSplit1 =
                        [dataString componentsSeparatedByString:@"id=\"keypage-restoreramdisk-key\">"];
                    NSArray *restoreRamdiskKEYSplit2 =
                        [restoreRamdiskKEYSplit1[1] componentsSeparatedByString:@"</code>"];

                    [self setRestoreRamdiskKEY:restoreRamdiskKEYSplit2[0]];

                    NSArray *ibootIVSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-iboot-iv\">"];
                    NSArray *ibootIVSplit2 = [ibootIVSplit1[1] componentsSeparatedByString:@"</code>"];

                    [self setIbootIV:ibootIVSplit2[0]];

                    NSArray *ibootKEYSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-iboot-key\">"];
                    NSArray *ibootKEYSplit2 = [ibootKEYSplit1[1] componentsSeparatedByString:@"</code>"];

                    [self setIbootKEY:ibootKEYSplit2[0]];
                }

                return TRUE;

            } else {

                NSArray *ibecIVSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-ibec2-iv\">"];
                NSArray *ibecIVSplit2 = [ibecIVSplit1[1] componentsSeparatedByString:@"</code></li>"];

                [self setIbecIV:ibecIVSplit2[0]];

                NSArray *ibssIVSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-ibss2-iv\">"];
                NSArray *ibssIVSplit2 = [ibssIVSplit1[1] componentsSeparatedByString:@"</code></li>"];

                [self setIbssIV:ibssIVSplit2[0]];

                NSArray *ibecKEYSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-ibec2-key\">"];
                NSArray *ibecKEYSplit2 = [ibecKEYSplit1[1] componentsSeparatedByString:@"</code></li>"];

                [self setIbecKEY:ibecKEYSplit2[0]];

                NSArray *ibssKEYSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-ibss2-key\">"];
                NSArray *ibssKEYSplit2 = [ibssKEYSplit1[1] componentsSeparatedByString:@"</code></li>"];

                [self setIbssKEY:ibssKEYSplit2[0]];

                if ([[ipsw getIosVersion] containsString:@"7."] || [[ipsw getIosVersion] containsString:@"8."] ||
                    [[ipsw getIosVersion] containsString:@"9."]) {

                    NSArray *devicetreeIVSplit1 =
                        [dataString componentsSeparatedByString:@"id=\"keypage-devicetree2-iv\">"];
                    NSArray *devicetreeIVSplit2 = [devicetreeIVSplit1[1] componentsSeparatedByString:@"</code>"];

                    [self setDevicetreeIV:devicetreeIVSplit2[0]];

                    NSArray *devicetreeKEYSplit1 =
                        [dataString componentsSeparatedByString:@"id=\"keypage-devicetree2-key\">"];
                    NSArray *devicetreeKEYSplit2 = [devicetreeKEYSplit1[1] componentsSeparatedByString:@"</code>"];

                    [self setDevicetreeKEY:devicetreeKEYSplit2[0]];

                    NSArray *kernelIVSplit1 =
                        [dataString componentsSeparatedByString:@"id=\"keypage-kernelcache2-iv\">"];
                    NSArray *kernelIVSplit2 = [kernelIVSplit1[1] componentsSeparatedByString:@"</code>"];

                    [self setKernelIV:kernelIVSplit2[0]];

                    NSArray *kernelKEYSplit1 =
                        [dataString componentsSeparatedByString:@"id=\"keypage-kernelcache2-key\">"];
                    NSArray *kernelKEYSplit2 = [kernelKEYSplit1[1] componentsSeparatedByString:@"</code>"];

                    [self setKernelKEY:kernelKEYSplit2[0]];

                    NSArray *restoreRamdiskIVSplit1 =
                        [dataString componentsSeparatedByString:@"id=\"keypage-restoreramdisk2-iv\">"];
                    NSArray *restoreRamdiskIVSplit2 =
                        [restoreRamdiskIVSplit1[1] componentsSeparatedByString:@"</code>"];

                    [self setRestoreRamdiskIV:restoreRamdiskIVSplit2[0]];

                    NSArray *restoreRamdiskKEYSplit1 =
                        [dataString componentsSeparatedByString:@"id=\"keypage-restoreramdisk2-key\">"];
                    NSArray *restoreRamdiskKEYSplit2 =
                        [restoreRamdiskKEYSplit1[1] componentsSeparatedByString:@"</code>"];

                    [self setRestoreRamdiskKEY:restoreRamdiskKEYSplit2[0]];

                    NSArray *ibootIVSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-iboot2-iv\">"];
                    NSArray *ibootIVSplit2 = [ibootIVSplit1[1] componentsSeparatedByString:@"</code>"];

                    [self setIbootIV:ibootIVSplit2[0]];

                    NSArray *ibootKEYSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-iboot2-key\">"];
                    NSArray *ibootKEYSplit2 = [ibootKEYSplit1[1] componentsSeparatedByString:@"</code>"];

                    [self setIbootKEY:ibootKEYSplit2[0]];
                }

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

            if ([[ipsw getIosVersion] containsString:@"7."] || [[ipsw getIosVersion] containsString:@"8."] ||
                [[ipsw getIosVersion] containsString:@"9."]) {

                NSArray *devicetreeIVSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-devicetree-iv\">"];
                NSArray *devicetreeIVSplit2 = [devicetreeIVSplit1[1] componentsSeparatedByString:@"</code>"];

                [self setDevicetreeIV:devicetreeIVSplit2[0]];

                NSArray *devicetreeKEYSplit1 =
                    [dataString componentsSeparatedByString:@"id=\"keypage-devicetree-key\">"];
                NSArray *devicetreeKEYSplit2 = [devicetreeKEYSplit1[1] componentsSeparatedByString:@"</code>"];

                [self setDevicetreeKEY:devicetreeKEYSplit2[0]];

                NSArray *kernelIVSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-kernelcache-iv\">"];
                NSArray *kernelIVSplit2 = [kernelIVSplit1[1] componentsSeparatedByString:@"</code>"];

                [self setKernelIV:kernelIVSplit2[0]];

                NSArray *kernelKEYSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-kernelcache-key\">"];
                NSArray *kernelKEYSplit2 = [kernelKEYSplit1[1] componentsSeparatedByString:@"</code>"];

                [self setKernelKEY:kernelKEYSplit2[0]];

                NSArray *restoreRamdiskIVSplit1 =
                    [dataString componentsSeparatedByString:@"id=\"keypage-restoreramdisk-iv\">"];
                NSArray *restoreRamdiskIVSplit2 = [restoreRamdiskIVSplit1[1] componentsSeparatedByString:@"</code>"];

                [self setRestoreRamdiskIV:restoreRamdiskIVSplit2[0]];

                NSArray *restoreRamdiskKEYSplit1 =
                    [dataString componentsSeparatedByString:@"id=\"keypage-restoreramdisk-key\">"];
                NSArray *restoreRamdiskKEYSplit2 = [restoreRamdiskKEYSplit1[1] componentsSeparatedByString:@"</code>"];

                [self setRestoreRamdiskKEY:restoreRamdiskKEYSplit2[0]];

                NSArray *ibootIVSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-iboot-iv\">"];
                NSArray *ibootIVSplit2 = [ibootIVSplit1[1] componentsSeparatedByString:@"</code>"];

                [self setIbootIV:ibootIVSplit2[0]];

                NSArray *ibootKEYSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-iboot-key\">"];
                NSArray *ibootKEYSplit2 = [ibootKEYSplit1[1] componentsSeparatedByString:@"</code>"];

                [self setIbootKEY:ibootKEYSplit2[0]];
            }

            return TRUE;
        }
    } else {
        if (![manifest objectForKey:@"local"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [RamielView errorHandler:
                    @"Failed to get firmware keys":@"Please check detailed log for more information"
                                                  :[NSString stringWithFormat:@"%@", data]];
            });
            return FALSE;
        }
        return TRUE;
    }
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
    [self setRestoreRamdiskIV:NULL];
    [self setRestoreRamdiskKEY:NULL];
    [self setIbootIV:NULL];
    [self setIbootKEY:NULL];
    [self setIsUsingLocalKeys:NULL];
}
+ (instancetype)initFirmwareKeys {
    return [[FirmwareKeys alloc] initFirmwareKeysID];
}

@end
