//
//  APNonceSetterViewController.m
//  Ramiel
//
//  Created by Matthew Pierson on 4/03/21.
//  Copyright © 2021 moski. All rights reserved.
//

#import "APNonceSetterViewController.h"
#import "../Pods/SSZipArchive/SSZipArchive/SSZipArchive.h"
#import "Device.h"
#import "IPSW.h"
#import "RamielView.h"
#include "kairos.h"

@implementation APNonceSetterViewController

NSString *generatorString;
NSString *apnonceextractPath;
IPSW *apnonceIPSW;
Device *apnonceDevice;
irecv_error_t apnonceerror = 0;
int apnoncecheckNum = 0;
int apnoncecon = 0;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);
    apnonceIPSW = [[IPSW alloc] initIPSWID];
    apnonceDevice = [RamielView getConnectedDeviceInfo];
    [apnonceDevice resetConnection];
    [apnonceDevice setIRECVDeviceInfo:[apnonceDevice getIRECVClient]];
    [apnonceDevice setModel:[NSString stringWithFormat:@"%s", apnonceDevice.getIRECVDevice->product_type]];
    [apnonceDevice setHardware_model:[NSString stringWithFormat:@"%s", apnonceDevice.getIRECVDevice->hardware_model]];
    [apnonceDevice setIRECVDeviceInfo:(apnonceDevice.getIRECVClient)];
    [apnonceDevice setCpid:[NSString stringWithFormat:@"0x%04x", apnonceDevice.getIRECVDeviceInfo.cpid]];
    if (apnonceDevice.getIRECVDeviceInfo.bdid > 9) {
        [apnonceDevice setBdid:[NSString stringWithFormat:@"0x%u", apnonceDevice.getIRECVDeviceInfo.bdid]];
    } else {
        [apnonceDevice setBdid:[NSString stringWithFormat:@"0x0%u", apnonceDevice.getIRECVDeviceInfo.bdid]];
    }
    [apnonceDevice setSrtg:[NSString stringWithFormat:@"%s", apnonceDevice.getIRECVDeviceInfo.srtg]];
    [apnonceDevice setSerial_string:[NSString stringWithFormat:@"%s", apnonceDevice.getIRECVDeviceInfo.serial_string]];
    [apnonceDevice setEcid:apnonceDevice.getIRECVDeviceInfo.ecid];
    [apnonceDevice setClosedState:0];
}

- (IBAction)setAPNonceButton:(NSButton *)sender {
    if ([self->_generatorEntry.stringValue isEqualToString:@""]) {
        generatorString = @"0x1111111111111111";
    } else {
        if ([self->_generatorEntry.stringValue containsString:@".shsh"] ||
            [self->_generatorEntry.stringValue containsString:@".shsh2"]) {
            generatorString = [[NSDictionary dictionaryWithContentsOfFile:self->_generatorEntry.stringValue]
                objectForKey:@"generator"];
            if (generatorString == nil) {
                NSAlert *apnonceError = [[NSAlert alloc] init];
                [apnonceError setMessageText:@"Error: SHSH file does not contain a generator..."];
                [apnonceError setInformativeText:@"You cannot use this SHSH file to set your devices generator."];
                apnonceError.window.titlebarAppearsTransparent = true;
                [apnonceError runModal];

                self->_generatorEntry.stringValue = @"";
                return;
            }
        } else if ([self->_generatorEntry.stringValue length] != 18 ||
                   ![self->_generatorEntry.stringValue containsString:@"0x"]) {
            NSAlert *apnonceError = [[NSAlert alloc] init];
            [apnonceError setMessageText:@"Error: Invalid Generator, please try again..."];
            apnonceError.window.titlebarAppearsTransparent = true;
            [apnonceError runModal];

            self->_generatorEntry.stringValue = @"";
            return;
        } else {
            generatorString = self->_generatorEntry.stringValue;
        }
    }
    [self->_generatorEntry setEnabled:FALSE];
    [self->_generatorEntry setHidden:TRUE];
    [self->_setNonceButton setEnabled:FALSE];
    [self->_setNonceButton setHidden:TRUE];

    [self->_prog setHidden:FALSE];
    [self->_label setStringValue:@"Checking if device is in PWNDFU mode..."];
    [self->_label setHidden:FALSE];

    if (!([[NSString stringWithFormat:@"%@", [apnonceDevice getSerial_string]] containsString:@"checkm8"] ||
          [[NSString stringWithFormat:@"%@", [apnonceDevice getSerial_string]] containsString:@"eclipsa"])) {
        [self->_label setStringValue:@"Device is not in PWNDFU mode..."];
        while (TRUE) {
            NSAlert *pwnNotice = [[NSAlert alloc] init];
            [pwnNotice setMessageText:[NSString stringWithFormat:@"Your %@ is not in PWNDFU mode. "
                                                                 @"Please enter it now.",
                                                                 [apnonceDevice getModel]]];
            [pwnNotice addButtonWithTitle:@"Run checkm8"];
            pwnNotice.window.titlebarAppearsTransparent = true;
            NSModalResponse choice = [pwnNotice runModal];
            if (choice == NSAlertFirstButtonReturn) {

                if ([apnonceDevice runCheckm8] == 0) {
                    [apnonceDevice setIRECVDeviceInfo:[apnonceDevice getIRECVClient]];
                    break;
                }
            }
        }
    }
    [self->_label setStringValue:@"Device is in PWNDFU mode..."];

    [self loadIPSW];
}

