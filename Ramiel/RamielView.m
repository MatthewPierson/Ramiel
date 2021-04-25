//
//  RamielView.m
//  Ramiel
//
//  Created by Matthew Pierson on 9/08/20.
//  Copyright © 2020 moski. All rights reserved.
//

#import "RamielView.h"
#import "../Pods/AFNetworking/AFNetworking/AFNetworking.h"
#import "../Pods/SSZipArchive/SSZipArchive/SSZipArchive.h"
#import "Device.h"
#import "FileMDHash.h"
#import "FirmwareKeys.h"
#import "IPSW.h"
#include "kairos.h"
#include "libirecovery.h"
#include "libusb-1.0/libusb.h"
#include "partial.h"
#import <CommonCrypto/CommonDigest.h>
#import <Network/Network.h>

@implementation RamielView

irecv_client_t compareClient = NULL;
irecv_error_t error = 0;
NSString *extractPath;
NSString *shshPath;
int checkNum;
int stopBackground = 0;
int exploitCheck = 0;
int irecDL = 0;
int con = 0;

Device *userDevice;
IPSW *userIPSW;
FirmwareKeys *userKeys;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Ensure we are running from /Applications, as running Ramiel from somewhere else can cause issues
    if ([[[NSBundle mainBundle] resourcePath] containsString:@"/Applications/"] &&
        ![[[NSBundle mainBundle] resourcePath] containsString:@"build/Ramiel/Build"]) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Error: Ramiel is not running from the \"Applications\" folder."];
        [alert setInformativeText:@"Please move \"Ramiel.app\" into \"/Applcations\" then run Ramiel again."];
        [alert addButtonWithTitle:@"Exit"];
        alert.window.titlebarAppearsTransparent = TRUE;
        [alert runModal];
        exit(0);
    }
    // Check if an update is available
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSData *updateData = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"https://ramiel.app/latest"]];
    if (updateData) {
        NSString *latestVersion = [[[NSString alloc] initWithData:updateData encoding:NSASCIIStringEncoding]
            componentsSeparatedByString:@"\n"][0];
        NSString *updateURL = [[[NSString alloc] initWithData:updateData encoding:NSASCIIStringEncoding]
            componentsSeparatedByString:@"\n"][1];
        if ([latestVersion compare:version options:NSNumericSearch] == NSOrderedDescending) {
            NSAlert *updateAvailable = [[NSAlert alloc] init];
            [updateAvailable
                setMessageText:[NSString stringWithFormat:@"Update to version %@ is available!", latestVersion]];
            [updateAvailable
                setInformativeText:
                    [NSString
                        stringWithFormat:
                            @"An update is not required but is highly encouraged to ensure that Ramiel has the latest "
                            @"bug-fixes and feature updates that it can get.\nYou are currently running version %@",
                            version]];
            updateAvailable.window.titlebarAppearsTransparent = TRUE;
            [updateAvailable addButtonWithTitle:@"Exit and Download Update"];
            [updateAvailable addButtonWithTitle:@"Ignore"];
            NSModalResponse choice = [updateAvailable runModal];
            if (choice == NSAlertFirstButtonReturn) {
                [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:updateURL]];
                exit(0);
            }
            // If user chooses to ignore the update we just continue to Ramiel and prompt again on next launch
        }
    }

    [self installBinaries];

    [self->_bootProgBar setHidden:TRUE];
    [self->_infoLabel setStringValue:@"Connect a device in DFU mode..."];
    [self->_modelLabel setStringValue:@""];

    [[NSFileManager defaultManager]
        removeItemAtPath:[NSString stringWithFormat:@"%@/RamielFiles/", [[NSBundle mainBundle] resourcePath]]
                   error:nil];

    [self deviceStuff];
    userIPSW = [[IPSW alloc] initIPSWID];
    userKeys = [[FirmwareKeys alloc] initFirmwareKeysID];
    if ([userIPSW getBootargs] == nil) {
        [userIPSW setBootargs:@"-v"];
    }

    NSMutableDictionary *ramielPrefs = [NSMutableDictionary
        dictionaryWithDictionary:[NSDictionary dictionaryWithContentsOfFile:
                                                   [NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                              [[NSBundle mainBundle] resourcePath]]]];
    if (![ramielPrefs objectForKey:@"customLogo"]) {
        [ramielPrefs setObject:@(0) forKey:@"customLogo"];
        [[NSFileManager defaultManager]
            removeItemAtPath:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                        [[NSBundle mainBundle] resourcePath]]
                       error:nil];
        [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                            [[NSBundle mainBundle] resourcePath]]
                      atomically:TRUE];
    }

    if (![ramielPrefs objectForKey:@"skipVerification"]) {
        [ramielPrefs setObject:@(0) forKey:@"skipVerification"];
        [[NSFileManager defaultManager]
            removeItemAtPath:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                        [[NSBundle mainBundle] resourcePath]]
                       error:nil];
        [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                            [[NSBundle mainBundle] resourcePath]]
                      atomically:TRUE];
    }

    if (![ramielPrefs objectForKey:@"dualbootDiskNum"]) {
        [ramielPrefs setObject:@(0) forKey:@"dualbootDiskNum"];
        [[NSFileManager defaultManager]
            removeItemAtPath:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                        [[NSBundle mainBundle] resourcePath]]
                       error:nil];
        [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                            [[NSBundle mainBundle] resourcePath]]
                      atomically:TRUE];
    }
    if (![ramielPrefs objectForKey:@"bootpartitionPatch"]) {
        [ramielPrefs setObject:@(0) forKey:@"bootpartitionPatch"];
        [[NSFileManager defaultManager]
            removeItemAtPath:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                        [[NSBundle mainBundle] resourcePath]]
                       error:nil];
        [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                            [[NSBundle mainBundle] resourcePath]]
                      atomically:TRUE];
    }

    // Reset custom boot args everytime we launch, just incase someone doesn't
    // want to save custom args, might add option to save it idk

    [ramielPrefs setObject:@"-v" forKey:@"customBootArgs"];
    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                                [[NSBundle mainBundle] resourcePath]]
                                               error:nil];
    [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                        [[NSBundle mainBundle] resourcePath]]
                  atomically:TRUE];

    [ramielPrefs setObject:@"N/A" forKey:@"customSHSHPath"];
    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                                [[NSBundle mainBundle] resourcePath]]
                                               error:nil];
    [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                        [[NSBundle mainBundle] resourcePath]]
                  atomically:TRUE];

    [ramielPrefs setObject:@(0) forKey:@"debug"];
    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                                [[NSBundle mainBundle] resourcePath]]
                                               error:nil];
    [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                        [[NSBundle mainBundle] resourcePath]]
                  atomically:TRUE];

    [ramielPrefs setObject:@(0) forKey:@"amfi"];
    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                                [[NSBundle mainBundle] resourcePath]]
                                               error:nil];
    [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                        [[NSBundle mainBundle] resourcePath]]
                  atomically:TRUE];
    [ramielPrefs setObject:@(0) forKey:@"amsd"];
    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                                [[NSBundle mainBundle] resourcePath]]
                                               error:nil];
    [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                        [[NSBundle mainBundle] resourcePath]]
                  atomically:TRUE];

    [self.view.window deminiaturize:nil];

    int rand = arc4random_uniform(100);
    int rand2 = arc4random_uniform(100);
    NSLog(@"%d", rand);
    NSLog(@"%d", rand2);
    if (rand == rand2) { // this only showed 2 times during development so gl on getting it :)
        [self->_secretLabel setHidden:FALSE];
        self->_secretLabel.textColor = [NSColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.5];
        [self->_secretLabel
            setStringValue:@"There's a 1 in 10000 chance of this message showing up. Congrats I guess?"];
    }
}

- (void)viewDidAppear {
    [super viewDidAppear];
    [self.view.window deminiaturize:nil];
}

- (void)installBinaries {

    NSFileManager *fm = [NSFileManager defaultManager];
    if (!([fm fileExistsAtPath:@"/usr/local/bin/iproxy"] &&
          [fm fileExistsAtPath:[NSString stringWithFormat:@"%@/Exploits/ipwndfu/ipwndfu",
                                                          [[NSBundle mainBundle] resourcePath]]] &&
          [fm fileExistsAtPath:[NSString
                                   stringWithFormat:@"%@/Exploits/Fugu/Fugu", [[NSBundle mainBundle] resourcePath]]] &&
          [fm fileExistsAtPath:@"/usr/local/bin/img4"] && [fm fileExistsAtPath:@"/usr/local/bin/img4tool"])) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSStoryboard *storyboard = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
            NSViewController *yourViewController = [storyboard instantiateControllerWithIdentifier:@"aa"];
            [self.view.window.contentViewController presentViewControllerAsSheet:yourViewController];
        });
        return;
    }
}

- (void)deviceStuff {

    [self.view.window setLevel:0];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        userDevice = NULL;

        userDevice = [[Device alloc] initDeviceID];

        if (userDevice != NULL) {

            dispatch_async(dispatch_get_main_queue(), ^{
                int ret, mode;
                ret = irecv_get_mode([userDevice getIRECVClient], &mode);
                if (ret == IRECV_E_SUCCESS) {
                    if (mode == IRECV_K_DFU_MODE) {

                        [userDevice
                            setCpid:[NSString stringWithFormat:@"0x%04x", [userDevice getIRECVDeviceInfo].cpid]];
                        NSArray *supportedDevices =
                            [NSArray arrayWithObjects:@"0x8960", @"0x8965", @"0x7000", @"0x7001", @"0x8000", @"0x8001",
                                                      @"0x8003", @"0x8010", @"0x8011", @"0x8015", nil];
                        stopBackground = 0;
                        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                            [self backgroundChecker];
                        });

                        if ([supportedDevices containsObject:[userDevice getCpid]]) {
                            if ([RamielView debugCheck])
                                NSLog(@"Device Information:\nModel: %@\nCPID: %@\n", [userDevice getModel],
                                      [userDevice getCpid]);
                            if ([[NSString stringWithFormat:@"%@", [userDevice getSerial_string]]
                                    containsString:@"checkm8"]) {
                                [self->_modelLabel setStringValue:[NSString stringWithFormat:@"%@ (PWND: checkm8)",
                                                                                             [userDevice getModel]]];
                            } else if ([[NSString stringWithFormat:@"%@", [userDevice getSerial_string]]
                                           containsString:@"eclipsa"]) {
                                [self->_modelLabel setStringValue:[NSString stringWithFormat:@"%@ (PWND: eclipsa)",
                                                                                             [userDevice getModel]]];
                            } else {
                                [self->_modelLabel setStringValue:[NSString stringWithFormat:@"%@ (PWND: N/A)",
                                                                                             [userDevice getModel]]];
                            }
                            [self->_infoLabel setStringValue:@""];

                            [self->_bootButton setHidden:FALSE];
                            [self->_bootButton setEnabled:TRUE];
                            [self->_settingsButton setHidden:FALSE];
                            [self->_settingsButton setEnabled:TRUE];
                        } else {
                            if ([RamielView debugCheck])
                                NSLog(@"CONNECTED DEVICE IS UNSUPPORTED!!!\nUnsupported Device Information:\nModel: "
                                      @"%@\nCPID: %@\n",
                                      [userDevice getModel], [userDevice getCpid]);
                            [self->_infoLabel setStringValue:@"Unsupported Device..."];

                            [self->_bootButton setHidden:TRUE];
                            [self->_bootButton setEnabled:FALSE];
                            [self->_settingsButton setHidden:TRUE];
                            [self->_settingsButton setEnabled:FALSE];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                // Inform user that their device isn't supported
                                NSAlert *unsupportedAlert = [[NSAlert alloc] init];
                                [unsupportedAlert addButtonWithTitle:@"OK"];
                                [unsupportedAlert
                                    setInformativeText:@"Please connect a 64-bit checkm8-vulnerable device..."];
                                [unsupportedAlert setMessageText:@"Error: This device is unsupported..."];
                                unsupportedAlert.window.titlebarAppearsTransparent = true;
                                [unsupportedAlert runModal];
                            });
                        }
                    } else {
                        [self->_bootButton setHidden:TRUE];
                        [self->_bootButton setEnabled:FALSE];
                        [self->_settingsButton setHidden:FALSE];
                        [self->_settingsButton setEnabled:TRUE];

                        [self->_infoLabel setStringValue:@"Device in wrong mode, please enter DFU mode..."];
                        [self->_modelLabel setStringValue:@""];

                        [userDevice closeDeviceConnection];

                        [self deviceStuff];
                    }
                }
            });
        }
    });
}

- (IBAction)refreshInfo:(NSButton *)sender {

    [self->_bootButton setHidden:TRUE];
    [self->_bootButton setEnabled:FALSE];
    [self->_settingsButton setHidden:TRUE];
    [self->_settingsButton setEnabled:FALSE];
    [self->_bootProgBar incrementBy:-100.00];
    [self->_bootProgBar setHidden:TRUE];

    [self->_infoLabel setStringValue:@"Connect a device in DFU mode..."];
    [self->_modelLabel setStringValue:@""];

    [userDevice closeDeviceConnection];

    [self deviceStuff];
}

- (void)bootErrorReset:(NSString *)error {

    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_infoLabel setStringValue:[NSString stringWithFormat:@"Failed to %@...", error]];
        NSAlert *alert = [[NSAlert alloc] init];
        alert.window.titlebarAppearsTransparent = true;
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:[NSString stringWithFormat:@"Error: Failed to %@...\n\nPlease reboot and "
                                                         @"re-exploit your device then try again...",
                                                         error]];
        [alert runModal];

        [self->_bootProgBar setHidden:TRUE];

        [self refreshInfo:NULL];
    });
}

- (void)backgroundChecker { // There is almost certainly a better way to check for a device disconnect but
    // this works and seemingly has no performance impact so ¯\_(ツ)_/¯
    while (TRUE) {

        // Thanks to
        // https://stackoverflow.com/questions/14722083/how-to-use-libusb-and-libusb-get-device-descriptor for this
        // section Plus my edits of course, to make it do what I want
        if (stopBackground == 0) {
            // NSLog(@"BG Running\n");
            sleep(1);
            libusb_context *context = NULL;
            libusb_device **list = NULL;
            int rc = 0;
            int check = 0;
            ssize_t count = 0;

            rc = libusb_init(&context);
            assert(rc == 0);

            count = libusb_get_device_list(context, &list);
            assert(count > 0);

            for (size_t idx = 0; idx < count; ++idx) {
                libusb_device *device = list[idx];
                struct libusb_device_descriptor desc = {0};

                rc = libusb_get_device_descriptor(device, &desc);
                assert(rc == 0);

                if (desc.idVendor == 0x05AC && desc.idProduct == 0x1227) {
                    check = 1; // This means a DFU device is still connected
                    break;
                }
            }
            libusb_free_device_list(list, (int)count);
            libusb_exit(context);

            if (check != 1) {
                check = 0;
                // Trigger a refreshInfo
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self refreshInfo:NULL];
                });
                break;
            }
        } else {
            sleep(2); // Since its unlikly that stopBackground will change too fast,
                      // we can just wait 2 seconds to stop unneeded code being run
        }
    }
}

