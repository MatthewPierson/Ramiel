//
//  SettingsView.m
//  Ramiel
//
//  Created by Matthew Pierson on 5/09/20.
//  Copyright © 2020 moski. All rights reserved.
//

#import "SettingsView.h"
#include "../ibootim/ibootimMain.h"
#import "RamielView.h"
#import "FirmwareKeys.h"
#include "libirecovery.h"

@implementation SettingsView

- (void)viewDidLoad {
    [super viewDidLoad];

    self.preferredContentSize =
        NSMakeSize(self.view.frame.size.width,
                   self.view.frame.size.height); // Ensure that the setting sheet can't be resized
    NSMutableDictionary *ramielPrefs = [NSMutableDictionary
        dictionaryWithDictionary:[NSDictionary dictionaryWithContentsOfFile:
                                                   [NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                              [[NSBundle mainBundle] resourcePath]]]];

    if ([[ramielPrefs objectForKey:@"skipVerification"] isEqual:@(0)]) {
        [self->_ignoreIPSWVerification setState:NSControlStateValueOff];
    } else {
        [self->_ignoreIPSWVerification setState:NSControlStateValueOn];
    }
    if ([[ramielPrefs objectForKey:@"debug"] isEqual:@(0)]) {
        [self->_toggleDebugMode setState:NSControlStateValueOff];
    } else {
        [self->_toggleDebugMode setState:NSControlStateValueOn];
    }

    if ([[ramielPrefs objectForKey:@"amfi"] isEqual:@(0)]) {
        [self->_amfiToggle setState:NSControlStateValueOff];
    } else {
        [self->_amfiToggle setState:NSControlStateValueOn];
    }
    if ([[ramielPrefs objectForKey:@"amsd"] isEqual:@(0)]) {
        [self->_amsdToggle setState:NSControlStateValueOff];
    } else {
        [self->_amsdToggle setState:NSControlStateValueOn];
    }
    if ([[ramielPrefs objectForKey:@"dualbootDiskNum"] isEqual:@(0)]) {
        [self->_dualbootCheck setState:NSControlStateValueOff];
        [self->_dualbootButton setEnabled:FALSE];
    } else {
        [self->_dualbootCheck setState:NSControlStateValueOn];
        [self->_dualbootButton setEnabled:TRUE];
    }

    if ([[ramielPrefs objectForKey:@"customBootArgs"] isEqualToString:@"-v"]) {
        [self->_bootargsCheck setState:NSControlStateValueOff];
        [self->_bootargsButton setEnabled:FALSE];
    } else {
        [self->_bootargsCheck setState:NSControlStateValueOn];
        [self->_bootargsButton setEnabled:TRUE];
    }

    if ([[ramielPrefs objectForKey:@"customLogo"] isEqual:@(0)]) {
        [self->_bootlogoCheck setState:NSControlStateValueOff];
        [self->_bootlogoButton setEnabled:FALSE];
    } else {
        [self->_bootlogoCheck setState:NSControlStateValueOn];
        [self->_bootlogoButton setEnabled:TRUE];
    }

    [RamielView stopBackground];

    int ret, mode;
    ret = irecv_get_mode([[RamielView getConnectedDeviceInfo] getIRECVClient], &mode);
    if (ret == IRECV_E_SUCCESS) {
        if (mode != IRECV_K_DFU_MODE) {
            // If device is in recovery mode we only need to enable the SHSH download button and the exit recovery mode
            // button
            [self->_exitRecMode setEnabled:TRUE];
            [self->_backupFirmwareKeysButton setEnabled:TRUE];
            [self->_dumpSHSH setEnabled:FALSE];
            [self->_amfiToggle setEnabled:FALSE];
            [self->_amsdToggle setEnabled:FALSE];
            [self->_apnonceButton setEnabled:FALSE];
            [self->_bootargsCheck setEnabled:FALSE];
            [self->_dualbootButton setEnabled:FALSE];
            [self->_bootargsButton setEnabled:FALSE];
            [self->_toggleDebugMode setEnabled:FALSE];
            [self->_ignoreIPSWVerification setEnabled:FALSE];
            [self->_dualbootCheck setEnabled:FALSE];
            [self->_bootlogoCheck setEnabled:FALSE];
        } else {
            // If device is in DFU mode we don't need the exit recovery mode button to be useable
            [self->_exitRecMode setEnabled:FALSE];
        }
    }
}