- (void)loadIPSW {
    [self->_label setStringValue:@"Waiting for user to pick IPSW..."];

    NSOpenPanel *openDlg = [NSOpenPanel openPanel];
    openDlg.message = @"Please pick an IPSW...";
    openDlg.canChooseFiles = TRUE;
    openDlg.canChooseDirectories = FALSE;
    openDlg.allowsMultipleSelection = FALSE;
    openDlg.allowedFileTypes = [NSArray arrayWithObject:@"ipsw"];
    openDlg.canCreateDirectories = FALSE;

    if ([openDlg runModal] == NSModalResponseOK) {

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_prog incrementBy:16.66];
                [self->_label setStringValue:@"Unzipping IPSW..."];
                [apnonceIPSW setIpswPath:openDlg.URL.path];
            });

            while ([apnonceIPSW getIpswPath] == NULL) {
            }

            apnonceextractPath =
                [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
            apnonceextractPath = [NSString stringWithFormat:@"%@/RamielIPSW", [[NSBundle mainBundle] resourcePath]];
            if ([RamielView debugCheck])
                NSLog(@"Unzipping IPSW From Path: %@\nto path: %@", [apnonceIPSW getIpswPath], apnonceextractPath);
            if ([[[NSFileManager defaultManager] attributesOfItemAtPath:[apnonceIPSW getIpswPath] error:nil] fileSize] <
                1677721600.00) { // If the IPSW is less then 1.5GB then its likely incomplete
                dispatch_async(dispatch_get_main_queue(), ^{
                    [RamielView errorHandler:
                        @"Downloaded IPSW is corrupt":
                            @"Please re-download the IPSW and try again, either from ipsw.me or using Ramiel's IPSW "
                             @"downloader.":
                                 [NSString stringWithFormat:
                                               @"IPSW's size in bytes is %llu which is to small for an actual IPSW",
                                               [[[NSFileManager defaultManager]
                                                   attributesOfItemAtPath:[apnonceIPSW getIpswPath]
                                                                    error:nil] fileSize]]];
                    [[NSFileManager defaultManager] removeItemAtPath:[apnonceIPSW getIpswPath] error:nil];
                    return;
                });
            }
            if ([[NSFileManager defaultManager] fileExistsAtPath:[apnonceextractPath pathExtension]
                                                     isDirectory:(BOOL * _Nullable) TRUE]) {

                [[NSFileManager defaultManager] removeItemAtPath:apnonceextractPath error:nil];
            }

            [[NSFileManager defaultManager] createDirectoryAtPath:apnonceextractPath
                                      withIntermediateDirectories:TRUE
                                                       attributes:NULL
                                                            error:nil];

            //[SSZipArchive unzipFileAtPath:[apnonceIPSW getIpswPath] toDestination:apnonceextractPath];
            NSError *er = nil;
            [SSZipArchive unzipFileAtPath:[apnonceIPSW getIpswPath]
                            toDestination:apnonceextractPath
                                overwrite:YES
                                 password:nil
                                    error:&er];
            if (er) {
                NSLog(@"sadge: %@", er);
            }

            apnoncecheckNum = 1;
        });

    } else {
        //[self->_prog setHidden:TRUE];
        [self.view.window.contentViewController dismissViewController:self];
        return;
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        while (apnoncecheckNum == 0) {
            NSLog(@"unzipping...");
            sleep(2);
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_prog incrementBy:8.33];
            [self->_label setStringValue:@"Parsing BuildManifest..."];
        });

        if ([[NSFileManager defaultManager]
                fileExistsAtPath:[NSString stringWithFormat:@"%@/BuildManifest.plist", apnonceextractPath]]) {

            NSDictionary *manifestData = [NSDictionary
                dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/BuildManifest.plist", apnonceextractPath]];
            [apnonceIPSW setIosVersion:[manifestData objectForKey:@"ProductVersion"]]; // Get IPSW's iOS version
            if ([[apnonceIPSW getIosVersion] containsString:@"9."] ||
                [[apnonceIPSW getIosVersion] containsString:@"8."] ||
                [[apnonceIPSW getIosVersion] containsString:@"7."]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSAlert *versionWarning = [[NSAlert alloc] init];
                    [versionWarning
                        setMessageText:
                            [NSString stringWithFormat:@"Warning: %@ is not offically supported at this time, however "
                                                       @"Ramiel will still attempt to properly boot your device.",
                                                       [apnonceIPSW getIosVersion]]];
                    [versionWarning
                        setInformativeText:
                            @"Your device may fail to boot, if this occurs then please open an issue on GitHub."];
                    versionWarning.window.titlebarAppearsTransparent = TRUE;
                    [versionWarning runModal];
                });
            }

            [apnonceIPSW
                setSupportedModels:[manifestData objectForKey:@"SupportedProductTypes"]]; // Get supported devices list
            int supported = 0;
            for (int i = 0; i < [[apnonceIPSW getSupportedModels] count]; i++) {
                if ([[[apnonceIPSW getSupportedModels] objectAtIndex:i] containsString:[apnonceDevice getModel]]) {
                    supported = 1;
                }
            }
            if (supported == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [RamielView errorHandler:
                        @"IPSW is not valid for this device":
                            @"Please pick another IPSW or download one that is valid for your device":@"N/A"];
                    [self.view.window.contentViewController dismissViewController:self];
                });
                return;
            }

            NSArray *buildID = [manifestData objectForKey:@"BuildIdentities"];

            if ([buildID[0][@"Info"][@"VariantContents"][@"VinylFirmware"] isEqual:@"Release"]) {
                [apnonceIPSW setReleaseBuild:YES];
            } else {
                [apnonceIPSW setReleaseBuild:NO];
            }

            for (int i = 0; i < [buildID count]; i++) {

                if ([buildID[i][@"ApChipID"] isEqual:[apnonceDevice getCpid]]) {

                    if ([buildID[i][@"Info"][@"DeviceClass"] isEqual:[apnonceDevice getHardware_model]]) {

                        [apnonceIPSW setIbssName:buildID[i][@"Manifest"][@"iBSS"][@"Info"][@"Path"]];
                        [apnonceIPSW setIbecName:buildID[i][@"Manifest"][@"iBEC"][@"Info"][@"Path"]];
                        break;
                    }
                }
            }

            if ([apnonceIPSW getIbssName] != NULL) {

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_prog incrementBy:16.66];
                    [self->_label setStringValue:@"Moving Files..."];
                });

                NSString *documentsFolder = [[NSBundle mainBundle] resourcePath];

                [[NSFileManager defaultManager]
                    removeItemAtPath:[NSString stringWithFormat:@"%@/RamielFiles", documentsFolder]
                               error:nil];

                [[NSFileManager defaultManager]
                          createDirectoryAtPath:[NSString stringWithFormat:@"%@/RamielFiles", documentsFolder]
                    withIntermediateDirectories:YES
                                     attributes:nil
                                          error:nil];

                [[NSFileManager defaultManager]
                    moveItemAtPath:[NSString stringWithFormat:@"%@/%@", apnonceextractPath, [apnonceIPSW getIbssName]]
                            toPath:[NSString stringWithFormat:@"%@/RamielFiles/ibss.im4p", documentsFolder]
                             error:nil];
                [[NSFileManager defaultManager]
                    moveItemAtPath:[NSString stringWithFormat:@"%@/%@", apnonceextractPath, [apnonceIPSW getIbecName]]
                            toPath:[NSString stringWithFormat:@"%@/RamielFiles/ibec.im4p", documentsFolder]
                             error:nil];

                [[NSFileManager defaultManager] removeItemAtPath:apnonceextractPath error:nil];

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_prog incrementBy:16.66];
                    [self->_label setStringValue:@"Grabbing Firmware Keys..."];
                });

                NSURL *wikiURL =
                    [NSURL URLWithString:[NSString stringWithFormat:@"https://www.theiphonewiki.com/wiki/%@_%@_(%@)",
                                                                    buildID[0][@"Info"][@"BuildTrain"],
                                                                    [manifestData objectForKey:@"ProductBuildVersion"],
                                                                    [apnonceDevice getModel]]];
                NSURLRequest *request = [NSURLRequest requestWithURL:wikiURL];
                NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
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
                            [self.view.window.contentViewController dismissViewController:self];
                        });
                        return;
                    }
                    if ([dataString containsString:@"/>&#160;("]) {

                        NSArray *model1 = [dataString componentsSeparatedByString:@"/>&#160;("];

                        model1 = [model1[1] componentsSeparatedByString:@")&"];

                        if ([[model1[0] uppercaseString]
                                isEqual:[[apnonceDevice getHardware_model] uppercaseString]]) { // Make sure we get the
                                                                                                // right keys

                            NSArray *ibecIVSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-ibec-iv\">"];
                            NSArray *ibecIVSplit2 = [ibecIVSplit1[1] componentsSeparatedByString:@"</code></li>"];

                            [apnonceIPSW setIbecIV:ibecIVSplit2[0]];

                            NSArray *ibssIVSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-ibss-iv\">"];
                            NSArray *ibssIVSplit2 = [ibssIVSplit1[1] componentsSeparatedByString:@"</code></li>"];

                            [apnonceIPSW setIbssIV:ibssIVSplit2[0]];

                            NSArray *ibecKEYSplit1 =
                                [dataString componentsSeparatedByString:@"id=\"keypage-ibec-key\">"];
                            NSArray *ibecKEYSplit2 = [ibecKEYSplit1[1] componentsSeparatedByString:@"</code></li>"];

                            [apnonceIPSW setIbecKEY:ibecKEYSplit2[0]];

                            NSArray *ibssKEYSplit1 =
                                [dataString componentsSeparatedByString:@"id=\"keypage-ibss-key\">"];
                            NSArray *ibssKEYSplit2 = [ibssKEYSplit1[1] componentsSeparatedByString:@"</code></li>"];

                            [apnonceIPSW setIbssKEY:ibssKEYSplit2[0]];

                        } else {

                            NSArray *ibecIVSplit1 =
                                [dataString componentsSeparatedByString:@"id=\"keypage-ibec2-iv\">"];
                            NSArray *ibecIVSplit2 = [ibecIVSplit1[1] componentsSeparatedByString:@"</code></li>"];

                            [apnonceIPSW setIbecIV:ibecIVSplit2[0]];

                            NSArray *ibssIVSplit1 =
                                [dataString componentsSeparatedByString:@"id=\"keypage-ibss2-iv\">"];
                            NSArray *ibssIVSplit2 = [ibssIVSplit1[1] componentsSeparatedByString:@"</code></li>"];

                            [apnonceIPSW setIbssIV:ibssIVSplit2[0]];

                            NSArray *ibecKEYSplit1 =
                                [dataString componentsSeparatedByString:@"id=\"keypage-ibec2-key\">"];
                            NSArray *ibecKEYSplit2 = [ibecKEYSplit1[1] componentsSeparatedByString:@"</code></li>"];

                            [apnonceIPSW setIbecKEY:ibecKEYSplit2[0]];

                            NSArray *ibssKEYSplit1 =
                                [dataString componentsSeparatedByString:@"id=\"keypage-ibss2-key\">"];
                            NSArray *ibssKEYSplit2 = [ibssKEYSplit1[1] componentsSeparatedByString:@"</code></li>"];

                            [apnonceIPSW setIbssKEY:ibssKEYSplit2[0]];
                        }

                    } else {

                        NSArray *ibecIVSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-ibec-iv\">"];
                        NSArray *ibecIVSplit2 = [ibecIVSplit1[1] componentsSeparatedByString:@"</code></li>"];

                        [apnonceIPSW setIbecIV:ibecIVSplit2[0]];

                        NSArray *ibssIVSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-ibss-iv\">"];
                        NSArray *ibssIVSplit2 = [ibssIVSplit1[1] componentsSeparatedByString:@"</code></li>"];

                        [apnonceIPSW setIbssIV:ibssIVSplit2[0]];

                        NSArray *ibecKEYSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-ibec-key\">"];
                        NSArray *ibecKEYSplit2 = [ibecKEYSplit1[1] componentsSeparatedByString:@"</code></li>"];

                        [apnonceIPSW setIbecKEY:ibecKEYSplit2[0]];

                        NSArray *ibssKEYSplit1 = [dataString componentsSeparatedByString:@"id=\"keypage-ibss-key\">"];
                        NSArray *ibssKEYSplit2 = [ibssKEYSplit1[1] componentsSeparatedByString:@"</code></li>"];

                        [apnonceIPSW setIbssKEY:ibssKEYSplit2[0]];
                    }

                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self->_prog incrementBy:16.66];
                        [self->_label setStringValue:@"Patching iBSS/iBEC..."];
                    });
                    if (!([apnonceIPSW getIbssKEY].length == 64 && [apnonceIPSW getIbecKEY].length == 64 &&
                          [apnonceIPSW getIbssIV].length == 32 &&
                          [apnonceIPSW getIbecIV].length == 32)) { // Ensure that the keys we got are the right length

                        dispatch_async(dispatch_get_main_queue(), ^{
                            [RamielView errorHandler:
                                @"Received malformed keys":
                                    [NSString stringWithFormat:
                                                  @"Expected string lengths of 64 & 32 but got %lu, %lu & %lu, %lu",
                                                  (unsigned long)[apnonceIPSW getIbssKEY].length,
                                                  (unsigned long)[apnonceIPSW getIbssIV].length,
                                                  (unsigned long)[apnonceIPSW getIbecKEY].length,
                                                  (unsigned long)[apnonceIPSW getIbecIV].length
                            ]:[NSString
                                    stringWithFormat:
                                        @"Key Information:\n\niBSS Key: %@\niBSS IVs: %@\niBEC Key: %@\niBEC IVs: %@",
                                        [apnonceIPSW getIbssKEY], [apnonceIPSW getIbssIV], [apnonceIPSW getIbecKEY],
                                        [apnonceIPSW getIbecIV]]];

                            [self.view.window.contentViewController dismissViewController:self];
                            return;
                        });
                    }

                    [RamielView
                        img4toolCMD:[NSString stringWithFormat:@"-e -o %@/RamielFiles/ibss.raw --iv %@ "
                                                               @"--key %@ %@/RamielFiles/ibss.im4p",
                                                               [[NSBundle mainBundle] resourcePath],
                                                               [apnonceIPSW getIbssIV], [apnonceIPSW getIbssKEY],
                                                               [[NSBundle mainBundle] resourcePath]]];

                    [RamielView
                        img4toolCMD:[NSString stringWithFormat:@"-e -o %@/RamielFiles/ibec.raw --iv %@ "
                                                               @"--key %@ %@/RamielFiles/ibec.im4p",
                                                               [[NSBundle mainBundle] resourcePath],
                                                               [apnonceIPSW getIbecIV], [apnonceIPSW getIbecKEY],
                                                               [[NSBundle mainBundle] resourcePath]]];

                    const char *ibssPath = [[NSString
                        stringWithFormat:@"%@/RamielFiles/ibss.raw", [[NSBundle mainBundle] resourcePath]] UTF8String];
                    const char *ibssPwnPath = [[NSString
                        stringWithFormat:@"%@/RamielFiles/ibss.pwn", [[NSBundle mainBundle] resourcePath]] UTF8String];
                    const char *args = [@"-v" UTF8String];

                    int ret;
                    sleep(1);
                    ret = patchIBXX((char *)ibssPath, (char *)ibssPwnPath, (char *)args);

                    if (ret != 0) {
                        dispatch_queue_t mainQueue = dispatch_get_main_queue();
                        dispatch_sync(mainQueue, ^{
                            [RamielView errorHandler:
                                @"Failed to patch iBSS":[NSString stringWithFormat:@"Kairos returned with: %i", ret
                            ]:@"N/A"];
                            [self->_prog setHidden:TRUE];
                            [self.view.window.contentViewController dismissViewController:self];
                            return;
                        });
                    } else {
                        const char *ibecPath =
                            [[NSString stringWithFormat:@"%@/RamielFiles/ibec.raw",
                                                        [[NSBundle mainBundle] resourcePath]] UTF8String];
                        const char *ibecPwnPath =
                            [[NSString stringWithFormat:@"%@/RamielFiles/ibec.pwn",
                                                        [[NSBundle mainBundle] resourcePath]] UTF8String];
                        ret = patchIBXX((char *)ibecPath, (char *)ibecPwnPath, (char *)args);

                        if (ret != 0) {
                            dispatch_queue_t mainQueue = dispatch_get_main_queue();
                            dispatch_sync(mainQueue, ^{
                                [RamielView errorHandler:
                                    @"Failed to patch iBEC":[NSString stringWithFormat:@"Kairos returned with: %i", ret
                                ]:@"N/A"];
                                [self->_prog setHidden:TRUE];
                                [self.view.window.contentViewController dismissViewController:self];
                                return;
                            });
                        }
                    }

                    [RamielView img4toolCMD:[NSString stringWithFormat:@"-c %@/RamielFiles/ibss.%@.patched -t ibss "
                                                                       @"%@/RamielFiles/ibss.pwn",
                                                                       [[NSBundle mainBundle] resourcePath],
                                                                       [apnonceDevice getModel],
                                                                       [[NSBundle mainBundle] resourcePath]]];

                    [RamielView img4toolCMD:[NSString stringWithFormat:@"-c %@/RamielFiles/ibec.%@.patched -t ibec "
                                                                       @"%@/RamielFiles/ibec.pwn",
                                                                       [[NSBundle mainBundle] resourcePath],
                                                                       [apnonceDevice getModel],
                                                                       [[NSBundle mainBundle] resourcePath]]];
                    NSString *apnonceshshPath;
                    NSMutableDictionary *ramielPrefs = [NSMutableDictionary
                        dictionaryWithDictionary:[NSDictionary
                                                     dictionaryWithContentsOfFile:
                                                         [NSString
                                                             stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                              [[NSBundle mainBundle] resourcePath]]]];
                    if (![[ramielPrefs objectForKey:@"customSHSHPath"] containsString:@"N/A"]) {
                        if ([RamielView debugCheck])
                            NSLog(@"Using user-provided SHSH from: %@", [ramielPrefs objectForKey:@"customSHSHPath"]);
                        apnonceshshPath = [ramielPrefs objectForKey:@"customSHSHPath"];
                    } else if ([[NSFileManager defaultManager]
                                   fileExistsAtPath:[NSString stringWithFormat:@"%@/shsh/%@.shsh",
                                                                               [[NSBundle mainBundle] resourcePath],
                                                                               [apnonceDevice getCpid]]]) {
                        apnonceshshPath =
                            [NSString stringWithFormat:@"%@/shsh/%@.shsh", [[NSBundle mainBundle] resourcePath],
                                                       [apnonceDevice getCpid]];
                    } else {
                        apnonceshshPath =
                            [NSString stringWithFormat:@"%@/shsh/shsh.shsh", [[NSBundle mainBundle] resourcePath]];
                    }

                    [RamielView
                        img4toolCMD:[NSString
                                        stringWithFormat:@"-c %@/ibss.img4 -p %@/RamielFiles/ibss.%@.patched -s %@",
                                                         [[NSBundle mainBundle] resourcePath],
                                                         [[NSBundle mainBundle] resourcePath], [apnonceDevice getModel],
                                                         apnonceshshPath]];

                    [RamielView
                        img4toolCMD:[NSString
                                        stringWithFormat:@"-c %@/ibec.img4 -p %@/RamielFiles/ibec.%@.patched -s %@",
                                                         [[NSBundle mainBundle] resourcePath],
                                                         [[NSBundle mainBundle] resourcePath], [apnonceDevice getModel],
                                                         apnonceshshPath]];

                    // Boot SSH Ramdisk
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self bootDevice];
                    });
                    return;

                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [RamielView errorHandler:
                            @"Failed to get firmware keys":@"Please check detailed log for more information"
                                                          :[NSString stringWithFormat:@"%@", data]];
                        [self.view.window.contentViewController dismissViewController:self];
                    });
                    return;
                }
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [RamielView errorHandler:
                        @"IPSW is not valid for connected device":@"Please provide Ramiel with the correct IPSW"
                                                                 :@"N/A"];
                });
                [self.view.window.contentViewController dismissViewController:self];
            }
        }
    });
}