+ (NSString *)img4toolCMD:(NSString *)cmd {

    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/bash"];
    [task setArguments:@[@"-c", [NSString stringWithFormat:@"/usr/local/bin/img4tool %@", cmd]]];
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    NSFileHandle *file = [pipe fileHandleForReading];
    [task launch];
    if ([RamielView debugCheck])
        NSLog(@"Running command: %@ %@", [task launchPath], [task arguments]);
    [task waitUntilExit];
    NSData *data = [file readDataToEndOfFile];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+ (NSString *)otherCMD:(NSString *)cmd {

    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/bash"];
    [task setArguments:@[@"-c", [NSString stringWithFormat:@"%@", cmd]]];
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    NSFileHandle *file = [pipe fileHandleForReading];
    [task launch];
    if ([RamielView debugCheck])
        NSLog(@"Running command: %@ %@", [task launchPath], [task arguments]);
    [task waitUntilExit];
    NSData *data = [file readDataToEndOfFile];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (IBAction)startBootProcess:(NSButton *)sender {

    stopBackground = 1;

    [self->_bootButton setHidden:TRUE];
    [self->_bootButton setEnabled:FALSE];
    [self->_settingsButton setHidden:TRUE];
    [self->_settingsButton setEnabled:FALSE];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!([[NSString stringWithFormat:@"%@", [userDevice getSerial_string]] containsString:@"checkm8"] ||
              [[NSString stringWithFormat:@"%@", [userDevice getSerial_string]] containsString:@"eclipsa"])) {

            while (TRUE) {
                NSAlert *pwnNotice = [[NSAlert alloc] init];
                [pwnNotice setMessageText:[NSString stringWithFormat:@"Your %@ is not in PWNDFU mode. "
                                                                     @"Please enter it now.",
                                                                     [userDevice getModel]]];
                [pwnNotice addButtonWithTitle:@"Run checkm8"];
                pwnNotice.window.titlebarAppearsTransparent = true;
                NSModalResponse choice = [pwnNotice runModal];
                if (choice == NSAlertFirstButtonReturn) {

                    if ([userDevice runCheckm8] == 0) {
                        [userDevice setIRECVDeviceInfo:[userDevice getIRECVClient]];
                        if ([[NSString stringWithFormat:@"%@", [userDevice getSerial_string]]
                                containsString:@"checkm8"]) {
                            [self->_modelLabel setStringValue:[NSString stringWithFormat:@"%@ (PWND: checkm8)",
                                                                                         [userDevice getModel]]];
                        } else {
                            [self->_modelLabel setStringValue:[NSString stringWithFormat:@"%@ (PWND: eclipsa)",
                                                                                         [userDevice getModel]]];
                        }
                        break;
                    }
                }
            }
        }
        [self->_dlIPSWButton setEnabled:TRUE];
        [self->_dlIPSWButton setHidden:FALSE];
        [self->_selIPSWButton setEnabled:TRUE];
        [self->_selIPSWButton setHidden:FALSE];
    });
}

- (IBAction)bootDevice:(NSButton *)sender {
    stopBackground = 1;

    [self->_bootButton setEnabled:FALSE];
    [self->_bootButton setHidden:TRUE];
    [self->_settingsButton setEnabled:FALSE];
    [self->_settingsButton setHidden:TRUE];
    [self->_bootProgBar setHidden:FALSE];

    [self->_bootProgBar incrementBy:-100.00];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_infoLabel setStringValue:@"Booting Device..."];
    });

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        irecv_error_t ret = 0;

        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_bootProgBar incrementBy:12.5];
            [self->_infoLabel setStringValue:@"Sending iBSS..."];
        });
        NSString *err = @"send iBSS";
        NSString *ibss = [NSString stringWithFormat:@"%@/ibss.img4", [[NSBundle mainBundle] resourcePath]];
        ret = [userDevice sendImage:ibss];
        if (ret == IRECV_E_NO_DEVICE) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [RamielView errorHandler:
                    @"Failed to send iBSS to device":@"Ramiel wasn't able to reconnect to the device after sending iBSS"
                                                    :@"libirecovery returned: IRECV_E_NO_DEVICE"];
            });
            return;
        }
        if ([[userDevice getCpid] containsString:@"8015"] || [[userDevice getCpid] containsString:@"8960"] ||
            [[userDevice getCpid] containsString:@"8965"] || [[userDevice getCpid] containsString:@"8010"]) {
            irecv_reset([userDevice getIRECVClient]);
            [userDevice closeDeviceConnection];
            [userDevice setClient:NULL];
            usleep(1000);
            irecv_client_t temp = NULL;
            irecv_open_with_ecid_and_attempts(&temp, (uint64_t)[userDevice getEcid], 5);
            [userDevice setIRECVClient:temp];
            ret = [userDevice sendImage:ibss];
            if (ret == IRECV_E_NO_DEVICE) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [RamielView errorHandler:
                        @"Failed to send iBSS to device for the second time":
                            @"Ramiel wasn't able to reconnect to the device after sending iBSS for the second time":
                                @"libirecovery returned: IRECV_E_NO_DEVICE"];
                });
                return;
            }
        }
        if (ret == 1) { // Some tools require a *dummy* file to be sent before we
                        // can boot ibss, this deals with that
            if ([RamielView debugCheck])
                printf("Failed to send iBSS once, reclaiming usb and trying again\n");
            irecv_reset([userDevice getIRECVClient]);
            [userDevice closeDeviceConnection];
            [userDevice setClient:NULL];
            usleep(1000);
            irecv_client_t temp = NULL;
            irecv_open_with_ecid_and_attempts(&temp, (uint64_t)[userDevice getEcid], 5);
            [userDevice setIRECVClient:temp];

            ret = [userDevice sendImage:ibss];
            if (ret == IRECV_E_NO_DEVICE) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [RamielView errorHandler:
                        @"Failed to send iBSS to device for the second time":
                            @"Ramiel wasn't able to reconnect to the device after sending iBSS for the second time":
                                @"libirecovery returned: IRECV_E_NO_DEVICE"];
                });
                return;
            }

            if (ret == 1) {

                if ([RamielView debugCheck])
                    printf("Failed to send iBSS twice, sending once more then erroring if it fails again\n");
                ret = [userDevice sendImage:ibss];
                if (ret == IRECV_E_NO_DEVICE) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [RamielView errorHandler:
                            @"Failed to send iBSS to device for the third time":
                                @"Ramiel wasn't able to reconnect to the device after sending iBSS for the third time":
                                    @"libirecovery returned: IRECV_E_NO_DEVICE"];
                    });
                    return;
                }
            }
        }
        ret = 0;
        while (ret == 0) {

            if ([[userIPSW getIosVersion] containsString:@"9."] || [[userIPSW getIosVersion] containsString:@"8."] ||
                [[userIPSW getIosVersion] containsString:@"7."]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_bootProgBar incrementBy:100];
                    [self->_infoLabel setStringValue:@"Sending iBoot..."];
                });
                err = @"send iBoot";
                NSString *iboot = [NSString stringWithFormat:@"%@/iboot.img4", [[NSBundle mainBundle] resourcePath]];
                ret = [userDevice sendImage:iboot];
            } else {

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_bootProgBar incrementBy:12.5];
                    [self->_infoLabel setStringValue:@"Sending iBEC..."];
                });
                err = @"send iBEC";
                NSString *ibec = [NSString stringWithFormat:@"%@/ibec.img4", [[NSBundle mainBundle] resourcePath]];
                ret = [userDevice sendImage:ibec];
                sleep(3);
                if ([[userDevice getCpid] isEqualToString:@"0x8010"] ||
                    [[userDevice getCpid] isEqualToString:@"0x8011"] ||
                    [[userDevice getCpid] isEqualToString:@"0x8015"]) {
                    ret = [userDevice sendImage:ibec];
                    sleep(1);
                    err = @"send go command";
                    NSString *boot = @"go";
                    ret = [userDevice sendCMD:boot];
                    sleep(1);
                }
                err = @"send first bootx command";
                NSString *boot = @"bootx";
                sleep(5);
                irecv_reset([userDevice getIRECVClient]);
                [userDevice closeDeviceConnection];
                [userDevice setClient:NULL];
                usleep(1000);
                irecv_client_t temp = NULL;
                irecv_open_with_ecid_and_attempts(&temp, (uint64_t)[userDevice getEcid], 5);
                [userDevice setIRECVClient:temp];
                [userDevice sendCMD:boot];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_bootProgBar incrementBy:12.5];
                    [self->_infoLabel setStringValue:@"Sending Bootlogo..."];
                });

                NSString *logo;
                if ([[NSFileManager defaultManager]
                        fileExistsAtPath:[NSString stringWithFormat:@"%@/ramdisk.img4",
                                                                    [[NSBundle mainBundle] resourcePath]]]) {
                    logo = [NSString stringWithFormat:@"%@/sshLogo.img4", [[NSBundle mainBundle] resourcePath]];
                } else {
                    if ([[NSFileManager defaultManager]
                            fileExistsAtPath:[NSString stringWithFormat:@"%@/customLogo.img4",
                                                                        [[NSBundle mainBundle] resourcePath]]]) {
                        logo = [NSString stringWithFormat:@"%@/customLogo.img4", [[NSBundle mainBundle] resourcePath]];
                    } else {
                        logo = [NSString stringWithFormat:@"%@/bootlogo.img4", [[NSBundle mainBundle] resourcePath]];
                    }
                }
                err = @"send BootLogo";
                ret = [userDevice sendImage:logo];

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_bootProgBar incrementBy:12.5];
                    [self->_infoLabel setStringValue:@"Showing Bootlogo..."];
                });
                err = @"send setpicture command";
                NSString *setpic = @"setpicture 0";
                ret = [userDevice sendCMD:setpic];
                err = @"send bgcolor command";
                NSString *colour = @"bgcolor 0 0 0";
                ret = [userDevice sendCMD:colour];

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_bootProgBar incrementBy:12.5];
                    [self->_infoLabel setStringValue:@"Sending DeviceTree..."];
                });
                NSString *dtree =
                    [NSString stringWithFormat:@"%@/devicetree.img4", [[NSBundle mainBundle] resourcePath]];
                err = @"send Devicetree";
                ret = [userDevice sendImage:dtree];

                NSString *dtreeCMD = @"devicetree";
                err = @"boot Devicetree";
                ret = [userDevice sendCMD:dtreeCMD];
                NSString *trustCMD = @"firmware";

                if ((([[userIPSW getIosVersion] containsString:@"12."] ||
                      [[userIPSW getIosVersion] containsString:@"13."] ||
                      [[userIPSW getIosVersion] containsString:@"14."]) &&
                     ![[NSFileManager defaultManager]
                         fileExistsAtPath:[NSString stringWithFormat:@"%@/ramdisk.img4",
                                                                     [[NSBundle mainBundle] resourcePath]]]) ||
                    ([[userDevice getCpid] isEqualToString:@"0x8015"] ||
                     [[userDevice getCpid] isEqualToString:@"0x8010"])) {

                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self->_bootProgBar incrementBy:12.5];
                        [self->_infoLabel setStringValue:@"Sending TrustCache..."];
                    });
                    NSString *trust =
                        [NSString stringWithFormat:@"%@/trustcache.img4", [[NSBundle mainBundle] resourcePath]];
                    err = @"send Trustcache";
                    ret = [userDevice sendImage:trust];
                    err = @"boot Trustcache";
                    ret = [userDevice sendCMD:trustCMD];
                }

                if ([userIPSW getAopfwName] != NULL &&
                    ![[NSFileManager defaultManager]
                        fileExistsAtPath:[NSString stringWithFormat:@"%@/ramdisk.img4",
                                                                    [[NSBundle mainBundle] resourcePath]]]) {

                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self->_infoLabel setStringValue:@"Sending AOPFW..."];
                    });
                    NSString *aop = [NSString stringWithFormat:@"%@/aop.img4", [[NSBundle mainBundle] resourcePath]];
                    ret = [userDevice sendImage:aop];

                    if (ret != 1) {
                        ret = [userDevice sendCMD:trustCMD];
                    }
                }

                if ([userIPSW getCallanName] != NULL &&
                    ![[NSFileManager defaultManager]
                        fileExistsAtPath:[NSString stringWithFormat:@"%@/ramdisk.img4",
                                                                    [[NSBundle mainBundle] resourcePath]]]) {

                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self->_infoLabel setStringValue:@"Sending Callan..."];
                    });
                    NSString *callan =
                        [NSString stringWithFormat:@"%@/callan.img4", [[NSBundle mainBundle] resourcePath]];
                    ret = [userDevice sendImage:callan];

                    if (ret != 1) {
                        ret = [userDevice sendCMD:trustCMD];
                    }
                }

                if ([userIPSW getIspName] != NULL &&
                    ![[NSFileManager defaultManager]
                        fileExistsAtPath:[NSString stringWithFormat:@"%@/ramdisk.img4",
                                                                    [[NSBundle mainBundle] resourcePath]]]) {

                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self->_infoLabel setStringValue:@"Sending ISP..."];
                    });
                    NSString *isp = [NSString stringWithFormat:@"%@/isp.img4", [[NSBundle mainBundle] resourcePath]];
                    ret = [userDevice sendImage:isp];

                    if (ret != 1) {
                        ret = [userDevice sendCMD:trustCMD];
                    }
                }
                if ([[userIPSW getIosVersion] containsString:@"14."] ||
                    [[userIPSW getIosVersion] containsString:@"13."] ||
                    ([[userDevice getCpid] containsString:@"8015"] && [userIPSW getBootRamdisk])) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self->_infoLabel setStringValue:@"Sending SSH Ramdisk..."];
                    });
                    NSString *ramdisk =
                        [NSString stringWithFormat:@"%@/ramdisk.img4", [[NSBundle mainBundle] resourcePath]];
                    if ([[userDevice getCpid] containsString:@"8015"]) {
                        sleep(5);
                    }
                    ret = [userDevice sendImage:ramdisk];

                    if (ret != 1) {
                        ret = [userDevice sendCMD:@"ramdisk"];
                    }
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_bootProgBar incrementBy:12.5];
                    [self->_infoLabel setStringValue:@"Sending Kernel..."];
                });

                NSString *kernel = [NSString stringWithFormat:@"%@/kernel.img4", [[NSBundle mainBundle] resourcePath]];
                err = @"send Kernel";
                ret = [userDevice sendImage:kernel];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_bootProgBar incrementBy:100];
                    [self->_infoLabel setStringValue:@"Booting Device..."];
                });
                NSString *kernelCMD = @"bootx";
                err = @"boot Device";
                ret = [userDevice sendCMD:kernelCMD];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"Booted device successfully!\n");

                if (([[userIPSW getIosVersion] containsString:@"14."] ||
                     [[userIPSW getIosVersion] containsString:@"13."] ||
                     ([[userDevice getCpid] containsString:@"8015"])) &&
                    [userIPSW getBootRamdisk]) {
                    con = 1;
                    [userIPSW setBootRamdisk:FALSE];
                    return;
                } else {
                    [self->_infoLabel setStringValue:@"Finished!"];

                    NSAlert *alert = [[NSAlert alloc] init];
                    [alert addButtonWithTitle:@"OK"];
                    alert.window.titlebarAppearsTransparent = true;
                    [alert setMessageText:[NSString stringWithFormat:@"Device is now booting iOS %@!",
                                                                     [userIPSW getIosVersion]]];
                    [alert setInformativeText:@"Thank you for using Ramiel!"];
                    [alert runModal];
                    [userIPSW teardown];
                    [userKeys teardown];
                    [userDevice teardown];

                    [self->_bootProgBar setHidden:TRUE];
                }
            });
            break;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (ret != 0) {
                [self bootErrorReset:err];
            } else {
                if ([[NSFileManager defaultManager]
                        fileExistsAtPath:[NSString stringWithFormat:@"%@/ramdisk.img4",
                                                                    [[NSBundle mainBundle] resourcePath]]]) {
                    [[NSFileManager defaultManager]
                        removeItemAtPath:[NSString
                                             stringWithFormat:@"%@/ramdisk.img4", [[NSBundle mainBundle] resourcePath]]
                                   error:nil];
                } else {

                    [self refreshInfo:NULL];
                }
            }
        });
    });
}