- (void)setRepresentedObject:(id)representedObject {

    [super setRepresentedObject:representedObject];
}

- (IBAction)bootargToggle:(NSButton *)sender {
    if ([self->_bootargsCheck state] == 1) {
        [self->_bootargsButton setEnabled:TRUE];
    } else {
        [self->_bootargsButton setEnabled:FALSE];
    }
}

- (IBAction)bootlogoToggle:(NSButton *)sender {
    if ([self->_bootlogoCheck state] == 1) {
        [self->_bootlogoButton setEnabled:TRUE];
    } else {
        [self->_bootlogoButton setEnabled:FALSE];
    }
}

- (IBAction)backUpAllFirmwareKeys:(NSButton *)sender {
    FirmwareKeys *keys = [[FirmwareKeys alloc] initFirmwareKeysID];
    [keys backupAllKeysForModel:[RamielView getConnectedDeviceInfo]];
}

- (IBAction)verificationToggle:(NSButton *)sender {
    NSMutableDictionary *ramielPrefs = [NSMutableDictionary
        dictionaryWithDictionary:[NSDictionary dictionaryWithContentsOfFile:
                                                   [NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                              [[NSBundle mainBundle] resourcePath]]]];
    if ([self->_ignoreIPSWVerification state] == 1) {

        NSAlert *warn = [[NSAlert alloc] init];
        [warn setMessageText:@"Warning: Enabling this option may introduce instability"];
        [warn setInformativeText:@"Only enable this if you know what you're doing"];
        warn.window.titlebarAppearsTransparent = true;
        [warn runModal];

        [ramielPrefs setObject:@(1) forKey:@"skipVerification"];
        [[NSFileManager defaultManager]
            removeItemAtPath:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                        [[NSBundle mainBundle] resourcePath]]
                       error:nil];
        [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                            [[NSBundle mainBundle] resourcePath]]
                      atomically:TRUE];
    } else {
        [ramielPrefs setObject:@(0) forKey:@"skipVerification"];
        [[NSFileManager defaultManager]
            removeItemAtPath:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                        [[NSBundle mainBundle] resourcePath]]
                       error:nil];
        [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                            [[NSBundle mainBundle] resourcePath]]
                      atomically:TRUE];
    }
}

- (IBAction)dualbootToggle:(NSButton *)sender {
    NSMutableDictionary *ramielPrefs = [NSMutableDictionary
        dictionaryWithDictionary:[NSDictionary dictionaryWithContentsOfFile:
                                                   [NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                              [[NSBundle mainBundle] resourcePath]]]];
    if ([self->_dualbootCheck state] == 1) {
        [self->_dualbootButton setEnabled:TRUE];
    } else {
        [self->_dualbootButton setEnabled:FALSE];
        [ramielPrefs setObject:@(0) forKey:@"dualbootDiskNum"];
        [[NSFileManager defaultManager]
            removeItemAtPath:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                        [[NSBundle mainBundle] resourcePath]]
                       error:nil];
        [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                            [[NSBundle mainBundle] resourcePath]]
                      atomically:TRUE];
    }
}