- (void)bootDevice {

    [self->_prog incrementBy:-100.00];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_label setStringValue:@"Booting Device..."];
    });

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        irecv_error_t ret = 0;

        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_prog incrementBy:33.3];
            [self->_label setStringValue:@"Sending iBSS..."];
        });
        NSString *err = @"send iBSS";
        NSString *ibss = [NSString stringWithFormat:@"%@/ibss.img4", [[NSBundle mainBundle] resourcePath]];
        ret = [apnonceDevice sendImage:ibss];
        if (ret == IRECV_E_NO_DEVICE) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [RamielView errorHandler:
                    @"Failed to send iBSS to device":@"Ramiel wasn't able to reconnect to the device after sending iBSS"
                                                    :@"libirecovery returned: IRECV_E_NO_DEVICE"];
            });
            return;
        }
        if ([[apnonceDevice getCpid] containsString:@"8015"] || [[apnonceDevice getCpid] containsString:@"8960"] ||
            [[apnonceDevice getCpid] containsString:@"8965"] ||
            ([[apnonceDevice getCpid] containsString:@"8010"] &&
             ([[apnonceDevice getModel] containsString:@"iPad"] ||
              [[apnonceDevice getModel]
                  containsString:@"9,2"]) /*Seems that only A10 iPads need this to happen, not A10 iPhone/iPods*/)) {
            irecv_reset([apnonceDevice getIRECVClient]);
            [apnonceDevice closeDeviceConnection];
            [apnonceDevice setClient:NULL];
            usleep(1000);
            irecv_client_t temp = NULL;
            irecv_open_with_ecid_and_attempts(&temp, (uint64_t)[apnonceDevice getEcid], 5);
            [apnonceDevice setIRECVClient:temp];

            ret = [apnonceDevice sendImage:ibss];
            if (ret == IRECV_E_NO_DEVICE) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [RamielView errorHandler:
                        @"Failed to send iBSS to device for the second time":
                            @"Ramiel wasn't able to reconnect to the device after sending iBSS for the second time":
                                @"libirecovery returned: IRECV_E_NO_DEVICE"];
                    [self.view.window.contentViewController dismissViewController:self];
                });
                return;
            }
        }
        if (ret == 1) { // Some tools require a *dummy* file to be sent before we
                        // can boot ibss, this deals with that
            if ([RamielView debugCheck])
                printf("Failed to send iBSS once, reclaiming usb and trying again\n");
            irecv_reset([apnonceDevice getIRECVClient]);
            [apnonceDevice closeDeviceConnection];
            [apnonceDevice setClient:NULL];
            usleep(1000);
            irecv_client_t temp = NULL;
            irecv_open_with_ecid_and_attempts(&temp, (uint64_t)[apnonceDevice getEcid], 5);
            [apnonceDevice setIRECVClient:temp];

            ret = [apnonceDevice sendImage:ibss];
            if (ret == IRECV_E_NO_DEVICE) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [RamielView errorHandler:
                        @"Failed to send iBSS to device for the second time":
                            @"Ramiel wasn't able to reconnect to the device after sending iBSS for the second time":
                                @"libirecovery returned: IRECV_E_NO_DEVICE"];
                    [self.view.window.contentViewController dismissViewController:self];
                    return;
                });
            }

            if (ret == 1) {

                if ([RamielView debugCheck])
                    printf("Failed to send iBSS twice, sending once more then erroring if it fails again\n");
                ret = [apnonceDevice sendImage:ibss];
                if (ret == IRECV_E_NO_DEVICE) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [RamielView errorHandler:
                            @"Failed to send iBSS to device for the third time":
                                @"Ramiel wasn't able to reconnect to the device after sending iBSS for the third time":
                                    @"libirecovery returned: IRECV_E_NO_DEVICE"];
                        return;
                    });
                    return;
                }
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_prog incrementBy:33.3];
            [self->_label setStringValue:@"Sending iBEC..."];
        });
        err = @"send iBEC";
        NSString *ibec = [NSString stringWithFormat:@"%@/ibec.img4", [[NSBundle mainBundle] resourcePath]];
        ret = [apnonceDevice sendImage:ibec];
        sleep(3);
        if ([[apnonceDevice getCpid] containsString:@"8015"]) {
            sleep(2);
        }
        if ([[apnonceDevice getCpid] isEqualToString:@"0x8010"] ||
            [[apnonceDevice getCpid] isEqualToString:@"0x8011"] ||
            [[apnonceDevice getCpid] isEqualToString:@"0x8015"]) {
            ret = [apnonceDevice sendImage:ibec];
            sleep(1);
            err = @"send go command";
            NSString *boot = @"go";
            ret = [apnonceDevice sendCMD:boot];
            sleep(1);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_prog incrementBy:33.4];
            [self->_label setStringValue:@"Setting generator and rebooting device..."];
        });
        // Send recovery commands now
        ret = [apnonceDevice
            sendCMD:[NSString stringWithFormat:@"setenv com.apple.System-boot.nonce %@", generatorString]];
        ret = [apnonceDevice sendCMD:@"saveenv"];
        ret = [apnonceDevice sendCMD:@"setenv auto-boot false"];
        ret = [apnonceDevice sendCMD:@"saveenv"];
        ret = [apnonceDevice sendCMD:@"reset"];

        if (ret == IRECV_E_SUCCESS) {

            sleep(6);

            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *success = [[NSAlert alloc] init];
                [success setInformativeText:@"Ramiel will now exit."];
                [success setMessageText:[NSString
                                            stringWithFormat:@"Successfully set your generator to\n\"%@\"\nYou can now "
                                                             @"futurerestore using your SHSH with that same generator.",
                                                             generatorString]];
                [success addButtonWithTitle:@"Exit"];
                success.window.titlebarAppearsTransparent = true;
                [success runModal];
                exit(0);
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *fail = [[NSAlert alloc] init];
                [fail setMessageText:[NSString stringWithFormat:@"Failed to set devices generator. Device returned: %d",
                                                                ret]];
                fail.window.titlebarAppearsTransparent = true;
                [fail runModal];
                [self backButton:nil];
            });
        }
        return;
    });
}

- (IBAction)backButton:(NSButton *)sender {
    [apnonceDevice teardown];
    [apnonceIPSW teardown];
    [self.view.window.contentViewController dismissViewController:self];
}

@end