- (IBAction)loadIPSWShimmy:(NSButton *)sender {
    [self loadIPSW:(int *) 1:NULL];
}
- (void)loadIPSW:(int *)check:(NSButton *)sender {

    [self->_dlIPSWButton setEnabled:FALSE];
    [self->_dlIPSWButton setHidden:TRUE];
    [self->_selIPSWButton setEnabled:FALSE];
    [self->_selIPSWButton setHidden:TRUE];

    stopBackground = 1;

    NSMutableDictionary *ramielPrefs = [NSMutableDictionary
        dictionaryWithDictionary:[NSDictionary dictionaryWithContentsOfFile:
                                                   [NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                              [[NSBundle mainBundle] resourcePath]]]];

    [userIPSW setBootargs:[ramielPrefs objectForKey:@"customBootArgs"]];
    if ([RamielView debugCheck]) {
        [userIPSW setBootargs:[NSString stringWithFormat:@"%@ serial=3",
                                                         [userIPSW getBootargs]]]; // Outputs verbose boot text to
                                                                                   // serial, useful for debugging
    }

    [self->_bootButton setEnabled:FALSE];
    [self->_bootProgBar setHidden:FALSE];
    [self->_settingsButton setHidden:TRUE];
    [self->_settingsButton setEnabled:FALSE];

    checkNum = 0;

    if (check == NULL) {

        [self->_bootProgBar incrementBy:16.66];
        [self->_infoLabel setStringValue:@"Unzipping IPSW..."];

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            extractPath =
                [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
            extractPath = [NSString stringWithFormat:@"%@/RamielIPSW", [[NSBundle mainBundle] resourcePath]];
            if ([RamielView debugCheck])
                NSLog(@"Unzipping IPSW From Path: %@\nto path: %@", [userIPSW getIpswPath], extractPath);
            if ([[[NSFileManager defaultManager] attributesOfItemAtPath:[userIPSW getIpswPath] error:nil] fileSize] <
                1400000000.00) { // If the IPSW is less then 1.3GB then its likely incomplete
                dispatch_async(dispatch_get_main_queue(), ^{
                    [RamielView errorHandler:
                        @"Downloaded IPSW is corrupt":
                            @"Please re-download the IPSW and try again, either from ipsw.me or using Ramiel's IPSW "
                             @"downloader.":
                                 [NSString
                                     stringWithFormat:
                                         @"IPSW's size in bytes is %llu which is to small for an actual IPSW",
                                         [[[NSFileManager defaultManager] attributesOfItemAtPath:[userIPSW getIpswPath]
                                                                                           error:nil] fileSize]]];
                    [userIPSW teardown];
                    [userKeys teardown];
                    userIPSW = NULL;
                    userIPSW = [[IPSW alloc] initIPSWID];
                    return;
                });
            }
            if ([[NSFileManager defaultManager] fileExistsAtPath:[extractPath pathExtension]
                                                     isDirectory:(BOOL * _Nullable) TRUE]) {

                [[NSFileManager defaultManager] removeItemAtPath:extractPath error:nil];
            }

            [[NSFileManager defaultManager] createDirectoryAtPath:extractPath
                                      withIntermediateDirectories:TRUE
                                                       attributes:NULL
                                                            error:nil];

            [SSZipArchive unzipFileAtPath:[userIPSW getIpswPath] toDestination:extractPath];

            checkNum = 1;
        });

    } else {

        [self->_infoLabel setStringValue:@"Waiting for user to pick IPSW..."];

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
                    [self->_bootProgBar incrementBy:16.66];
                    [self->_infoLabel setStringValue:@"Unzipping IPSW..."];
                    [userIPSW setIpswPath:openDlg.URL.path];
                });

                while ([userIPSW getIpswPath] == NULL) {
                }

                extractPath =
                    [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
                extractPath = [NSString stringWithFormat:@"%@/RamielIPSW", [[NSBundle mainBundle] resourcePath]];
                if ([RamielView debugCheck])
                    NSLog(@"Unzipping IPSW From Path: %@\nto path: %@", [userIPSW getIpswPath], extractPath);
                if ([[[NSFileManager defaultManager] attributesOfItemAtPath:[userIPSW getIpswPath] error:nil]
                        fileSize] < 1400000000.00) { // If the IPSW is less then 1.5GB then its likely incomplete
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [RamielView errorHandler:
                            @"Downloaded IPSW is corrupt":
                                @"Please re-download the IPSW and try again, either from ipsw.me or using Ramiel's "
                                 @"IPSW downloader.":
                                     [NSString stringWithFormat:
                                                   @"IPSW's size in bytes is %llu which is to small for an actual IPSW",
                                                   [[[NSFileManager defaultManager]
                                                       attributesOfItemAtPath:[userIPSW getIpswPath]
                                                                        error:nil] fileSize]]];
                        [userIPSW teardown];
                        [userKeys teardown];
                        userIPSW = NULL;
                        userIPSW = [[IPSW alloc] initIPSWID];
                        return;
                    });
                }
                if ([[NSFileManager defaultManager] fileExistsAtPath:[extractPath pathExtension]
                                                         isDirectory:(BOOL * _Nullable) TRUE]) {

                    [[NSFileManager defaultManager] removeItemAtPath:extractPath error:nil];
                }

                [[NSFileManager defaultManager] createDirectoryAtPath:extractPath
                                          withIntermediateDirectories:TRUE
                                                           attributes:NULL
                                                                error:nil];

                [SSZipArchive unzipFileAtPath:[userIPSW getIpswPath] toDestination:extractPath];

                checkNum = 1;
            });

        } else {
            [self->_bootProgBar setHidden:TRUE];
            [self refreshInfo:NULL];
            return;
        }
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        while (checkNum == 0) {
            NSLog(@"Waiting");
            sleep(2);
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_bootProgBar incrementBy:8.33];
            [self->_infoLabel setStringValue:@"Parsing BuildManifest..."];
        });

        if ([[NSFileManager defaultManager]
                fileExistsAtPath:[NSString stringWithFormat:@"%@/BuildManifest.plist", extractPath]]) {

            NSDictionary *manifestData = [NSDictionary
                dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/BuildManifest.plist", extractPath]];
            [userIPSW setIosVersion:[manifestData objectForKey:@"ProductVersion"]]; // Get IPSW's iOS version
            [userIPSW
                setSupportedModels:[manifestData objectForKey:@"SupportedProductTypes"]]; // Get supported devices list
            int supported = 0;
            for (int i = 0; i < [[userIPSW getSupportedModels] count]; i++) {
                if ([[[userIPSW getSupportedModels] objectAtIndex:i] containsString:[userDevice getModel]]) {
                    supported = 1;
                }
            }
            if (supported == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [RamielView errorHandler:
                        @"IPSW is not valid for this device":
                            @"Please pick another IPSW or download one that is valid for your device":@"N/A"];
                    [self refreshInfo:NULL];
                });
                return;
            }

            NSArray *buildID = [manifestData objectForKey:@"BuildIdentities"];

            if ([buildID[0][@"Info"][@"VariantContents"][@"VinylFirmware"] isEqual:@"Release"]) {
                [userIPSW setReleaseBuild:YES];
            } else {
                [userIPSW setReleaseBuild:NO];
            }
            if ([[ramielPrefs objectForKey:@"skipVerification"] isEqual:@(0)]) {

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_bootProgBar incrementBy:8.33];
                    [self->_infoLabel setStringValue:@"Verifying IPSW..."];
                });

                CFStringRef md5hash = FileMD5HashCreateWithPath((CFStringRef)CFBridgingRetain([userIPSW getIpswPath]),
                                                                FileHashDefaultChunkSizeForReadingData);

                NSURL *ipswMD5SUM =
                    [NSURL URLWithString:[NSString stringWithFormat:@"https://api.ipsw.me/v2.1/%@/%@/md5sum",
                                                                    [userDevice getModel], [userIPSW getIosVersion]]];
                NSURLRequest *request = [NSURLRequest requestWithURL:ipswMD5SUM];
                NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
                // NSURLSessionDataTask *test = [[NSURLSession init] dataTaskWithRequest:request];
                //[test resume];
                NSString *dataString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];

                if ([RamielView debugCheck])
                    NSLog(@"md5sum of IPSW: %@\nExpected md5sum: %@", md5hash, dataString);
                if (![(__bridge NSString *)md5hash isEqualToString:dataString]) {

                    [[NSFileManager defaultManager] removeItemAtPath:[userIPSW getIpswPath] error:nil];

                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self->_bootProgBar setHidden:TRUE];
                        [RamielView errorHandler:
                            @"MD5SUM mismatch with IPSW, please re-download IPSW.":
                                [NSString stringWithFormat:@"IPSW's MD5SUM is %@ when it should be %@. "
                                                           @"Downloaded IPSW will be deleted",
                                                           md5hash, dataString
                        ]:@"N/A"];
                    });

                    [self refreshInfo:NULL];

                    return;

                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self->_bootProgBar incrementBy:8.33];
                    });
                }
            } else {
                if ([RamielView debugCheck])
                    NSLog(@"User chose to skip IPSW verification, hopefully the IPSW isn't corrupted :)");
            }

            for (int i = 0; i < [buildID count]; i++) {

                if ([buildID[i][@"ApChipID"] isEqual:[userDevice getCpid]]) {

                    if ([buildID[i][@"Info"][@"DeviceClass"] isEqual:[userDevice getHardware_model]]) {

                        [userIPSW setIbssName:buildID[i][@"Manifest"][@"iBSS"][@"Info"][@"Path"]];
                        [userIPSW setIbecName:buildID[i][@"Manifest"][@"iBEC"][@"Info"][@"Path"]];
                        [userIPSW setIbootName:buildID[i][@"Manifest"][@"iBoot"][@"Info"][@"Path"]];
                        [userIPSW setDeviceTreeName:buildID[i][@"Manifest"][@"DeviceTree"][@"Info"][@"Path"]];
                        [userIPSW setKernelName:buildID[i][@"Manifest"][@"KernelCache"][@"Info"][@"Path"]];
                        [userIPSW
                            setTrustCacheName:[NSString
                                                  stringWithFormat:@"Firmware/%@.trustcache",
                                                                   buildID[i][@"Manifest"][@"OS"][@"Info"][@"Path"]]];
                        if ([[userIPSW getIosVersion] containsString:@"14."] ||
                            ([[userIPSW getIosVersion] containsString:@"13."]) ||
                            ([[userDevice getCpid] containsString:@"8015"])) {
                            [userIPSW
                                setRestoreRamdiskName:buildID[i][@"Manifest"][@"RestoreRamDisk"][@"Info"][@"Path"]];
                        }

                        if (buildID[i][@"Manifest"][@"AOP"][@"Info"][@"Path"] != NULL) {
                            [userIPSW setAopfwName:buildID[i][@"Manifest"][@"AOP"][@"Info"][@"Path"]];
                        }
                        if (buildID[i][@"Manifest"][@"AudioCodecFirmware"][@"Info"][@"Path"] != NULL) {
                            [userIPSW setCallanName:buildID[i][@"Manifest"][@"AudioCodecFirmware"][@"Info"][@"Path"]];
                        }

                        if (buildID[i][@"Manifest"][@"ISP"][@"Info"][@"Path"] != NULL) {
                            [userIPSW setIspName:buildID[i][@"Manifest"][@"ISP"][@"Info"][@"Path"]];
                        }

                        if (buildID[i][@"Manifest"][@"Multitouch"][@"Info"][@"Path"] != NULL) {
                            [userIPSW setTouchName:buildID[i][@"Manifest"][@"Multitouch"][@"Info"][@"Path"]];
                        }
                        break;
                    }
                }
            }

            if ([userIPSW getIbssName] != NULL) {

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_bootProgBar incrementBy:16.66];
                    [self->_infoLabel setStringValue:@"Moving Files..."];
                });

                NSString *resourcesFolder = [[NSBundle mainBundle] resourcePath];

                [[NSFileManager defaultManager]
                    removeItemAtPath:[NSString stringWithFormat:@"%@/RamielFiles", resourcesFolder]
                               error:nil];

                [[NSFileManager defaultManager]
                          createDirectoryAtPath:[NSString stringWithFormat:@"%@/RamielFiles", resourcesFolder]
                    withIntermediateDirectories:YES
                                     attributes:nil
                                          error:nil];

                [[NSFileManager defaultManager]
                    moveItemAtPath:[NSString stringWithFormat:@"%@/%@", extractPath, [userIPSW getIbssName]]
                            toPath:[NSString stringWithFormat:@"%@/RamielFiles/ibss.im4p", resourcesFolder]
                             error:nil];
                [[NSFileManager defaultManager]
                    moveItemAtPath:[NSString stringWithFormat:@"%@/%@", extractPath, [userIPSW getIbecName]]
                            toPath:[NSString stringWithFormat:@"%@/RamielFiles/ibec.im4p", resourcesFolder]
                             error:nil];
                [[NSFileManager defaultManager]
                    moveItemAtPath:[NSString stringWithFormat:@"%@/%@", extractPath, [userIPSW getDeviceTreeName]]
                            toPath:[NSString stringWithFormat:@"%@/RamielFiles/devicetree.im4p", resourcesFolder]
                             error:nil];
                [[NSFileManager defaultManager]
                    moveItemAtPath:[NSString stringWithFormat:@"%@/%@", extractPath, [userIPSW getTrustCacheName]]
                            toPath:[NSString stringWithFormat:@"%@/RamielFiles/trustcache.im4p", resourcesFolder]
                             error:nil];
                [[NSFileManager defaultManager]
                    moveItemAtPath:[NSString stringWithFormat:@"%@/%@", extractPath, [userIPSW getKernelName]]
                            toPath:[NSString stringWithFormat:@"%@/RamielFiles/kernel.im4p", resourcesFolder]
                             error:nil];
                if ([[userIPSW getIosVersion] containsString:@"14."] ||
                    [[userIPSW getIosVersion] containsString:@"13."] ||
                    ([[userDevice getCpid] containsString:@"8015"])) {
                    [[NSFileManager defaultManager]
                        moveItemAtPath:[NSString
                                           stringWithFormat:@"%@/%@", extractPath, [userIPSW getRestoreRamdiskName]]
                                toPath:[NSString stringWithFormat:@"%@/RamielFiles/ramdisk.im4p", resourcesFolder]
                                 error:nil];
                }
                if ([userIPSW getAopfwName] != NULL) {
                    [[NSFileManager defaultManager]
                        moveItemAtPath:[NSString stringWithFormat:@"%@/%@", extractPath, [userIPSW getAopfwName]]
                                toPath:[NSString stringWithFormat:@"%@/RamielFiles/aop.im4p", resourcesFolder]
                                 error:nil];
                }
                if ([userIPSW getCallanName] != NULL) {
                    [[NSFileManager defaultManager]
                        moveItemAtPath:[NSString stringWithFormat:@"%@/%@", extractPath, [userIPSW getCallanName]]
                                toPath:[NSString stringWithFormat:@"%@/RamielFiles/callan.im4p", resourcesFolder]
                                 error:nil];
                }
                if ([userIPSW getIspName] != NULL) {
                    [[NSFileManager defaultManager]
                        moveItemAtPath:[NSString stringWithFormat:@"%@/%@", extractPath, [userIPSW getIspName]]
                                toPath:[NSString stringWithFormat:@"%@/RamielFiles/isp.im4p", resourcesFolder]
                                 error:nil];
                }
                if ([userIPSW getTouchName] != NULL) {
                    [[NSFileManager defaultManager]
                        moveItemAtPath:[NSString stringWithFormat:@"%@/%@", extractPath, [userIPSW getTouchName]]
                                toPath:[NSString stringWithFormat:@"%@/RamielFiles/touch.im4p", resourcesFolder]
                                 error:nil];
                }
                if ([[userIPSW getIosVersion] containsString:@"9."] ||
                    [[userIPSW getIosVersion] containsString:@"8."] ||
                    [[userIPSW getIosVersion] containsString:@"7."]) {
                    [[NSFileManager defaultManager]
                        moveItemAtPath:[NSString stringWithFormat:@"%@/%@", extractPath, [userIPSW getIbootName]]
                                toPath:[NSString stringWithFormat:@"%@/RamielFiles/iboot.im4p", resourcesFolder]
                                 error:nil];
                }

                [[NSFileManager defaultManager] removeItemAtPath:extractPath error:nil];

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_bootProgBar incrementBy:16.66];
                    [self->_infoLabel setStringValue:@"Grabbing Firmware Keys..."];
                });
                if ([userKeys checkLocalKeys:userDevice:userIPSW]) {
                    [userKeys readFirmwareKeysFromFile:userDevice:userIPSW];
                } else {
                    if (![userKeys fetchKeysFromWiki:userDevice:userIPSW:manifestData]) {
                        // Show error message here
                        [self refreshInfo:NULL];
                        return;
                    }
                }
                if (![userKeys getUsingLocalKeys]) {
                    if (![userKeys writeFirmwareKeysToFile:userDevice:userIPSW]) {
                        // Failed to write to file
                        // Show error message here
                    }
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_bootProgBar incrementBy:16.66];
                    [self->_infoLabel setStringValue:@"Patching iBSS/iBEC..."];
                });
                if (!([userKeys getIbssKEY].length == 64 && [userKeys getIbecKEY].length == 64 &&
                      [userKeys getIbssIV].length == 32 &&
                      [userKeys getIbecIV].length == 32)) { // Ensure that the keys we got are the right length

                    dispatch_async(dispatch_get_main_queue(), ^{
                        [RamielView errorHandler:
                            @"Received malformed keys":
                                [NSString
                                    stringWithFormat:@"Expected string lengths of 64 & 32 but got %lu, %lu & %lu, %lu",
                                                     (unsigned long)[userKeys getIbssKEY].length,
                                                     (unsigned long)[userKeys getIbssIV].length,
                                                     (unsigned long)[userKeys getIbecKEY].length,
                                                     (unsigned long)[userKeys getIbecIV].length
                        ]:[NSString stringWithFormat:
                                        @"Key Information:\n\niBSS Key: %@\niBSS IVs: %@\niBEC Key: %@\niBEC IVs: %@",
                                        [userKeys getIbssKEY], [userKeys getIbssIV], [userKeys getIbecKEY],
                                        [userKeys getIbecIV]]];

                        [self refreshInfo:NULL];
                        return;
                    });
                }

                // This is all done now, will leave just because
                // To add 14.x support we need to:
                // 1: Prompt for the SHSH the device was restored with
                // 2: Use that if possible, if not then we need to download the normal
                // files + restore ramdisk 3: We need to create an SSH ramdisk that
                // will allow us to dump disk1's SHSH 4: Then we need to boot said
                // ramdisk, dump SHSH to host machine, convert it to SHSH then use
                // that to sign images 5: Save the new 14.x SHSH somewhere for future
                // use and name it with the devices ECID, Model and the iOS version
                // it's for

                // This should allow us to bypass the
                // "/private/preboot/RANDOM_LONG_STRING" folder not existing issue
                // when using mismatching SHSH It's a bit long-winded and annoying but
                // currently tether booting iOS 14.x with anything other then
                // checkra1n is impossible without having the SHSH the device was
                // restored with on hand.

                if ([[userIPSW getIosVersion] containsString:@"14."] ||
                    ([[userDevice getCpid] containsString:@"8015"] || [[userDevice getCpid] containsString:@"8010"])) {
                    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                    NSString *documentsDirectory = [paths objectAtIndex:0];
                    [[NSFileManager defaultManager]
                              createDirectoryAtPath:[NSString stringWithFormat:@"%@/Ramiel/shsh", documentsDirectory]
                        withIntermediateDirectories:YES
                                         attributes:nil
                                              error:nil];
                    if ([[NSFileManager defaultManager]
                            fileExistsAtPath:[NSString stringWithFormat:@"%@/Ramiel/shsh/%llu_%@.shsh",
                                                                        documentsDirectory,
                                                                        (uint64_t)[userDevice getEcid],
                                                                        [userIPSW getIosVersion]]]) {

                        shshPath = [NSString stringWithFormat:@"%@/Ramiel/shsh/%llu_%@.shsh", documentsDirectory,
                                                              (uint64_t)[userDevice getEcid], [userIPSW getIosVersion]];

                    } else {
                        // Inform user we need to dump SHSH
                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSAlert *dumpInform = [[NSAlert alloc] init];
                            [dumpInform
                                setMessageText:
                                    [NSString stringWithFormat:
                                                  @"Warning: Ramiel needs to dump your devices SHSH to boot iOS %@",
                                                  [userIPSW getIosVersion]]];
                            [dumpInform setInformativeText:@"This process will take a minute or so to complete, and "
                                                           @"will require you to manually re-enter DFU mode to "
                                                           @"continue. This will only need to be done once."];
                            dumpInform.window.titlebarAppearsTransparent = true;
                            [dumpInform runModal];
                            con = 1;
                        });
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self->_infoLabel setStringValue:@"Creating SSH Ramdisk..."];
                            [self->_bootProgBar incrementBy:-100.00];
                        });
                        while (con == 0) {
                            NSLog(@"Waiting");
                            sleep(2);
                        }
                        con = 0;
                        // Create SSH Ramdisk
                        [userIPSW setBootRamdisk:TRUE];
                        NSString *returnString =
                            [RamielView img4toolCMD:[NSString stringWithFormat:@"-e -o %@/RamielFiles/ramdisk.dmg "
                                                                               @"%@/RamielFiles/ramdisk.im4p",
                                                                               [[NSBundle mainBundle] resourcePath],
                                                                               [[NSBundle mainBundle] resourcePath]]];
                        if ([returnString containsString:@"failed"]) {
                            [RamielView errorHandler:
                                @"Failed to extract ramdisk DMG.":[NSString
                                                                      stringWithFormat:@"img4tool returned output: %@",
                                                                                       returnString
                            ]:returnString];
                            [self refreshInfo:NULL];
                            return;
                        }
                        [RamielView otherCMD:[NSString stringWithFormat:@"/usr/bin/hdiutil resize -size "
                                                                        @"115MB %@/RamielFiles/ramdisk.dmg",
                                                                        [[NSBundle mainBundle] resourcePath]]];
                        [[NSFileManager defaultManager] removeItemAtPath:@"/tmp/RamielMount" error:nil];
                        [[NSFileManager defaultManager] createDirectoryAtPath:@"/tmp/RamielMount"
                                                  withIntermediateDirectories:YES
                                                                   attributes:nil
                                                                        error:nil];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self->_infoLabel setStringValue:@"Adding files to Ramdisk..."];
                            [self->_bootProgBar incrementBy:14.28];
                        });
                        [RamielView otherCMD:[NSString stringWithFormat:@"/usr/bin/hdiutil attach -mountpoint "
                                                                        @"/tmp/RamielMount %@/RamielFiles/ramdisk.dmg",
                                                                        [[NSBundle mainBundle] resourcePath]]];

                        // Download SSH.tar
                        // https://github.com/MatthewPierson/sshTar/blob/main/ssh.tar?raw=true
                        if (![[NSFileManager defaultManager]
                                fileExistsAtPath:[NSString stringWithFormat:@"%@/ssh/ssh.tar",
                                                                            [[NSBundle mainBundle] resourcePath]]]) {
                            NSString *stringURL =
                                @"https://github.com/MatthewPierson/sshTar/blob/main/ssh.tar?raw=true";
                            NSURL *url = [NSURL URLWithString:stringURL];
                            NSData *urlData = [NSData dataWithContentsOfURL:url];
                            if (urlData) {

                                NSString *filePath =
                                    [NSString stringWithFormat:@"%@/ssh/ssh.tar", [[NSBundle mainBundle] resourcePath]];
                                [urlData writeToFile:filePath atomically:YES];
                            }
                        }
                        [RamielView otherCMD:[NSString stringWithFormat:@"%@/ssh/gtar -x --no-overwrite-dir -f "
                                                                        @"%@/ssh/ssh.tar -C /tmp/RamielMount/",
                                                                        [[NSBundle mainBundle] resourcePath],
                                                                        [[NSBundle mainBundle] resourcePath]]];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self->_infoLabel setStringValue:@"Adding entitlements..."];
                            [self->_bootProgBar incrementBy:14.28];
                        });
                        [RamielView otherCMD:[NSString stringWithFormat:@"%@/ssh/ldid2 -S%@/ssh/dd_ent.xml "
                                                                        @"/tmp/RamielMount/bin/dd",
                                                                        [[NSBundle mainBundle] resourcePath],
                                                                        [[NSBundle mainBundle] resourcePath]]];

                        sleep(1);
                        [RamielView otherCMD:[NSString stringWithFormat:@"%@/ssh/ldid2 -M -S%@/ssh/ent.xml "
                                                                        @"/tmp/RamielMount/sbin/mount",
                                                                        [[NSBundle mainBundle] resourcePath],
                                                                        [[NSBundle mainBundle] resourcePath]]];
                        [RamielView otherCMD:[NSString stringWithFormat:@"%@/ssh/ldid2 -M -S%@/ssh/ent.xml "
                                                                        @"/tmp/RamielMount/sbin/umount",
                                                                        [[NSBundle mainBundle] resourcePath],
                                                                        [[NSBundle mainBundle] resourcePath]]];
                        // Maybe other sign other stuff??

                        NSArray *bin = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/tmp/RamielMount/bin"
                                                                                           error:nil];

                        for (int i = 0; i < [bin count]; i++) {
                            [RamielView
                                otherCMD:[NSString stringWithFormat:@"%@/ssh/ldid2 -M%@/ssh/ent.xml "
                                                                    @"/tmp/RamielMount/bin/%@",
                                                                    [[NSBundle mainBundle] resourcePath],
                                                                    [[NSBundle mainBundle] resourcePath], bin[i]]];
                        }
                        bin = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/tmp/RamielMount/usr/bin/"
                                                                                  error:nil];

                        for (int i = 0; i < [bin count]; i++) {
                            [RamielView
                                otherCMD:[NSString stringWithFormat:@"%@/ssh/ldid2 -M%@/ssh/ent.xml "
                                                                    @"/tmp/RamielMount/usr/bin/%@",
                                                                    [[NSBundle mainBundle] resourcePath],
                                                                    [[NSBundle mainBundle] resourcePath], bin[i]]];
                        }
                        bin = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/tmp/RamielMount/usr/sbin/"
                                                                                  error:nil];

                        for (int i = 0; i < [bin count]; i++) {
                            [RamielView
                                otherCMD:[NSString stringWithFormat:@"%@/ssh/ldid2 -M%@/ssh/ent.xml "
                                                                    @"/tmp/RamielMount/usr/sbin/%@",
                                                                    [[NSBundle mainBundle] resourcePath],
                                                                    [[NSBundle mainBundle] resourcePath], bin[i]]];
                        }
                        bin =
                            [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/tmp/RamielMount/usr/local/bin/"
                                                                                error:nil];

                        for (int i = 0; i < [bin count]; i++) {
                            [RamielView
                                otherCMD:[NSString stringWithFormat:@"%@/ssh/ldid2 -M%@/ssh/ent.xml "
                                                                    @"/tmp/RamielMount/usr/local/bin/%@",
                                                                    [[NSBundle mainBundle] resourcePath],
                                                                    [[NSBundle mainBundle] resourcePath], bin[i]]];
                        }
                        bin = [[NSFileManager defaultManager]
                            contentsOfDirectoryAtPath:@"/tmp/RamielMount/usr/local/sbin/"
                                                error:nil];

                        for (int i = 0; i < [bin count]; i++) {
                            [RamielView
                                otherCMD:[NSString stringWithFormat:@"%@/ssh/ldid2 -M%@/ssh/ent.xml "
                                                                    @"/tmp/RamielMount/usr/local/sbin/%@",
                                                                    [[NSBundle mainBundle] resourcePath],
                                                                    [[NSBundle mainBundle] resourcePath], bin[i]]];
                        }

                        bin = [[NSFileManager defaultManager]
                            contentsOfDirectoryAtPath:@"/tmp/RamielMount/System/Library/Filesystems/apfs.fs/"
                                                error:nil];

                        for (int i = 0; i < [bin count]; i++) {
                            [RamielView
                                otherCMD:[NSString stringWithFormat:@"%@/ssh/ldid2 -M -S%@/ssh/ent.xml "
                                                                    @"/tmp/RamielMount/System/Library/Filesystems/"
                                                                    @"apfs.fs/%@",
                                                                    [[NSBundle mainBundle] resourcePath],
                                                                    [[NSBundle mainBundle] resourcePath], bin[i]]];
                        }
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self->_infoLabel setStringValue:@"Unmounting ramdisk..."];
                            [self->_bootProgBar incrementBy:14.28];
                        });
                        [RamielView otherCMD:@"/usr/bin/hdiutil detach -force /tmp/RamielMount"];
                        [RamielView
                            otherCMD:[NSString stringWithFormat:
                                                   @"/usr/bin/hdiutil resize -sectors min %@/RamielFiles/ramdisk.dmg",
                                                   [[NSBundle mainBundle]
                                                       resourcePath]]]; // Shrink dmg to smallest it will go, only needs
                                                                        // to be larger while we add files to it
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self->_infoLabel setStringValue:@"Packing back to IM4P/IMG4..."];
                            [self->_bootProgBar incrementBy:14.28];
                        });
                        returnString = [RamielView
                            img4toolCMD:[NSString stringWithFormat:@"-c %@/RamielFiles/ramdisk.ssh.im4p -t rdsk "
                                                                   @"-d SSH_RAMDISK  %@/RamielFiles/ramdisk.dmg",
                                                                   [[NSBundle mainBundle] resourcePath],
                                                                   [[NSBundle mainBundle] resourcePath]]];
                        if ([returnString containsString:@"failed"]) {
                            [RamielView errorHandler:
                                @"Failed to create ramdisk IM4P from ramdisk DMG":
                                    [NSString stringWithFormat:@"img4tool returned output: %@", returnString
                            ]:returnString];
                            [self refreshInfo:NULL];
                            return;
                        }
                        if (![[ramielPrefs objectForKey:@"customSHSHPath"] containsString:@"N/A"]) {
                            if ([RamielView debugCheck])
                                NSLog(@"Using user-provided SHSH from: %@",
                                      [ramielPrefs objectForKey:@"customSHSHPath"]);
                            shshPath = [ramielPrefs objectForKey:@"customSHSHPath"];
                        } else {
                            if ([[NSFileManager defaultManager]
                                    fileExistsAtPath:[NSString stringWithFormat:@"%@/shsh/%@.shsh",
                                                                                [[NSBundle mainBundle] resourcePath],
                                                                                [userDevice getCpid]]]) {
                                shshPath =
                                    [NSString stringWithFormat:@"%@/shsh/%@.shsh", [[NSBundle mainBundle] resourcePath],
                                                               [userDevice getCpid]];
                            } else {
                                shshPath = [NSString
                                    stringWithFormat:@"%@/shsh/shsh.shsh", [[NSBundle mainBundle] resourcePath]];
                            }
                        }
                        [RamielView
                            img4toolCMD:[NSString stringWithFormat:@"-c %@/ramdisk.img4 -p "
                                                                   @"%@/RamielFiles/ramdisk.ssh.im4p -s %@",
                                                                   [[NSBundle mainBundle] resourcePath],
                                                                   [[NSBundle mainBundle] resourcePath], shshPath]];

                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self->_infoLabel setStringValue:@"Preparing other boot files..."];
                            [self->_bootProgBar incrementBy:7.14];
                        });
                        [self prepareSSHBootChain];

                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self->_infoLabel setStringValue:@"Booting SSH Ramdisk..."];
                            [self->_bootProgBar incrementBy:7.14];
                        });

                        // Boot SSH Ramdisk
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self bootDevice:NULL];
                        });
                        while (con == 0) {
                            NSLog(@"Waiting");
                            sleep(2);
                        }
                        con = 0;

                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self->_infoLabel setStringValue:@"Waiting For Device..."];
                            [self->_bootProgBar incrementBy:71.40];
                            [self->_bootProgBar incrementBy:14.28];
                        });

                        sleep(15);

                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self->_infoLabel setStringValue:@"Dumping SHSH..."];
                            [self->_bootProgBar incrementBy:14.28];
                        });

                        NSTask *task = [[NSTask alloc] init];
                        [task setLaunchPath:@"/bin/bash"];
                        [task setArguments:@[
                            @"-c",
                            [NSString stringWithFormat:@"%@/ssh/iproxy 2222 44", [[NSBundle mainBundle] resourcePath]]
                        ]];
                        [task launch];
                        NSString *prefix;
                        if (@available(macOS 11.0, *)) {
                            prefix = @"/usr/bin";
                        } else {
                            prefix = @"/usr/local/bin";
                        }
                        // Dump SHSH
                        [RamielView otherCMD:[NSString stringWithFormat:@"%@/python3 %@/ssh/dump.py", prefix,
                                                                        [[NSBundle mainBundle] resourcePath]]];
                        // Have to do this twice
                        [RamielView otherCMD:[NSString stringWithFormat:@"%@/python3 %@/ssh/dump.py", prefix,
                                                                        [[NSBundle mainBundle] resourcePath]]];
                        // ssh -p 2222 root@localhost "dd if=/dev/disk1 bs=256 count=$((0x4000))" | dd
                        // of=/tmp/dump.raw
                        [RamielView
                            img4toolCMD:[NSString
                                            stringWithFormat:@"--convert -s %@/Ramiel/shsh/%llu_%@.shsh /tmp/dump.raw",
                                                             documentsDirectory, (uint64_t)[userDevice getEcid],
                                                             [userIPSW getIosVersion]]];

                        if ([[NSFileManager defaultManager]
                                fileExistsAtPath:[NSString stringWithFormat:@"%@/Ramiel/shsh/%llu_%@.shsh",
                                                                            documentsDirectory,
                                                                            (uint64_t)[userDevice getEcid],
                                                                            [userIPSW getIosVersion]]]) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                NSAlert *rebootAlert = [[NSAlert alloc] init];
                                [rebootAlert setMessageText:@"SHSH dumped successfully!"];
                                [rebootAlert setInformativeText:@"Please reboot your device into DFU mode for "
                                                                @"re-explotation\nPress OK once you are done"];
                                rebootAlert.window.titlebarAppearsTransparent = true;
                                [rebootAlert runModal];
                                [[NSFileManager defaultManager] removeItemAtPath:@"/tmp/dump.raw" error:nil];
                                con = 1;
                            });
                            while (con == 0) {
                                NSLog(@"Waiting");
                                sleep(2);
                            }
                            con = 0;
                            // Wait for device to reconnect

                            int i;
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self->_infoLabel setStringValue:@"Waiting for DFU device..."];
                                [self->_bootProgBar incrementBy:-100.00];
                            });
                            for (i = 0; i <= 100; i++) {
                                irecv_client_t temp = NULL;
                                irecv_error_t err = irecv_open_with_ecid(&temp, (uint64_t)[userDevice getEcid]);
                                [userDevice setIRECVClient:temp];
                                if (err == IRECV_E_UNSUPPORTED) {
                                    fprintf(stderr, "ERROR: %s\n", irecv_strerror(err));
                                    break;
                                } else if (err != IRECV_E_SUCCESS)
                                    sleep(1);
                                else
                                    break;
                            }

                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self->_infoLabel setStringValue:@"Exploiting device with checkm8..."];

                                // Exploit device

                                int ret = [userDevice runCheckm8];

                                if (ret != 0) {
                                    // Exploit failed or something went wrong
                                    NSAlert *exploitFailed = [[NSAlert alloc] init];
                                    exploitFailed.window.titlebarAppearsTransparent = TRUE;
                                    [exploitFailed setMessageText:@"Error: Failed to exploit device.."];
                                    [exploitFailed
                                        setInformativeText:@"Please reboot your device into DFU mode and try "
                                                           @"again. Press OK once the device is back in DFU mode."];
                                    while (ret != 0) {
                                        [exploitFailed runModal];
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            [self->_infoLabel setStringValue:@"Waiting for DFU device..."];
                                            [self->_bootProgBar incrementBy:-100.00];
                                        });
                                        for (int i = 0; i <= 100; i++) {
                                            irecv_client_t temp = NULL;
                                            irecv_error_t err =
                                                irecv_open_with_ecid(&temp, (uint64_t)[userDevice getEcid]);
                                            [userDevice setIRECVClient:temp];
                                            if (err == IRECV_E_UNSUPPORTED) {
                                                fprintf(stderr, "ERROR: %s\n", irecv_strerror(err));
                                                break;
                                            } else if (err != IRECV_E_SUCCESS)
                                                sleep(1);
                                            else
                                                break;
                                        }
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            [self->_infoLabel setStringValue:@"Exploiting device with checkm8..."];
                                        });
                                        ret = [userDevice runCheckm8];
                                    }
                                }
                                con = 1;
                                [self->_bootProgBar incrementBy:91.57];
                            });
                            while (con == 0) {
                                NSLog(@"Waiting");
                                sleep(2);
                            }
                            con = 0;

                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self->_infoLabel setStringValue:@"Patching iBSS/iBEC..."];
                            });

                            // No need for these anymore, we can delete them :)
                            [[NSFileManager defaultManager]
                                removeItemAtPath:[NSString stringWithFormat:@"%@/ramdisk.img4",
                                                                            [[NSBundle mainBundle] resourcePath]]
                                           error:nil];
                            [[NSFileManager defaultManager]
                                removeItemAtPath:[NSString stringWithFormat:@"%@/RamielFiles/ramdisk.dmg",
                                                                            [[NSBundle mainBundle] resourcePath]]
                                           error:nil];
                            [[NSFileManager defaultManager]
                                removeItemAtPath:[NSString stringWithFormat:@"%@/RamielFiles/ramdisk.im4p",
                                                                            [[NSBundle mainBundle] resourcePath]]
                                           error:nil];
                            [[NSFileManager defaultManager]
                                removeItemAtPath:[NSString stringWithFormat:@"%@/RamielFiles/ramdisk.ssh.im4p",
                                                                            [[NSBundle mainBundle] resourcePath]]
                                           error:nil];

                            // Continue with Ramiel

                        } else {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [RamielView errorHandler:
                                    @"Failed to dump SHSH":@"Please reboot back into DFU and try again.":@"N/A"];

                                [self deviceStuff];
                            });
                            return;
                        }
                    }
                }

                sleep(1);

                [RamielView img4toolCMD:[NSString stringWithFormat:@"-e -o %@/RamielFiles/ibss.raw --iv %@ "
                                                                   @"--key %@ %@/RamielFiles/ibss.im4p",
                                                                   [[NSBundle mainBundle] resourcePath],
                                                                   [userKeys getIbssIV], [userKeys getIbssKEY],
                                                                   [[NSBundle mainBundle] resourcePath]]];

                [RamielView img4toolCMD:[NSString stringWithFormat:@"-e -o %@/RamielFiles/ibec.raw --iv %@ "
                                                                   @"--key %@ %@/RamielFiles/ibec.im4p",
                                                                   [[NSBundle mainBundle] resourcePath],
                                                                   [userKeys getIbecIV], [userKeys getIbecKEY],
                                                                   [[NSBundle mainBundle] resourcePath]]];
                if ([[userIPSW getIosVersion] containsString:@"9."] ||
                    [[userIPSW getIosVersion] containsString:@"8."] ||
                    [[userIPSW getIosVersion] containsString:@"7."]) {
                    [RamielView img4toolCMD:[NSString stringWithFormat:@"-e -o %@/RamielFiles/iboot.raw --iv %@ "
                                                                       @"--key %@ %@/RamielFiles/iboot.im4p",
                                                                       [[NSBundle mainBundle] resourcePath],
                                                                       [userKeys getIbootIV], [userKeys getIbootKEY],
                                                                       [[NSBundle mainBundle] resourcePath]]];
                }

                const char *ibssPath = [[NSString
                    stringWithFormat:@"%@/RamielFiles/ibss.raw", [[NSBundle mainBundle] resourcePath]] UTF8String];
                const char *ibssPwnPath = [[NSString
                    stringWithFormat:@"%@/RamielFiles/ibss.pwn", [[NSBundle mainBundle] resourcePath]] UTF8String];
                const char *ibecPath = [[NSString
                    stringWithFormat:@"%@/RamielFiles/ibec.raw", [[NSBundle mainBundle] resourcePath]] UTF8String];
                const char *ibecPwnPath = [[NSString
                    stringWithFormat:@"%@/RamielFiles/ibec.pwn", [[NSBundle mainBundle] resourcePath]] UTF8String];
                const char *ibootPath = [[NSString
                    stringWithFormat:@"%@/RamielFiles/iboot.raw", [[NSBundle mainBundle] resourcePath]] UTF8String];
                const char *ibootArgsPath = [[NSString
                    stringWithFormat:@"%@/RamielFiles/iboot.pwn", [[NSBundle mainBundle] resourcePath]] UTF8String];
                const char *args = [[NSString stringWithFormat:@"%@", [userIPSW getBootargs]] UTF8String];
                if (![[ramielPrefs objectForKey:@"dualbootDiskNum"] isEqual:@(0)]) {
                    if (![[NSString stringWithFormat:@"%@", [userIPSW getBootargs]] containsString:@"rd=disk0s1s"]) {
                        [userIPSW
                            setBootargs:[NSString stringWithFormat:@"%@ rd=disk0s1s%@", [userIPSW getBootargs],
                                                                   [ramielPrefs objectForKey:@"dualbootDiskNum"]]];
                    }
                    args = [[NSString stringWithFormat:@"%@", [userIPSW getBootargs]] UTF8String];
                }
                int ret;
                if ([[userIPSW getIosVersion] containsString:@"9."] ||
                    [[userIPSW getIosVersion] containsString:@"8."] ||
                    [[userIPSW getIosVersion] containsString:@"7."]) {
                    if ([self downloadiBSS] != 0) {
                        dispatch_queue_t mainQueue = dispatch_get_main_queue();
                        dispatch_sync(mainQueue, ^{
                            [RamielView errorHandler:@"Failed to download iBSS":@"Please try again.":@"N/A"];
                            [self->_bootProgBar setHidden:TRUE];
                            [self refreshInfo:NULL];
                            return;
                        });
                    }
                    patchIBXX((char *)[[NSString stringWithFormat:@"%@/RamielFiles/ibss.raw",
                                                                  [[NSBundle mainBundle] resourcePath]] UTF8String],
                              (char *)[[NSString stringWithFormat:@"%@/RamielFiles/ibss.pwn",
                                                                  [[NSBundle mainBundle] resourcePath]] UTF8String],
                              (char *)args, 0);
                } else {
                    sleep(1);
                    ret = patchIBXX((char *)ibssPath, (char *)ibssPwnPath, (char *)args, 0);

                    if (ret != 0) {
                        dispatch_queue_t mainQueue = dispatch_get_main_queue();
                        dispatch_sync(mainQueue, ^{
                            [RamielView errorHandler:
                                @"Failed to patch iBSS":[NSString stringWithFormat:@"Kairos returned with: %i", ret
                            ]:@"N/A"];
                            [self->_bootProgBar setHidden:TRUE];
                            [self refreshInfo:NULL];
                            return;
                        });
                    }
                }
                if ([[userIPSW getIosVersion] containsString:@"9."] ||
                    [[userIPSW getIosVersion] containsString:@"8."] ||
                    [[userIPSW getIosVersion] containsString:@"7."]) {
                    if ([[ramielPrefs objectForKey:@"amfi"] isEqual:@(1)] &&
                        ![[userIPSW getIosVersion] containsString:@"9."]) {
                        args = [[NSString
                            stringWithFormat:@"%s amfi=0xff cs_enforcement_disable=1 amfi_get_out_of_my_way=1", args]
                            UTF8String]; // Older iOS versions don't need kernel patches for AMFI, just boot args
                    }
                    if ([[userIPSW getIosVersion] containsString:@"9."] &&
                        [[ramielPrefs objectForKey:@"amfi"] isEqual:@(1)]) {
                        dispatch_queue_t mainQueue = dispatch_get_main_queue();
                        dispatch_sync(mainQueue, ^{
                            NSAlert *alert = [[NSAlert alloc] init];
                            [alert setMessageText:@"Warning: iOS 9.x currently doesn't support AMFI patches"];
                            alert.window.titlebarAppearsTransparent = TRUE;
                            [alert runModal];
                        });
                    }
                    patchIBXX((char *)ibootPath, (char *)ibootArgsPath, (char *)args, 1);
                    [RamielView img4toolCMD:[NSString stringWithFormat:@"-c %@/RamielFiles/iboot.patched -t "
                                                                       @"ibec %@/RamielFiles/iboot.pwn",
                                                                       [[NSBundle mainBundle] resourcePath],
                                                                       [[NSBundle mainBundle] resourcePath]]];
                    NSString *lowSignSHSH =
                        [NSString stringWithFormat:@"%@/shsh/shsh.shsh", [[NSBundle mainBundle] resourcePath]];
                    [RamielView
                        img4toolCMD:[NSString
                                        stringWithFormat:@"-c %@/iboot.img4 -p %@/RamielFiles/iboot.patched -s %@",
                                                         [[NSBundle mainBundle] resourcePath],
                                                         [[NSBundle mainBundle] resourcePath], lowSignSHSH]];

                } else {
                    const char *ibecPath = [[NSString
                        stringWithFormat:@"%@/RamielFiles/ibec.raw", [[NSBundle mainBundle] resourcePath]] UTF8String];
                    const char *ibecPwnPath = [[NSString
                        stringWithFormat:@"%@/RamielFiles/ibec.pwn", [[NSBundle mainBundle] resourcePath]] UTF8String];
                    ret = patchIBXX((char *)ibecPath, (char *)ibecPwnPath, (char *)args, 0);

                    if (ret != 0) {
                        dispatch_queue_t mainQueue = dispatch_get_main_queue();
                        dispatch_sync(mainQueue, ^{
                            [RamielView errorHandler:
                                @"Failed to patch iBEC":[NSString stringWithFormat:@"Kairos returned with: %i", ret
                            ]:@"N/A"];
                            [self->_bootProgBar setHidden:TRUE];
                            [self refreshInfo:NULL];
                            return;
                        });
                    }
                    // Check irecovery -s or serial output to see the effect of these :p

                    NSString *ibecRawPath =
                        [NSString stringWithFormat:@"%@/RamielFiles/ibec.pwn", [[NSBundle mainBundle] resourcePath]];
                    NSString *ibssRawPath =
                        [NSString stringWithFormat:@"%@/RamielFiles/ibss.pwn", [[NSBundle mainBundle] resourcePath]];
                    NSData *moskiPatch = [@"Moski" dataUsingEncoding:NSUTF8StringEncoding];
                    NSData *ramielBooterPatch = [@"DoPeopleEvenReadThis?" dataUsingEncoding:NSUTF8StringEncoding];
                    int offset = 640;
                    int ramielOffset = 512;

                    NSFileHandle *fHandleiBEC = [NSFileHandle fileHandleForWritingAtPath:ibecRawPath];
                    NSFileHandle *fHandleiBSS = [NSFileHandle fileHandleForWritingAtPath:ibssRawPath];
                    NSData *moskiWrite = [NSData dataWithBytes:[moskiPatch bytes] length:5];
                    NSData *ramielWrite = [NSData dataWithBytes:[ramielBooterPatch bytes] length:21];
                    [fHandleiBEC seekToFileOffset:offset];
                    [fHandleiBEC writeData:moskiWrite];
                    [fHandleiBEC seekToFileOffset:ramielOffset];
                    [fHandleiBEC writeData:ramielWrite];
                    [fHandleiBEC closeFile];
                    [fHandleiBSS seekToFileOffset:offset];
                    [fHandleiBSS writeData:moskiWrite];
                    [fHandleiBSS seekToFileOffset:ramielOffset];
                    [fHandleiBSS writeData:ramielWrite];
                    [fHandleiBSS closeFile];

                    if (![[ramielPrefs objectForKey:@"bootpartitionPatch"] isEqual:@(0)]) {

                        if ([[userIPSW getIosVersion] containsString:@"13"] ||
                            [[userIPSW getIosVersion] containsString:@"14"]) {
                            int convertInt = [[ramielPrefs objectForKey:@"bootpartitionPatch"] intValue];

                            NSString *filepath = [NSString
                                stringWithFormat:@"%@/RamielFiles/ibec.pwn", [[NSBundle mainBundle] resourcePath]];
                            NSData *data0 = [NSData dataWithContentsOfFile:filepath
                                                                   options:NSDataReadingUncached
                                                                     error:NULL];
                            NSData *pattern = [@"T!=2" dataUsingEncoding:NSASCIIStringEncoding];
                            NSRange range = [data0 rangeOfData:pattern options:0 range:NSMakeRange(0, data0.length)];
                            int offset = (int)(range.location + 6);

                            NSFileHandle *fHandle = [NSFileHandle fileHandleForWritingAtPath:filepath];
                            NSData *dataWrite = [NSData dataWithBytes:(const void *)&convertInt length:1];
                            [fHandle seekToFileOffset:offset];
                            [fHandle writeData:dataWrite];
                            [fHandle closeFile];
                            if (![[userIPSW getIosVersion] containsString:@"12"]) {
                                filepath = [NSString stringWithFormat:@"%@/RamielFiles/devicetree.im4p",
                                                                      [[NSBundle mainBundle] resourcePath]];
                                if ([[userIPSW getIosVersion] containsString:@"14"]) {
                                    [RamielView
                                        img4toolCMD:[NSString stringWithFormat:@"-e -o %@/RamielFiles/devicetree.raw "
                                                                               @"%@/RamielFiles/devicetree.im4p",
                                                                               [[NSBundle mainBundle] resourcePath],
                                                                               [[NSBundle mainBundle] resourcePath]]];
                                    filepath = [NSString stringWithFormat:@"%@/RamielFiles/devicetree.raw",
                                                                          [[NSBundle mainBundle] resourcePath]];
                                }

                                data0 = [NSData dataWithContentsOfFile:filepath
                                                               options:NSDataReadingUncached
                                                                 error:NULL];
                                NSMutableData *pattern1 = [NSMutableData data];
                                char bytesToAppend[1] = {0x00};
                                [pattern1 appendBytes:[[@"Data" dataUsingEncoding:NSASCIIStringEncoding] bytes]
                                               length:4];
                                [pattern1 appendBytes:bytesToAppend
                                               length:sizeof(bytesToAppend)]; // Ensure we actually find the right
                                                                              // offset in devicetree

                                range = [data0 rangeOfData:pattern1 options:0 range:NSMakeRange(0, data0.length)];
                                offset = (int)(range.location - 40);
                                int writeInt = 0;
                                fHandle = [NSFileHandle fileHandleForWritingAtPath:filepath];
                                dataWrite = [NSData dataWithBytes:(const void *)&writeInt length:1];
                                [fHandle seekToFileOffset:offset];
                                [fHandle writeData:dataWrite];
                                [fHandle closeFile];

                                if ([[userIPSW getIosVersion] containsString:@"14"]) {
                                    [RamielView
                                        img4toolCMD:[NSString stringWithFormat:@"-c %@/RamielFiles/devicetree.im4p -t "
                                                                               @"dtre %@/RamielFiles/devicetree.raw",
                                                                               [[NSBundle mainBundle] resourcePath],
                                                                               [[NSBundle mainBundle] resourcePath]]];
                                }
                            }
                        }
                    }
                }
                [RamielView
                    img4toolCMD:[NSString stringWithFormat:@"-c %@/RamielFiles/ibss.%@.patched -t "
                                                           @"ibss %@/RamielFiles/ibss.pwn",
                                                           [[NSBundle mainBundle] resourcePath], [userDevice getModel],
                                                           [[NSBundle mainBundle] resourcePath]]];

                [RamielView
                    img4toolCMD:[NSString stringWithFormat:@"-c %@/RamielFiles/ibec.%@.patched -t "
                                                           @"ibec %@/RamielFiles/ibec.pwn",
                                                           [[NSBundle mainBundle] resourcePath], [userDevice getModel],
                                                           [[NSBundle mainBundle] resourcePath]]];
                NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                NSString *documentsDirectory = [paths objectAtIndex:0];
                if ([[NSFileManager defaultManager]
                        fileExistsAtPath:[NSString stringWithFormat:@"%@/Ramiel/shsh/%llu_%@.shsh", documentsDirectory,
                                                                    (uint64_t)[userDevice getEcid],
                                                                    [userIPSW getIosVersion]]]) {

                    shshPath = [NSString stringWithFormat:@"%@/Ramiel/shsh/%llu_%@.shsh", documentsDirectory,
                                                          (uint64_t)[userDevice getEcid], [userIPSW getIosVersion]];

                } else {
                    if (![[ramielPrefs objectForKey:@"customSHSHPath"] containsString:@"N/A"]) {
                        if ([RamielView debugCheck])
                            NSLog(@"Using user-provided SHSH from: %@", [ramielPrefs objectForKey:@"customSHSHPath"]);
                        shshPath = [ramielPrefs objectForKey:@"customSHSHPath"];
                    } else if ([[NSFileManager defaultManager]
                                   fileExistsAtPath:[NSString stringWithFormat:@"%@/shsh/%@.shsh",
                                                                               [[NSBundle mainBundle] resourcePath],
                                                                               [userDevice getCpid]]]) {
                        shshPath = [NSString stringWithFormat:@"%@/shsh/%@.shsh", [[NSBundle mainBundle] resourcePath],
                                                              [userDevice getCpid]];
                    } else {
                        shshPath =
                            [NSString stringWithFormat:@"%@/shsh/shsh.shsh", [[NSBundle mainBundle] resourcePath]];
                    }
                }
                if ([RamielView debugCheck])
                    NSLog(@"shshPath is set to: %@", shshPath);
                [RamielView
                    img4toolCMD:[NSString stringWithFormat:@"-c %@/ibss.img4 -p %@/RamielFiles/ibss.%@.patched -s %@",
                                                           [[NSBundle mainBundle] resourcePath],
                                                           [[NSBundle mainBundle] resourcePath], [userDevice getModel],
                                                           shshPath]];

                [RamielView
                    img4toolCMD:[NSString stringWithFormat:@"-c %@/ibec.img4 -p %@/RamielFiles/ibec.%@.patched -s %@",
                                                           [[NSBundle mainBundle] resourcePath],
                                                           [[NSBundle mainBundle] resourcePath], [userDevice getModel],
                                                           shshPath]];

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_bootProgBar incrementBy:16.66];
                    [self->_infoLabel setStringValue:@"Preparing Bootchain Files..."];
                });
                if ([[userIPSW getIosVersion] containsString:@"9."] ||
                    [[userIPSW getIosVersion] containsString:@"8."] ||
                    [[userIPSW getIosVersion] containsString:@"7."]) {
                    [RamielView
                        img4toolCMD:[NSString stringWithFormat:@"-e -o %@/RamielFiles/devicetree.raw --iv %@ "
                                                               @"--key %@ %@/RamielFiles/devicetree.im4p",
                                                               [[NSBundle mainBundle] resourcePath],
                                                               [userKeys getDevicetreeIV], [userKeys getDevicetreeKEY],
                                                               [[NSBundle mainBundle] resourcePath]]];
                    [RamielView img4toolCMD:[NSString stringWithFormat:@"-c %@/RamielFiles/devicetree.im4p -t "
                                                                       @"dtre %@/RamielFiles/devicetree.raw",
                                                                       [[NSBundle mainBundle] resourcePath],
                                                                       [[NSBundle mainBundle] resourcePath]]];
                }
                [RamielView img4toolCMD:[NSString stringWithFormat:@"-o %@/RamielFiles/devicetree.im4pp -n "
                                                                   @"rdtr %@/RamielFiles/devicetree.im4p",
                                                                   [[NSBundle mainBundle] resourcePath],
                                                                   [[NSBundle mainBundle] resourcePath]]];
                [RamielView img4toolCMD:[NSString stringWithFormat:@"-c %@/devicetree.img4 -p "
                                                                   @"%@/RamielFiles/devicetree.im4pp -s %@",
                                                                   [[NSBundle mainBundle] resourcePath],
                                                                   [[NSBundle mainBundle] resourcePath], shshPath]];

                if ([[NSFileManager defaultManager]
                        fileExistsAtPath:[NSString stringWithFormat:@"%@/RamielFiles/trustcache.im4p",
                                                                    [[NSBundle mainBundle] resourcePath]]]) {

                    [RamielView img4toolCMD:[NSString stringWithFormat:@"-o %@/RamielFiles/trustcache.im4pp -n "
                                                                       @"rtsc %@/RamielFiles/trustcache.im4p",
                                                                       [[NSBundle mainBundle] resourcePath],
                                                                       [[NSBundle mainBundle] resourcePath]]];
                    [RamielView img4toolCMD:[NSString stringWithFormat:@"-c %@/trustcache.img4 -p "
                                                                       @"%@/RamielFiles/trustcache.im4pp -s %@",
                                                                       [[NSBundle mainBundle] resourcePath],
                                                                       [[NSBundle mainBundle] resourcePath], shshPath]];
                }

                if ([[NSFileManager defaultManager]
                        fileExistsAtPath:[NSString stringWithFormat:@"%@/customLogo.ibootim",
                                                                    [[NSBundle mainBundle] resourcePath]]]) {

                    [RamielView
                        img4toolCMD:[NSString stringWithFormat:@"-c %@/RamielFiles/customLogo.im4p -t logo %@",
                                                               [[NSBundle mainBundle] resourcePath],
                                                               [NSString stringWithFormat:@"%@/customLogo.ibootim",
                                                                                          [[NSBundle mainBundle]
                                                                                              resourcePath]]]];
                    [RamielView img4toolCMD:[NSString stringWithFormat:@"-c %@/customLogo.img4 -p "
                                                                       @"%@/RamielFiles/customLogo.im4p -s %@",
                                                                       [[NSBundle mainBundle] resourcePath],
                                                                       [[NSBundle mainBundle] resourcePath], shshPath]];
                } else {
                    [RamielView img4toolCMD:[NSString stringWithFormat:@"-c %@/bootlogo.img4 -p "
                                                                       @"%@/bootlogo.im4p -s %@",
                                                                       [[NSBundle mainBundle] resourcePath],
                                                                       [[NSBundle mainBundle] resourcePath], shshPath]];
                }

                if ([[NSFileManager defaultManager]
                        fileExistsAtPath:[NSString stringWithFormat:@"%@/RamielFiles/callan.im4p",
                                                                    [[NSBundle mainBundle] resourcePath]]]) {
                    [RamielView
                        img4toolCMD:[NSString stringWithFormat:@"-c %@/callan.img4 -p %@/RamielFiles/callan.im4p -s %@",
                                                               [[NSBundle mainBundle] resourcePath],
                                                               [[NSBundle mainBundle] resourcePath], shshPath]];
                }
                if ([[NSFileManager defaultManager]
                        fileExistsAtPath:[NSString stringWithFormat:@"%@/RamielFiles/aop.im4p",
                                                                    [[NSBundle mainBundle] resourcePath]]]) {
                    [RamielView
                        img4toolCMD:[NSString stringWithFormat:@"-c %@/aop.img4 -p %@/RamielFiles/aop.im4p -s %@",
                                                               [[NSBundle mainBundle] resourcePath],
                                                               [[NSBundle mainBundle] resourcePath], shshPath]];
                }
                if ([[NSFileManager defaultManager]
                        fileExistsAtPath:[NSString stringWithFormat:@"%@/RamielFiles/isp.im4p",
                                                                    [[NSBundle mainBundle] resourcePath]]]) {
                    [RamielView
                        img4toolCMD:[NSString stringWithFormat:@"-c %@/isp.img4 -p %@/RamielFiles/isp.im4p -s %@",
                                                               [[NSBundle mainBundle] resourcePath],
                                                               [[NSBundle mainBundle] resourcePath], shshPath]];
                }
                if ([[NSFileManager defaultManager]
                        fileExistsAtPath:[NSString stringWithFormat:@"%@/RamielFiles/touch.im4p",
                                                                    [[NSBundle mainBundle] resourcePath]]]) {
                    [RamielView
                        img4toolCMD:[NSString stringWithFormat:@"-c %@/touch.img4 -p %@/RamielFiles/touch.im4p -s %@",
                                                               [[NSBundle mainBundle] resourcePath],
                                                               [[NSBundle mainBundle] resourcePath], shshPath]];
                }
                if ([[ramielPrefs objectForKey:@"amfi"] isEqual:@(1)]) {
                    if (!([[userIPSW getIosVersion] containsString:@"9."] ||
                          [[userIPSW getIosVersion] containsString:@"8."] ||
                          [[userIPSW getIosVersion] containsString:@"7."])) {
                        [self kernelAMFIPatches];
                    }
                } else {
                    if ([[userIPSW getIosVersion] containsString:@"9."] ||
                        [[userIPSW getIosVersion] containsString:@"8."] ||
                        [[userIPSW getIosVersion] containsString:@"7."]) {
                        [RamielView img4toolCMD:[NSString stringWithFormat:@"-e -s %@ -m %@/RamielFiles/IM4M", shshPath,
                                                                           [[NSBundle mainBundle] resourcePath]]];
                        [RamielView
                            otherCMD:[NSString
                                         stringWithFormat:@"/usr/local/bin/img4 -i %@/RamielFiles/kernel.im4p -o "
                                                          @"%@/kernel.img4 -k %@%@ -M %@/RamielFiles/IM4M -T rkrn -D",
                                                          [[NSBundle mainBundle] resourcePath],
                                                          [[NSBundle mainBundle] resourcePath], [userKeys getKernelIV],
                                                          [userKeys getKernelKEY],
                                                          [[NSBundle mainBundle] resourcePath]]];

                    } else {
                        [RamielView img4toolCMD:[NSString stringWithFormat:@"-o %@/RamielFiles/kernel.im4pp -n rkrn "
                                                                           @"%@/RamielFiles/kernel.im4p",
                                                                           [[NSBundle mainBundle] resourcePath],
                                                                           [[NSBundle mainBundle] resourcePath]]];
                        [RamielView
                            img4toolCMD:[NSString
                                            stringWithFormat:@"-c %@/kernel.img4 -p %@/RamielFiles/kernel.im4pp -s %@",
                                                             [[NSBundle mainBundle] resourcePath],
                                                             [[NSBundle mainBundle] resourcePath], shshPath]];
                    }
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_bootProgBar setHidden:TRUE];
                    [self->_bootProgBar incrementBy:-100.00];
                    [self->_infoLabel setStringValue:@"Press \"Boot Device\" to continue..."];
                    [self->_bootButton setHidden:FALSE];
                    [self->_bootButton setEnabled:TRUE];

                    [self bootDevice:NULL];
                });

            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [RamielView errorHandler:
                        @"IPSW is not valid for connected device":@"Please provide Ramiel with the correct IPSW"
                                                                 :@"N/A"];
                });
                [self refreshInfo:NULL];
            }
        } else {

            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_bootProgBar setHidden:TRUE];

                [self refreshInfo:NULL];
            });
        }
    });
}