- (IBAction)bootargsButton:(NSButton *)sender {

    NSMutableDictionary *ramielPrefs = [NSMutableDictionary
        dictionaryWithDictionary:[NSDictionary dictionaryWithContentsOfFile:
                                                   [NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                              [[NSBundle mainBundle] resourcePath]]]];

    NSTextField *bootargField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 25)];
    bootargField.cell.sendsActionOnEndEditing = NO;
    bootargField.placeholderString = [ramielPrefs objectForKey:@"customBootArgs"];

    NSStackView *stack = [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, 200, 25)];
    [stack addSubview:bootargField];

    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    alert.window.titlebarAppearsTransparent = true;
    [alert setMessageText:@"Please enter desiered bootargs, then press enter "
                          @"(Defaults to \"-v\")\n\nNote that this is for "
                          @"ADVANCED users only, you've been warned"];
    alert.accessoryView = stack;
    [[alert window] setInitialFirstResponder:bootargField];
    [alert runModal];
    if ([bootargField.stringValue isEqualToString:@""]) {
        [ramielPrefs setObject:@"-v" forKey:@"customBootArgs"];
        [[NSFileManager defaultManager]
            removeItemAtPath:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                        [[NSBundle mainBundle] resourcePath]]
                       error:nil];
        [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                            [[NSBundle mainBundle] resourcePath]]
                      atomically:TRUE];
    } else {
        [ramielPrefs setObject:bootargField.stringValue forKey:@"customBootArgs"];
        [[NSFileManager defaultManager]
            removeItemAtPath:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                        [[NSBundle mainBundle] resourcePath]]
                       error:nil];
        [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                            [[NSBundle mainBundle] resourcePath]]
                      atomically:TRUE];
    }
}

- (IBAction)bootLogoButton:(NSButton *)sender {

    NSMutableDictionary *ramielPrefs = [NSMutableDictionary
        dictionaryWithDictionary:[NSDictionary dictionaryWithContentsOfFile:
                                                   [NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                              [[NSBundle mainBundle] resourcePath]]]];

    NSOpenPanel *openDlg = [NSOpenPanel openPanel];
    openDlg.canChooseFiles = TRUE;
    openDlg.canChooseDirectories = FALSE;
    openDlg.allowsMultipleSelection = FALSE;
    openDlg.allowedFileTypes = [NSArray arrayWithObject:@"png"];
    openDlg.canCreateDirectories = FALSE;

    if ([openDlg runModal] == NSModalResponseOK) {

        NSString *customLogoPath = openDlg.URL.path;

        [[NSFileManager defaultManager]
            removeItemAtPath:[NSString stringWithFormat:@"%@/customLogo.ibootim", [[NSBundle mainBundle] resourcePath]]
                       error:nil];

        ibootimMain(
            [customLogoPath UTF8String],
            [[NSString stringWithFormat:@"%@/customLogo.ibootim", [[NSBundle mainBundle] resourcePath]] UTF8String]);

        if ([[NSFileManager defaultManager]
                fileExistsAtPath:[NSString stringWithFormat:@"%@/customLogo.ibootim",
                                                            [[NSBundle mainBundle] resourcePath]]]) {

            NSAlert *alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:@"OK"];
            alert.window.titlebarAppearsTransparent = true;
            [alert setMessageText:@"Successfully created custom bootlogo! Custom "
                                  @"bootlogo will be used on next boot"];
            [alert runModal];

            [ramielPrefs setObject:@(1) forKey:@"customLogo"];
            [[NSFileManager defaultManager]
                removeItemAtPath:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                            [[NSBundle mainBundle] resourcePath]]
                           error:nil];
            [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                [[NSBundle mainBundle] resourcePath]]
                          atomically:TRUE];

        } else {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:@"OK"];
            alert.window.titlebarAppearsTransparent = true;
            [alert setMessageText:@"Failed to create custom bootlogo, please try again or "
                                  @"pick a different image if the issue persists"];
            [alert runModal];

            [ramielPrefs setObject:@(0) forKey:@"customLogo"];
            [[NSFileManager defaultManager]
                removeItemAtPath:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                            [[NSBundle mainBundle] resourcePath]]
                           error:nil];
            [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                [[NSBundle mainBundle] resourcePath]]
                          atomically:TRUE];
        }
    }
}