- (void)prepareSSHBootChain {
    NSString *returnString = @"";
    while (![returnString containsString:@"failed"]) {
        returnString = [RamielView
            img4toolCMD:[NSString stringWithFormat:@"-e -o %@/RamielFiles/ibss.raw --iv %@ "
                                                   @"--key %@ %@/RamielFiles/ibss.im4p",
                                                   [[NSBundle mainBundle] resourcePath], [userKeys getIbssIV],
                                                   [userKeys getIbssKEY], [[NSBundle mainBundle] resourcePath]]];

        returnString = [RamielView
            img4toolCMD:[NSString stringWithFormat:@"-e -o %@/RamielFiles/ibec.raw --iv %@ "
                                                   @"--key %@ %@/RamielFiles/ibec.im4p",
                                                   [[NSBundle mainBundle] resourcePath], [userKeys getIbecIV],
                                                   [userKeys getIbecKEY], [[NSBundle mainBundle] resourcePath]]];

        const char *ibssPath =
            [[NSString stringWithFormat:@"%@/RamielFiles/ibss.raw", [[NSBundle mainBundle] resourcePath]] UTF8String];
        const char *ibssPwnPath =
            [[NSString stringWithFormat:@"%@/RamielFiles/ibss.pwn", [[NSBundle mainBundle] resourcePath]] UTF8String];
        const char *args = [@"rd=md0 debug=0x14e" UTF8String];

        int ret;
        sleep(1);
        ret = patchIBXX((char *)ibssPath, (char *)ibssPwnPath, (char *)args, 0);

        if (ret != 0) {
            dispatch_queue_t mainQueue = dispatch_get_main_queue();
            dispatch_sync(mainQueue, ^{
                [RamielView errorHandler:
                    @"Failed to patch iBSS":[NSString stringWithFormat:@"Kairos returned with: %i", ret]:@"N/A"];
                [self->_bootProgBar setHidden:TRUE];
                [self refreshInfo:NULL];
                return;
            });
        } else {
            const char *ibecPath = [[NSString
                stringWithFormat:@"%@/RamielFiles/ibec.raw", [[NSBundle mainBundle] resourcePath]] UTF8String];
            const char *ibecPwnPath = [[NSString
                stringWithFormat:@"%@/RamielFiles/ibec.pwn", [[NSBundle mainBundle] resourcePath]] UTF8String];
            ret = patchIBXX((char *)ibecPath, (char *)ibecPwnPath, (char *)args, 0);

            if (ret != 0) {
                dispatch_queue_t mainQueue = dispatch_get_main_queue();
                dispatch_sync(mainQueue, ^{
                    [RamielView errorHandler:
                        @"Failed to patch iBEC":[NSString stringWithFormat:@"Kairos returned with: %i", ret]:@"N/A"];
                    [self->_bootProgBar setHidden:TRUE];
                    [self refreshInfo:NULL];
                    return;
                });
            }
        }

        returnString = [RamielView
            img4toolCMD:[NSString stringWithFormat:@"-c %@/RamielFiles/ibss.%@.patched -t ibss "
                                                   @"%@/RamielFiles/ibss.pwn",
                                                   [[NSBundle mainBundle] resourcePath], [userDevice getModel],
                                                   [[NSBundle mainBundle] resourcePath]]];

        returnString = [RamielView
            img4toolCMD:[NSString stringWithFormat:@"-c %@/RamielFiles/ibec.%@.patched -t ibec "
                                                   @"%@/RamielFiles/ibec.pwn",
                                                   [[NSBundle mainBundle] resourcePath], [userDevice getModel],
                                                   [[NSBundle mainBundle] resourcePath]]];
        NSMutableDictionary *ramielPrefs = [NSMutableDictionary
            dictionaryWithDictionary:
                [NSDictionary
                    dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                            [[NSBundle mainBundle] resourcePath]]]];
        if (![[ramielPrefs objectForKey:@"customSHSHPath"] containsString:@"N/A"]) {
            if ([RamielView debugCheck])
                NSLog(@"Using user-provided SHSH from: %@", [ramielPrefs objectForKey:@"customSHSHPath"]);
            shshPath = [ramielPrefs objectForKey:@"customSHSHPath"];
        } else if ([[NSFileManager defaultManager]
                       fileExistsAtPath:[NSString stringWithFormat:@"%@/shsh/%@.shsh",
                                                                   [[NSBundle mainBundle] resourcePath],
                                                                   [userDevice getCpid]]]) {
            shshPath = [NSString
                stringWithFormat:@"%@/shsh/%@.shsh", [[NSBundle mainBundle] resourcePath], [userDevice getCpid]];
        } else {
            shshPath = [NSString stringWithFormat:@"%@/shsh/shsh.shsh", [[NSBundle mainBundle] resourcePath]];
        }

        returnString = [RamielView
            img4toolCMD:[NSString stringWithFormat:@"-c %@/ibss.img4 -p %@/RamielFiles/ibss.%@.patched -s %@",
                                                   [[NSBundle mainBundle] resourcePath],
                                                   [[NSBundle mainBundle] resourcePath], [userDevice getModel],
                                                   shshPath]];

        returnString = [RamielView
            img4toolCMD:[NSString stringWithFormat:@"-c %@/ibec.img4 -p %@/RamielFiles/ibec.%@.patched -s %@",
                                                   [[NSBundle mainBundle] resourcePath],
                                                   [[NSBundle mainBundle] resourcePath], [userDevice getModel],
                                                   shshPath]];

        returnString =
            [RamielView img4toolCMD:[NSString stringWithFormat:@"-c %@/sshLogo.img4 -p %@/ssh/sshLogo.im4p -s %@",
                                                               [[NSBundle mainBundle] resourcePath],
                                                               [[NSBundle mainBundle] resourcePath], shshPath]];

        returnString = [RamielView img4toolCMD:[NSString stringWithFormat:@"-o %@/RamielFiles/devicetree.im4pp -n "
                                                                          @"rdtr %@/RamielFiles/devicetree.im4p",
                                                                          [[NSBundle mainBundle] resourcePath],
                                                                          [[NSBundle mainBundle] resourcePath]]];
        returnString =
            [RamielView img4toolCMD:[NSString stringWithFormat:@"-c %@/devicetree.img4 -p "
                                                               @"%@/RamielFiles/devicetree.im4pp -s %@",
                                                               [[NSBundle mainBundle] resourcePath],
                                                               [[NSBundle mainBundle] resourcePath], shshPath]];

        if ([[NSFileManager defaultManager]
                fileExistsAtPath:[NSString stringWithFormat:@"%@/RamielFiles/trustcache.im4p",
                                                            [[NSBundle mainBundle] resourcePath]]]) {

            returnString = [RamielView img4toolCMD:[NSString stringWithFormat:@"-o %@/RamielFiles/trustcache.im4pp -n "
                                                                              @"rtsc %@/RamielFiles/trustcache.im4p",
                                                                              [[NSBundle mainBundle] resourcePath],
                                                                              [[NSBundle mainBundle] resourcePath]]];
            returnString =
                [RamielView img4toolCMD:[NSString stringWithFormat:@"-c %@/trustcache.img4 -p "
                                                                   @"%@/RamielFiles/trustcache.im4pp -s %@",
                                                                   [[NSBundle mainBundle] resourcePath],
                                                                   [[NSBundle mainBundle] resourcePath], shshPath]];
        }
        break;
    }

    if ([returnString containsString:@"failed"]) {
        [RamielView errorHandler:
            @"Failed to create SSH ramdisk files.":[NSString
                                                       stringWithFormat:@"img4tool failed with output: %@", returnString
        ]:returnString];
        [self refreshInfo:NULL];
        return;
    }

    [self kernelAMFIPatches];
}
- (IBAction)downloadIPSW:(NSButton *)sender {

    [self->_dlIPSWButton setEnabled:FALSE];
    [self->_dlIPSWButton setHidden:TRUE];
    [self->_selIPSWButton setEnabled:FALSE];
    [self->_selIPSWButton setHidden:TRUE];
    stopBackground = 1;

    [self->_infoLabel setStringValue:@"Please pick an iOS version to download..."];

    [self->_bootButton setEnabled:FALSE];
    [self->_bootProgBar setHidden:TRUE];
    [self->_settingsButton setHidden:TRUE];
    [self->_settingsButton setEnabled:FALSE];

    NSURLRequest *request =
        [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://api.ipsw.me/v4/"
                                                                                     @"device/%@?type=ipsw",
                                                                                     [userDevice getModel]]]];
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    NSError *jsonError;
    NSDictionary *parsedThing = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    NSMutableArray *firmwaresToPickFrom = [[NSMutableArray alloc] init];
    ;
    if (parsedThing == nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [RamielView errorHandler:
                @"Failed to get list of iOS versions":@"Please ensure you have an internet connection"
                                                     :[NSString stringWithFormat:@"%@", data]];
        });
    } else {
        NSArray *firmwares = parsedThing[@"firmwares"];
        int dictSize = (int)firmwares.count;
        for (int i = 0; i < dictSize; i++) {
            [firmwaresToPickFrom addObject:(NSString *)[NSString stringWithFormat:@"%@", firmwares[i][@"version"]]];
        }
    }

    NSArray *listVersions = [[NSOrderedSet orderedSetWithArray:firmwaresToPickFrom] array];
    for (int i = 0; i < [listVersions count]; ++i) {
        [self->_comboBoxList addItemWithObjectValue:[listVersions objectAtIndex:i]];
    }
    [self->_comboBoxList setHidden:FALSE];
    [self->_comboBoxList setEnabled:TRUE];
    [self->_dlButton setHidden:FALSE];
    [self->_dlButton setEnabled:TRUE];
}