- (IBAction)dualbootButton:(NSButton *)sender {

    NSMutableDictionary *ramielPrefs = [NSMutableDictionary
        dictionaryWithDictionary:[NSDictionary dictionaryWithContentsOfFile:
                                                   [NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                              [[NSBundle mainBundle] resourcePath]]]];

    NSTextField *dualbootField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 25)];
    dualbootField.cell.sendsActionOnEndEditing = NO;
    dualbootField.placeholderString = [ramielPrefs objectForKey:@"dualbootDiskNum"];

    NSStackView *stack = [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, 200, 25)];
    [stack addSubview:dualbootField];

    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    alert.window.titlebarAppearsTransparent = true;
    [alert setMessageText:@"Please enter the disk identifier for your second OS "
                          @"(E.G disk0s1s5 = 5)"];
    alert.accessoryView = stack;
    [[alert window] setInitialFirstResponder:dualbootField];
    [alert runModal];

    NSMutableCharacterSet *digitsAndDots = [NSMutableCharacterSet decimalDigitCharacterSet];
    NSCharacterSet *notDigitsNorDots = [digitsAndDots invertedSet];

    if (!([dualbootField.stringValue rangeOfCharacterFromSet:notDigitsNorDots].location == NSNotFound) ||
        [dualbootField.stringValue isEqualToString:@""]) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        alert.window.titlebarAppearsTransparent = true;
        [alert setMessageText:@"Invalid input, not continuing..."];
        [alert runModal];
        [ramielPrefs setObject:@(0) forKey:@"dualbootDiskNum"];
        [[NSFileManager defaultManager]
            removeItemAtPath:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                        [[NSBundle mainBundle] resourcePath]]
                       error:nil];
        [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                            [[NSBundle mainBundle] resourcePath]]
                      atomically:TRUE];
    } else {

        const char *utf8String1 = [dualbootField.stringValue UTF8String];
        int convertInt = (int)(strtol(utf8String1, NULL, 0) + 47);

        [ramielPrefs setObject:@(convertInt) forKey:@"bootpartitionPatch"];
        [[NSFileManager defaultManager]
            removeItemAtPath:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                        [[NSBundle mainBundle] resourcePath]]
                       error:nil];
        [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                            [[NSBundle mainBundle] resourcePath]]
                      atomically:TRUE];

        int save = dualbootField.stringValue.intValue;
        [ramielPrefs setObject:@(save) forKey:@"dualbootDiskNum"];
        [[NSFileManager defaultManager]
            removeItemAtPath:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                        [[NSBundle mainBundle] resourcePath]]
                       error:nil];
        [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                            [[NSBundle mainBundle] resourcePath]]
                      atomically:TRUE];

        NSAlert *warn = [[NSAlert alloc] init];
        [warn setMessageText:@"Dualboot: Would you like to also enable AMFI + AMSD/ASBS/APSD Kernel patches? AMFI "
                             @"patches are not always nessacary, Divise would have informed you if they were for your "
                             @"dualboot, but AMSD/ASBS/APSD patches may be nessacary if you are experiencing random "
                             @"panics and reboots after unplugging your device in its secondOS."];
        [warn setInformativeText:@"There is no risk in enabling these patches."];
        warn.window.titlebarAppearsTransparent = true;
        [warn addButtonWithTitle:@"Yes"];
        [warn addButtonWithTitle:@"No"];
        NSModalResponse dualChoice = [warn runModal];
        if (dualChoice == NSAlertFirstButtonReturn) {
            [ramielPrefs setObject:@(1) forKey:@"amsd"];
            [ramielPrefs setObject:@(1) forKey:@"amfi"];
            [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                [[NSBundle mainBundle] resourcePath]]
                          atomically:TRUE];
            [self->_amfiToggle setState:NSControlStateValueOn];
            [self->_amsdToggle setState:NSControlStateValueOn];
        } else {
            [ramielPrefs setObject:@(0) forKey:@"amsd"];
            [ramielPrefs setObject:@(0) forKey:@"amfi"];
            [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                [[NSBundle mainBundle] resourcePath]]
                          atomically:TRUE];
            [self->_amfiToggle setState:NSControlStateValueOff];
            [self->_amsdToggle setState:NSControlStateValueOff];
        }
    }
}