- (IBAction)senderdownloadStage2:(NSButton *)sender {

    [self->_dlButton setHidden:TRUE];
    [self->_comboBoxList setHidden:TRUE];
    [self->_dlButton setEnabled:FALSE];
    [self->_comboBoxList setEnabled:FALSE];
    [self->_bootProgBar setHidden:FALSE];

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES);
    [userIPSW setIpswPath:paths[0]];
    [userIPSW setIosVersion:self->_comboBoxList.objectValueOfSelectedItem];

    [self->_comboBoxList removeAllItems];

    if ([[NSFileManager defaultManager]
            fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.%@.ipsw", [userIPSW getIpswPath],
                                                        [userIPSW getIosVersion], [userDevice getModel]]]) {

        [userIPSW setIpswPath:[NSString stringWithFormat:@"%@/%@.%@.ipsw", [userIPSW getIpswPath],
                                                         [userIPSW getIosVersion], [userDevice getModel]]];

        [self loadIPSW:NULL:NULL];

    } else {

        [self->_infoLabel setStringValue:@"Getting IPSW download link..."];

        NSURL *ipswDownloadURL =
            [NSURL URLWithString:[NSString stringWithFormat:@"https://api.ipsw.me/v2.1/%@/%@/url",
                                                            [userDevice getModel], [userIPSW getIosVersion]]];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSURLRequest *request = [NSURLRequest requestWithURL:ipswDownloadURL];
            NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];

            NSString *dataString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];

            if ([dataString isEqualToString:@"\n"]) {

                dispatch_async(dispatch_get_main_queue(), ^{
                    [RamielView errorHandler:@"Invalid input":@"":@"N/A"];

                    [self->_bootProgBar setHidden:TRUE];

                    [self refreshInfo:NULL];

                    return;
                });
            } else {

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_infoLabel setStringValue:@"Downloading IPSW..."];
                    [self->_bootProgBar setHidden:FALSE];
                    [self->_downloadLabel setHidden:FALSE];
                });

                NSURL *url = [NSURL URLWithString:dataString];
                NSURLRequest *request = [NSURLRequest requestWithURL:url];
                AFURLConnectionOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];

                NSString *filePath = [NSString stringWithFormat:@"%@/%@.%@.ipsw", [userIPSW getIpswPath],
                                                                [userIPSW getIosVersion], [userDevice getModel]];
                operation.outputStream = [NSOutputStream outputStreamToFileAtPath:filePath append:NO];

                [operation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead,
                                                      long long totalBytesExpectedToRead) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self->_downloadLabel
                            setStringValue:[NSString
                                               stringWithFormat:@"%.0f MB / %lld MB... ",
                                                                (([self->_bootProgBar doubleValue] / 1024) / 1024),
                                                                ((totalBytesExpectedToRead / 1024) / 1024)]];
                        [self->_bootProgBar setMaxValue:(double)totalBytesExpectedToRead];
                        [self->_bootProgBar incrementBy:(double)bytesRead];
                    });
                }];

                [operation setCompletionBlock:^{
                    if ([operation error] != NULL) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [RamielView errorHandler:
                                @"IPSW download failed":[NSString
                                                            stringWithFormat:@"Failure reason: %@",
                                                                             [operation error]
                                                                                 .userInfo[@"NSLocalizedDescription"]
                            ]:(NSString *)[operation error]];
                            [self->_downloadLabel setHidden:TRUE];
                            [self->_downloadLabel setStringValue:@""];
                            [self refreshInfo:NULL];
                        });
                        return;
                    }
                    NSLog(@"Download Complete!");
                    [self->_bootProgBar setMaxValue:100.00];
                    [self->_bootProgBar incrementBy:([self->_bootProgBar doubleValue] * -1)];

                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self->_downloadLabel setHidden:TRUE];

                        [userIPSW
                            setIpswPath:[NSString stringWithFormat:@"%@/%@.%@.ipsw", [userIPSW getIpswPath],
                                                                   [userIPSW getIosVersion], [userDevice getModel]]];

                        [self loadIPSW:NULL:NULL];
                    });
                }];
                [operation start];
                return;
            }
        });
    }
}

- (int)kernelAMFIPatches {
    int ret = 0;
    NSString *returnString = @"";
    while (![returnString containsString:@"failed"]) {
        returnString = [RamielView img4toolCMD:[NSString stringWithFormat:@"-e -o %@/RamielFiles/kernel.raw "
                                                                          @"%@/RamielFiles/kernel.im4p",
                                                                          [[NSBundle mainBundle] resourcePath],
                                                                          [[NSBundle mainBundle] resourcePath]]];
        NSString *kernel64patcher = [[NSString alloc] init];
        if ([[userDevice getCpid] containsString:@"8015"]) {
            kernel64patcher = @"Kernel64PatcherB";
            [RamielView otherCMD:[NSString stringWithFormat:@"%@/ssh/%@ %@/RamielFiles/kernel.raw "
                                                            @"%@/RamielFiles/kernel.pwn -a",
                                                            [[NSBundle mainBundle] resourcePath], kernel64patcher,
                                                            [[NSBundle mainBundle] resourcePath],
                                                            [[NSBundle mainBundle] resourcePath]]];
        } else {
            kernel64patcher = @"Kernel64Patcher";
            [RamielView otherCMD:[NSString stringWithFormat:@"%@/ssh/%@ %@/RamielFiles/kernel.raw "
                                                            @"%@/RamielFiles/kernel.pwn -a",
                                                            [[NSBundle mainBundle] resourcePath], kernel64patcher,
                                                            [[NSBundle mainBundle] resourcePath],
                                                            [[NSBundle mainBundle] resourcePath]]];
        }
        NSMutableDictionary *ramielPrefs = [NSMutableDictionary
            dictionaryWithDictionary:
                [NSDictionary
                    dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                            [[NSBundle mainBundle] resourcePath]]]];
        if ([[ramielPrefs objectForKey:@"amsd"] isEqual:@(1)]) {
            [RamielView otherCMD:[NSString stringWithFormat:@"%@/ssh/Kernel64PatcherA %@/RamielFiles/kernel.pwn "
                                                            @"%@/RamielFiles/kernel.pwn2 -s",
                                                            [[NSBundle mainBundle] resourcePath],
                                                            [[NSBundle mainBundle] resourcePath],
                                                            [[NSBundle mainBundle] resourcePath]]];
            [[NSFileManager defaultManager]
                removeItemAtPath:[NSString stringWithFormat:@"%@/RamielFiles/kernel.pwn",
                                                            [[NSBundle mainBundle] resourcePath]]
                           error:nil];
            [[NSFileManager defaultManager]
                moveItemAtPath:[NSString
                                   stringWithFormat:@"%@/RamielFiles/kernel.pwn2", [[NSBundle mainBundle] resourcePath]]
                        toPath:[NSString
                                   stringWithFormat:@"%@/RamielFiles/kernel.pwn", [[NSBundle mainBundle] resourcePath]]
                         error:nil];
        }
        returnString = [RamielView img4toolCMD:[NSString stringWithFormat:@"-e -s %@ -m %@/RamielFiles/IM4M", shshPath,
                                                                          [[NSBundle mainBundle] resourcePath]]];
        NSString *prefix;
        if (@available(macOS 11.0, *)) {
            prefix = @"/usr/bin";
        } else {
            prefix = @"/usr/local/bin";
        }
        [RamielView otherCMD:[NSString stringWithFormat:@"%@/python3 %@/ssh/compare.py "
                                                        @"%@/RamielFiles/kernel.raw %@/RamielFiles/kernel.pwn",
                                                        prefix, [[NSBundle mainBundle] resourcePath],
                                                        [[NSBundle mainBundle] resourcePath],
                                                        [[NSBundle mainBundle] resourcePath]]];
        [[NSFileManager defaultManager]
            moveItemAtPath:@"/tmp/kc.bpatch"
                    toPath:[NSString stringWithFormat:@"%@/kc.bpatch", [[NSBundle mainBundle] resourcePath]]
                     error:nil];
        NSString *img4ReturnString = [RamielView
            otherCMD:[NSString
                         stringWithFormat:@"/usr/local/bin/img4 -i %@/RamielFiles/kernel.im4p -o "
                                          @"%@/kernel.img4 -M %@/RamielFiles/IM4M -T rkrn -P %@/kc.bpatch -J",
                                          [[NSBundle mainBundle] resourcePath], [[NSBundle mainBundle] resourcePath],
                                          [[NSBundle mainBundle] resourcePath], [[NSBundle mainBundle] resourcePath]]];
        if ([img4ReturnString containsString:@"apply"]) {
            [RamielView errorHandler:
                @"Failed to patch kernel.":[NSString stringWithFormat:@"img4 failed with output: %@", img4ReturnString
            ]:img4ReturnString];
            [self refreshInfo:NULL];
            return 1;
        }

        return ret;
    }
    [RamielView errorHandler:
        @"Failed to create SSH ramdisk files.":[NSString
                                                   stringWithFormat:@"img4tool failed with output: %@", returnString
    ]:returnString];
    [self refreshInfo:NULL];
    return 1;
}