- (IBAction)useLocalSHSHButton:(NSButton *)sender {

    NSMutableDictionary *ramielPrefs = [NSMutableDictionary
        dictionaryWithDictionary:[NSDictionary dictionaryWithContentsOfFile:
                                                   [NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                              [[NSBundle mainBundle] resourcePath]]]];

    NSTextField *shshPathField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 50)];
    shshPathField.cell.sendsActionOnEndEditing = NO;
    shshPathField.placeholderString = @"Drag/Drop SHSH File here";

    NSStackView *stack = [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, 200, 50)];
    [stack addSubview:shshPathField];

    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.window.titlebarAppearsTransparent = true;
    [alert setMessageText:@"Please drag and drop your SHSH file into the textbox. You can also manually type in the "
                          @"path to the SHSH file if you wish."];
    alert.accessoryView = stack;
    [[alert window] setInitialFirstResponder:shshPathField];
    NSModalResponse choice = [alert runModal];
    if (choice != NSAlertFirstButtonReturn) {
        return;
    }
    while ([shshPathField.stringValue isEqualToString:@""]) {
        NSModalResponse choice = [alert runModal];
        if (choice != NSAlertFirstButtonReturn) {
            return;
        }
    }
    NSString *shshFile = [NSString stringWithContentsOfFile:[shshPathField stringValue]
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
    if (!([[shshPathField stringValue] containsString:@".shsh"] ||
          [[shshPathField stringValue] containsString:@".shsh2"]) ||
        ![shshFile containsString:@"ApImg4Ticket"]) {
        NSAlert *badFile = [[NSAlert alloc] init];
        [badFile addButtonWithTitle:@"OK"];
        [badFile setMessageText:@"Error: File given was not a valid SHSH/SHSH2 file. Not using given file."];
        badFile.window.titlebarAppearsTransparent = TRUE;
        [badFile runModal];
        return;
    }
    [ramielPrefs setObject:shshPathField.stringValue forKey:@"customSHSHPath"];
    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                                [[NSBundle mainBundle] resourcePath]]
                                               error:nil];
    [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                        [[NSBundle mainBundle] resourcePath]]
                  atomically:TRUE];
    NSAlert *worked = [[NSAlert alloc] init];
    [worked addButtonWithTitle:@"OK"];
    [worked setMessageText:
                @"Success: Ramiel will use this SHSH to sign the bootchain images for the remainder of this "
                @"session.\n(Execpt for when booting iOS 14.x as dumped SHSH will need to be used in that case.)"];
    worked.window.titlebarAppearsTransparent = TRUE;
    [worked runModal];
    return;
}

- (IBAction)backButton:(NSButton *)sender {
    [RamielView startBackground];
    [self.view.window.contentViewController dismissViewController:self];
}

- (IBAction)exitRecMode:(NSButton *)sender {

    irecv_error_t error = 0;
    irecv_client_t returnClient = [RamielView getClientExternal];

    int ret, mode;
    ret = irecv_get_mode(returnClient, &mode);
    if (ret == IRECV_E_SUCCESS) {
        if (mode == IRECV_K_RECOVERY_MODE_1 || mode == IRECV_K_RECOVERY_MODE_2 || mode == IRECV_K_RECOVERY_MODE_3 ||
            mode == IRECV_K_RECOVERY_MODE_4) {
            error = irecv_setenv(returnClient, "auto-boot", "true");
            if (error != IRECV_E_SUCCESS) {
                printf("%s\n", irecv_strerror(error));
            }

            error = irecv_saveenv(returnClient);
            if (error != IRECV_E_SUCCESS) {
                printf("%s\n", irecv_strerror(error));
            }

            error = irecv_reboot(returnClient);
            if (error != IRECV_E_SUCCESS) {
                printf("%s\n", irecv_strerror(error));
            } else {
                printf("%s\n", irecv_strerror(error));

                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"OK"];
                alert.window.titlebarAppearsTransparent = true;
                [alert setMessageText:@"Device is now rebooting into normal mode."];
                [alert runModal];
                [RamielView startBackground];
                [self.view.window.contentViewController dismissViewController:self];
            }
        } else {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:@"OK"];
            alert.window.titlebarAppearsTransparent = true;
            [alert setMessageText:@"Device is not in recovery mode, not doing anything..."];
            [alert runModal];
        }
    }
}