+ (int)debugCheck {
    if ([[[NSMutableDictionary
            dictionaryWithDictionary:
                [NSDictionary
                    dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                            [[NSBundle mainBundle] resourcePath]]]]
            objectForKey:@"debug"] isEqual:@(0)]) {
        return 0;
    } else {
        return 1;
    }
}
- (int)downloadiBSS {

    NSURL *IPSWURL = [NSURL
        URLWithString:[NSString stringWithFormat:@"https://api.ipsw.me/v2.1/%@/12.4/url", [userDevice getModel]]];
    NSURLRequest *request = [NSURLRequest requestWithURL:IPSWURL];
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    NSString *dataString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    NSString *outPath = [NSString stringWithFormat:@"%@/RamielFiles/ibss.im4p", [[NSBundle mainBundle] resourcePath]];
    NSString *outPathManifest =
        [NSString stringWithFormat:@"%@/RamielFiles/ios12Manifest.plist", [[NSBundle mainBundle] resourcePath]];

    [RamielView downloadFileFromIPSW:dataString:@"BuildManifest.plist":outPathManifest];
    NSDictionary *manifestData = [NSDictionary dictionaryWithContentsOfFile:outPathManifest];
    if (manifestData == NULL) {
        return 1;
    }
    NSString *path;
    NSArray *buildID = [manifestData objectForKey:@"BuildIdentities"];
    for (int i = 0; i < [buildID count]; i++) {

        if ([buildID[i][@"ApChipID"] isEqual:[userDevice getCpid]]) {

            if ([buildID[i][@"Info"][@"DeviceClass"] isEqual:[userDevice getHardware_model]]) {

                path = buildID[i][@"Manifest"][@"iBSS"][@"Info"][@"Path"];
            }
        }
    }
    [RamielView downloadFileFromIPSW:dataString:path:outPath];
    FirmwareKeys *ios12Keys = [[FirmwareKeys alloc] initFirmwareKeysID];
    IPSW *ios12IPSW = [[IPSW alloc] initIPSWID];
    [ios12IPSW setIosVersion:[manifestData objectForKey:@"ProductVersion"]];
    [ios12Keys fetchKeysFromWiki:userDevice:ios12IPSW:manifestData];
    [RamielView img4toolCMD:[NSString stringWithFormat:@"-e -o %@/RamielFiles/ibss.raw --iv %@ "
                                                       @"--key %@ %@/RamielFiles/ibss.im4p",
                                                       [[NSBundle mainBundle] resourcePath], [ios12Keys getIbssIV],
                                                       [ios12Keys getIbssKEY], [[NSBundle mainBundle] resourcePath]]];
    return 0;
}
+ (int)downloadFileFromIPSW:(NSString *)url:(NSString *)path:(NSString *)outpath {
    return partialzip_download_file([url UTF8String], [path UTF8String], [outpath UTF8String]);
}
+ (irecv_client_t)getClientExternal {
    return [userDevice getIRECVClient];
}
+ (IPSW *)getIpswInfoExternal {
    return userIPSW;
}
+ (Device *)getConnectedDeviceInfo {
    return userDevice;
}
+ (void)stopBackground {
    if ([RamielView debugCheck])
        NSLog(@"Background checker stopped.");
    stopBackground = 1;
}
+ (void)startBackground {
    if ([RamielView debugCheck])
        NSLog(@"Background checker started.");
    stopBackground = 0;
}

+ (void)errorHandler:(NSString *)errorMessage:(NSString *)errorTitle:(NSString *)detailedMessage {
    NSAlert *errorAlert = [[NSAlert alloc] init];
    [errorAlert setMessageText:[NSString stringWithFormat:@"ERROR: %@", errorMessage]];
    [errorAlert setInformativeText:[NSString stringWithFormat:@"%@", errorTitle]];
    [errorAlert addButtonWithTitle:@"OK"];
    [errorAlert addButtonWithTitle:@"Save Detailed Log To File"];
    errorAlert.window.titlebarAppearsTransparent = true;
    NSModalResponse choice = [errorAlert runModal];
    if (choice != NSAlertFirstButtonReturn) {
        NSDate *today = [NSDate date];
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
        NSString *currentTime = [dateFormatter stringFromDate:today];
        currentTime = [currentTime stringByReplacingOccurrencesOfString:@":" withString:@"."];
        currentTime = [currentTime stringByReplacingOccurrencesOfString:@" " withString:@"."];
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString *fileName = [NSString
            stringWithFormat:@"%@/Ramiel/Error_Logs/Ramiel_Error_Log_%@.txt", documentsDirectory, currentTime];
        if (![[NSFileManager defaultManager]
                fileExistsAtPath:[NSString stringWithFormat:@"%@/Ramiel/Error_Logs/", documentsDirectory]
                     isDirectory:(BOOL * _Nullable) TRUE]) {
            [[NSFileManager defaultManager]
                      createDirectoryAtPath:[NSString stringWithFormat:@"%@/Ramiel/Error_Logs/", documentsDirectory]
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:nil];
        }
        detailedMessage = [NSString stringWithFormat:@"Device Information:\n\nModel: %@\niOS Version: "
                                                     @"%@\nBootargs: \"%@\"\n\nOther Error "
                                                     @"Information:\n\n%@\n%@\n\nDetailed Error Log:\n\n%@",
                                                     [userDevice getHardware_model], [userIPSW getIosVersion],
                                                     [userIPSW getBootargs], errorTitle, errorMessage, detailedMessage];
        [detailedMessage writeToFile:fileName atomically:NO encoding:NSStringEncodingConversionAllowLossy error:nil];
        NSAlert *errorAlert = [[NSAlert alloc] init];
        [errorAlert setMessageText:[NSString stringWithFormat:@"Saved error log to: %@", fileName]];
        [errorAlert setInformativeText:@"If you open an issue on GitHub, please upload this file with your "
                                       @"issue, as it will assit me in figuring out what is wrong"];
        [errorAlert addButtonWithTitle:@"OK"];
        [errorAlert addButtonWithTitle:@"Open GitHub Issues Page"];
        errorAlert.window.titlebarAppearsTransparent = true;
        NSModalResponse choice = [errorAlert runModal];
        if (choice != NSAlertFirstButtonReturn) {
            NSURL *url = [[NSURL alloc]
                initWithString:@"https://github.com/MatthewPierson/Ramiel/issues/"
                               @"new?assignees=&labels=bug%2C+help+wanted&template=bug_report.md&title=%5BBug%5D"];
            [[NSWorkspace sharedWorkspace] openURL:url];
        }
    }
    return;
}

@end