- (IBAction)toggleDebugButton:(NSButton *)sender {

    NSMutableDictionary *ramielPrefs = [NSMutableDictionary
        dictionaryWithDictionary:[NSDictionary dictionaryWithContentsOfFile:
                                                   [NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                              [[NSBundle mainBundle] resourcePath]]]];
    if ([self->_toggleDebugMode state] == 1) {

        NSAlert *warn = [[NSAlert alloc] init];
        [warn setMessageText:@"Warning: Enabling this option will log more information while Ramiel runs and it may "
                             @"cause Ramiel to run slower then normal. Verbose mode will also be disabled in favour of "
                             @"serial=3, which pipes the verbose ouput to a serial cable if present."];
        [warn setInformativeText:@"Only enable this if you know what you're doing"];
        warn.window.titlebarAppearsTransparent = true;
        [warn runModal];

        [ramielPrefs setObject:@(1) forKey:@"debug"];
        [[NSFileManager defaultManager]
            removeItemAtPath:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                        [[NSBundle mainBundle] resourcePath]]
                       error:nil];
        [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                            [[NSBundle mainBundle] resourcePath]]
                      atomically:TRUE];
    } else {
        [ramielPrefs setObject:@(0) forKey:@"debug"];
        [[NSFileManager defaultManager]
            removeItemAtPath:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                        [[NSBundle mainBundle] resourcePath]]
                       error:nil];
        [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                            [[NSBundle mainBundle] resourcePath]]
                      atomically:TRUE];
    }
}

- (IBAction)amfiToggleButton:(NSButton *)sender {
    NSMutableDictionary *ramielPrefs = [NSMutableDictionary
        dictionaryWithDictionary:[NSDictionary dictionaryWithContentsOfFile:
                                                   [NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                              [[NSBundle mainBundle] resourcePath]]]];
    if ([self->_amfiToggle state] == 1) {
        [ramielPrefs setObject:@(1) forKey:@"amfi"];
    } else {
        [ramielPrefs setObject:@(0) forKey:@"amfi"];
    }
    [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                        [[NSBundle mainBundle] resourcePath]]
                  atomically:TRUE];
}

- (IBAction)amsdToggleButton:(NSButton *)sender {
    NSMutableDictionary *ramielPrefs = [NSMutableDictionary
        dictionaryWithDictionary:[NSDictionary dictionaryWithContentsOfFile:
                                                   [NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                              [[NSBundle mainBundle] resourcePath]]]];
    if ([self->_amsdToggle state] == 1) {
        NSAlert *warn = [[NSAlert alloc] init];
        [warn setMessageText:
                  @"Warning: Enabling this option will patch out AppleMesaSEPDriver from the kernel, which is only "
                  @"required if your device panics after being locked and unplugged after booting the second OS."];
        [warn setInformativeText:@"Only enable this if you need to do so."];
        warn.window.titlebarAppearsTransparent = true;
        [warn runModal];
        [ramielPrefs setObject:@(1) forKey:@"amsd"];
    } else {
        [ramielPrefs setObject:@(0) forKey:@"amsd"];
    }
    [ramielPrefs writeToFile:[NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                        [[NSBundle mainBundle] resourcePath]]
                  atomically:TRUE];
}

@end
