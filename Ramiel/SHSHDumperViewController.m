//
//  SHSHDumperViewController.m
//  Ramiel
//
//  Created by Matthew Pierson on 21/02/21.
//  Copyright © 2021 moski. All rights reserved.
//

#import "SHSHDumperViewController.h"
#import "../Pods/SSZipArchive/SSZipArchive/SSZipArchive.h"
#import "Device.h"
#import "FirmwareKeys.h"
#import "IPSW.h"
#import "RamielView.h"
#include "kairos.h"

@implementation SHSHDumperViewController

irecv_error_t dumperror = 0;
int dumpcheckNum = 0;
int dumpcon = 0;
NSString *dumpextractPath;
NSString *dumpshshPath;
IPSW *dumpIPSW;
Device *dumpDevice;
FirmwareKeys *dumpKeys;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);
    dumpIPSW = [[IPSW alloc] initIPSWID];
    dumpKeys = [[FirmwareKeys alloc] initFirmwareKeysID];
    dumpDevice = [RamielView getConnectedDeviceInfo];
    [dumpDevice resetConnection];
    [dumpDevice setIRECVDeviceInfo:[dumpDevice getIRECVClient]];
}

- (IBAction)loadIPSW:(NSButton *)sender {

    [self->_dumpSHSHButton setHidden:TRUE];
    [self->_dumpSHSHButton setEnabled:FALSE];
    [self->_prog setHidden:FALSE];
    [self->_prog setIndeterminate:FALSE];

    if (!([[NSString stringWithFormat:@"%@", [dumpDevice getSerial_string]] containsString:@"checkm8"] ||
          [[NSString stringWithFormat:@"%@", [dumpDevice getSerial_string]] containsString:@"eclipsa"])) {
        while (TRUE) {
            NSAlert *pwnNotice = [[NSAlert alloc] init];
            [pwnNotice setMessageText:[NSString stringWithFormat:@"Your %@ is not in PWNDFU mode. "
                                                                 @"Please enter it now.",
                                                                 [dumpDevice getModel]]];
            [pwnNotice addButtonWithTitle:@"Run checkm8"];
            pwnNotice.window.titlebarAppearsTransparent = true;
            NSModalResponse choice = [pwnNotice runModal];
            if (choice == NSAlertFirstButtonReturn) {

                if ([dumpDevice runCheckm8] == 0) {
                    [dumpDevice setIRECVDeviceInfo:[dumpDevice getIRECVClient]];
                    break;
                }
            }
        }
    }

    NSMutableDictionary *ramielPrefs = [NSMutableDictionary
        dictionaryWithDictionary:[NSDictionary dictionaryWithContentsOfFile:
                                                   [NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                              [[NSBundle mainBundle] resourcePath]]]];

    [dumpIPSW setBootargs:[ramielPrefs objectForKey:@"customBootArgs"]];
    if ([RamielView debugCheck]) {
        [dumpIPSW setBootargs:[NSString stringWithFormat:@"%@ serial=3",
                                                         [dumpIPSW getBootargs]]]; // Outputs verbose boot text to
                                                                                   // serial, useful for debugging
    }

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
                [dumpIPSW setIpswPath:openDlg.URL.path];
            });

            while ([dumpIPSW getIpswPath] == NULL) {
            }

            dumpextractPath =
                [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
            dumpextractPath = [NSString stringWithFormat:@"%@/RamielIPSW", [[NSBundle mainBundle] resourcePath]];
            if ([RamielView debugCheck])
                NSLog(@"Unzipping IPSW From Path: %@\nto path: %@", [dumpIPSW getIpswPath], dumpextractPath);
            if ([[[NSFileManager defaultManager] attributesOfItemAtPath:[dumpIPSW getIpswPath] error:nil] fileSize] <
                1400000000.00) { // If the IPSW is less then 1.5GB then its likely incomplete
                dispatch_async(dispatch_get_main_queue(), ^{
                    [RamielView errorHandler:
                        @"Downloaded IPSW is corrupt":
                            @"Please re-download the IPSW and try again, either from ipsw.me or using Ramiel's IPSW "
                             @"downloader.":
                                 [NSString
                                     stringWithFormat:
                                         @"IPSW's size in bytes is %llu which is to small for an actual IPSW",
                                         [[[NSFileManager defaultManager] attributesOfItemAtPath:[dumpIPSW getIpswPath]
                                                                                           error:nil] fileSize]]];
                    [[NSFileManager defaultManager] removeItemAtPath:[dumpIPSW getIpswPath] error:nil];
                    return;
                });
            }
            if ([[NSFileManager defaultManager] fileExistsAtPath:[dumpextractPath pathExtension]
                                                     isDirectory:(BOOL * _Nullable) TRUE]) {

                [[NSFileManager defaultManager] removeItemAtPath:dumpextractPath error:nil];
            }

            [[NSFileManager defaultManager] createDirectoryAtPath:dumpextractPath
                                      withIntermediateDirectories:TRUE
                                                       attributes:NULL
                                                            error:nil];

            //[SSZipArchive unzipFileAtPath:[dumpIPSW getIpswPath] toDestination:dumpextractPath];
            NSError *er = nil;
            [SSZipArchive unzipFileAtPath:[dumpIPSW getIpswPath]
                            toDestination:dumpextractPath
                                overwrite:YES
                                 password:nil
                                    error:&er];
            if (er) {
                NSLog(@"sadge: %@", er);
            }

            dumpcheckNum = 1;
        });

    } else {
        //[self->_prog setHidden:TRUE];
        [self.view.window.contentViewController dismissViewController:self];
        return;
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        while (dumpcheckNum == 0) {
            NSLog(@"unzipping...");
            sleep(2);
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_prog incrementBy:8.33];
            [self->_label setStringValue:@"Parsing BuildManifest..."];
        });

        if ([[NSFileManager defaultManager]
                fileExistsAtPath:[NSString stringWithFormat:@"%@/BuildManifest.plist", dumpextractPath]]) {

            NSDictionary *manifestData = [NSDictionary
                dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/BuildManifest.plist", dumpextractPath]];
            [dumpIPSW setIosVersion:[manifestData objectForKey:@"ProductVersion"]]; // Get IPSW's iOS version
            [dumpIPSW
                setSupportedModels:[manifestData objectForKey:@"SupportedProductTypes"]]; // Get supported devices list
            int supported = 0;
            for (int i = 0; i < [[dumpIPSW getSupportedModels] count]; i++) {
                if ([[[dumpIPSW getSupportedModels] objectAtIndex:i] containsString:[dumpDevice getModel]]) {
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
                [dumpIPSW setReleaseBuild:YES];
            } else {
                [dumpIPSW setReleaseBuild:NO];
            }

            for (int i = 0; i < [buildID count]; i++) {

                if ([buildID[i][@"ApChipID"] isEqual:[dumpDevice getCpid]]) {

                    if ([buildID[i][@"Info"][@"DeviceClass"] isEqual:[dumpDevice getHardware_model]]) {

                        [dumpIPSW setIbssName:buildID[i][@"Manifest"][@"iBSS"][@"Info"][@"Path"]];
                        [dumpIPSW setIbecName:buildID[i][@"Manifest"][@"iBEC"][@"Info"][@"Path"]];
                        [dumpIPSW setDeviceTreeName:buildID[i][@"Manifest"][@"DeviceTree"][@"Info"][@"Path"]];
                        [dumpIPSW setKernelName:buildID[i][@"Manifest"][@"KernelCache"][@"Info"][@"Path"]];
                        [dumpIPSW
                            setTrustCacheName:[NSString
                                                  stringWithFormat:@"Firmware/%@.trustcache",
                                                                   buildID[i][@"Manifest"][@"OS"][@"Info"][@"Path"]]];
                        [dumpIPSW setRestoreRamdiskName:buildID[i][@"Manifest"][@"RestoreRamDisk"][@"Info"][@"Path"]];
                        break;
                    }
                }
            }

            if ([dumpIPSW getIbssName] != NULL) {

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
                    moveItemAtPath:[NSString stringWithFormat:@"%@/%@", dumpextractPath, [dumpIPSW getIbssName]]
                            toPath:[NSString stringWithFormat:@"%@/RamielFiles/ibss.im4p", documentsFolder]
                             error:nil];
                [[NSFileManager defaultManager]
                    moveItemAtPath:[NSString stringWithFormat:@"%@/%@", dumpextractPath, [dumpIPSW getIbecName]]
                            toPath:[NSString stringWithFormat:@"%@/RamielFiles/ibec.im4p", documentsFolder]
                             error:nil];
                [[NSFileManager defaultManager]
                    moveItemAtPath:[NSString stringWithFormat:@"%@/%@", dumpextractPath, [dumpIPSW getDeviceTreeName]]
                            toPath:[NSString stringWithFormat:@"%@/RamielFiles/devicetree.im4p", documentsFolder]
                             error:nil];
                [[NSFileManager defaultManager]
                    moveItemAtPath:[NSString stringWithFormat:@"%@/%@", dumpextractPath, [dumpIPSW getTrustCacheName]]
                            toPath:[NSString stringWithFormat:@"%@/RamielFiles/trustcache.im4p", documentsFolder]
                             error:nil];
                [[NSFileManager defaultManager]
                    moveItemAtPath:[NSString stringWithFormat:@"%@/%@", dumpextractPath, [dumpIPSW getKernelName]]
                            toPath:[NSString stringWithFormat:@"%@/RamielFiles/kernel.im4p", documentsFolder]
                             error:nil];
                [[NSFileManager defaultManager]
                    moveItemAtPath:[NSString
                                       stringWithFormat:@"%@/%@", dumpextractPath, [dumpIPSW getRestoreRamdiskName]]
                            toPath:[NSString stringWithFormat:@"%@/RamielFiles/ramdisk.im4p", documentsFolder]
                             error:nil];

                [[NSFileManager defaultManager] removeItemAtPath:dumpextractPath error:nil];

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_prog incrementBy:16.66];
                    [self->_label setStringValue:@"Grabbing Firmware Keys..."];
                });

                if ([dumpKeys checkLocalKeys:dumpDevice:dumpIPSW]) {
                    [dumpKeys readFirmwareKeysFromFile:dumpDevice:dumpIPSW];
                } else {
                    if (![dumpKeys fetchKeysFromWiki:dumpDevice:dumpIPSW:manifestData]) {
                        [self.view.window.contentViewController dismissViewController:self];
                        return;
                    }
                }
                if (![dumpKeys getUsingLocalKeys]) {
                    if (![dumpKeys writeFirmwareKeysToFile:dumpDevice:dumpIPSW]) {
                        // Failed to write to file
                    }
                    [dumpKeys setIsUsingLocalKeys:TRUE];
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_prog incrementBy:16.66];
                    [self->_label setStringValue:@"Patching iBSS/iBEC..."];
                });
                if (!([dumpKeys getIbssKEY].length == 64 && [dumpKeys getIbecKEY].length == 64 &&
                      [dumpKeys getIbssIV].length == 32 &&
                      [dumpKeys getIbecIV].length == 32)) { // Ensure that the keys we got are the right length

                    dispatch_async(dispatch_get_main_queue(), ^{
                        [RamielView errorHandler:
                            @"Received malformed keys":
                                [NSString
                                    stringWithFormat:@"Expected string lengths of 64 & 32 but got %lu, %lu & %lu, %lu",
                                                     (unsigned long)[dumpKeys getIbssKEY].length,
                                                     (unsigned long)[dumpKeys getIbssIV].length,
                                                     (unsigned long)[dumpKeys getIbecKEY].length,
                                                     (unsigned long)[dumpKeys getIbecIV].length
                        ]:[NSString stringWithFormat:
                                        @"Key Information:\n\niBSS Key: %@\niBSS IVs: %@\niBEC Key: %@\niBEC IVs: %@",
                                        [dumpKeys getIbssKEY], [dumpKeys getIbssIV], [dumpKeys getIbecKEY],
                                        [dumpKeys getIbecIV]]];

                        [self.view.window.contentViewController dismissViewController:self];
                        return;
                    });
                }

                // This is all done now, will leave just because
                //
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

                dumpcon = 1;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_label setStringValue:@"Creating SSH Ramdisk..."];
                    [self->_prog incrementBy:-100.00];
                });
                while (dumpcon == 0) {
                    NSLog(@"Waiting...");
                    sleep(2);
                }
                dumpcon = 0;
                // Create SSH Ramdisk
                if ([[dumpIPSW getIosVersion] containsString:@"9."] ||
                    [[dumpIPSW getIosVersion] containsString:@"8."] ||
                    [[dumpIPSW getIosVersion] containsString:@"7."]) {
                    [RamielView img4toolCMD:[NSString stringWithFormat:@"-e -o %@/RamielFiles/ramdisk.dmg "
                                                                       @"--iv %@ --key %@ %@/RamielFiles/ramdisk.im4p",
                                                                       [[NSBundle mainBundle] resourcePath],
                                                                       dumpKeys.getRestoreRamdiskIV,
                                                                       dumpKeys.getRestoreRamdiskKEY,
                                                                       [[NSBundle mainBundle] resourcePath]]];
                } else {
                    [RamielView img4toolCMD:[NSString stringWithFormat:@"-e -o %@/RamielFiles/ramdisk.dmg "
                                                                       @"%@/RamielFiles/ramdisk.im4p",
                                                                       [[NSBundle mainBundle] resourcePath],
                                                                       [[NSBundle mainBundle] resourcePath]]];
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
                    [self->_label setStringValue:@"Adding files to Ramdisk..."];
                    [self->_prog incrementBy:14.28];
                });
                [RamielView otherCMD:[NSString stringWithFormat:@"/usr/bin/hdiutil attach -mountpoint "
                                                                @"/tmp/RamielMount %@/RamielFiles/ramdisk.dmg",
                                                                [[NSBundle mainBundle] resourcePath]]];
                // Download SSH.tar
                // https://github.com/MatthewPierson/sshTar/blob/main/ssh.tar?raw=true
                if (![[NSFileManager defaultManager]
                        fileExistsAtPath:[NSString stringWithFormat:@"%@/ssh/ssh.tar",
                                                                    [[NSBundle mainBundle] resourcePath]]]) {
                    NSString *stringURL = @"https://github.com/MatthewPierson/sshTar/blob/main/ssh.tar?raw=true";
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
                    [self->_label setStringValue:@"Adding entitlements..."];
                    [self->_prog incrementBy:14.28];
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
                    [RamielView otherCMD:[NSString stringWithFormat:@"%@/ssh/ldid2 -M%@/ssh/ent.xml "
                                                                    @"/tmp/RamielMount/bin/%@",
                                                                    [[NSBundle mainBundle] resourcePath],
                                                                    [[NSBundle mainBundle] resourcePath], bin[i]]];
                }
                bin = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/tmp/RamielMount/usr/bin/" error:nil];

                for (int i = 0; i < [bin count]; i++) {
                    [RamielView otherCMD:[NSString stringWithFormat:@"%@/ssh/ldid2 -M%@/ssh/ent.xml "
                                                                    @"/tmp/RamielMount/usr/bin/%@",
                                                                    [[NSBundle mainBundle] resourcePath],
                                                                    [[NSBundle mainBundle] resourcePath], bin[i]]];
                }
                bin = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/tmp/RamielMount/usr/sbin/"
                                                                          error:nil];

                for (int i = 0; i < [bin count]; i++) {
                    [RamielView otherCMD:[NSString stringWithFormat:@"%@/ssh/ldid2 -M%@/ssh/ent.xml "
                                                                    @"/tmp/RamielMount/usr/sbin/%@",
                                                                    [[NSBundle mainBundle] resourcePath],
                                                                    [[NSBundle mainBundle] resourcePath], bin[i]]];
                }
                bin = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/tmp/RamielMount/usr/local/bin/"
                                                                          error:nil];

                for (int i = 0; i < [bin count]; i++) {
                    [RamielView otherCMD:[NSString stringWithFormat:@"%@/ssh/ldid2 -M%@/ssh/ent.xml "
                                                                    @"/tmp/RamielMount/usr/local/bin/%@",
                                                                    [[NSBundle mainBundle] resourcePath],
                                                                    [[NSBundle mainBundle] resourcePath], bin[i]]];
                }
                bin = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/tmp/RamielMount/usr/local/sbin/"
                                                                          error:nil];

                for (int i = 0; i < [bin count]; i++) {
                    [RamielView otherCMD:[NSString stringWithFormat:@"%@/ssh/ldid2 -M%@/ssh/ent.xml "
                                                                    @"/tmp/RamielMount/usr/local/sbin/%@",
                                                                    [[NSBundle mainBundle] resourcePath],
                                                                    [[NSBundle mainBundle] resourcePath], bin[i]]];
                }

                bin = [[NSFileManager defaultManager]
                    contentsOfDirectoryAtPath:@"/tmp/RamielMount/System/Library/Filesystems/apfs.fs/"
                                        error:nil];

                for (int i = 0; i < [bin count]; i++) {
                    [RamielView otherCMD:[NSString stringWithFormat:@"%@/ssh/ldid2 -M -S%@/ssh/ent.xml "
                                                                    @"/tmp/RamielMount/System/Library/Filesystems/"
                                                                    @"apfs.fs/%@",
                                                                    [[NSBundle mainBundle] resourcePath],
                                                                    [[NSBundle mainBundle] resourcePath], bin[i]]];
                }
                bin = [[NSFileManager defaultManager]
                    contentsOfDirectoryAtPath:@"/tmp/RamielMount/System/Library/Filesystems/hfs.fs/Contents/Resources/"
                                        error:nil];

                for (int i = 0; i < [bin count]; i++) {
                    [RamielView otherCMD:[NSString stringWithFormat:@"%@/ssh/ldid2 -M -S%@/ssh/ent.xml "
                                                                    @"/tmp/RamielMount/System/Library/Filesystems/"
                                                                    @"hfs.fs/Contents/Resources/%@",
                                                                    [[NSBundle mainBundle] resourcePath],
                                                                    [[NSBundle mainBundle] resourcePath], bin[i]]];
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_label setStringValue:@"Unmounting ramdisk..."];
                    [self->_prog incrementBy:14.28];
                });
                [RamielView otherCMD:@"/usr/bin/hdiutil detach -force /tmp/RamielMount"];
                sleep(2);
                [RamielView
                    otherCMD:[NSString
                                 stringWithFormat:@"/usr/bin/hdiutil resize -sectors min %@/RamielFiles/ramdisk.dmg",
                                                  [[NSBundle mainBundle]
                                                      resourcePath]]]; // Shrink dmg to smallest it will go, only needs
                                                                       // to be larger while we add files to it
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_label setStringValue:@"Packing back to IM4P/IMG4..."];
                    [self->_prog incrementBy:14.28];
                });
                [RamielView img4toolCMD:[NSString stringWithFormat:@"-c %@/RamielFiles/ramdisk.ssh.im4p -t rdsk "
                                                                   @"-d SSH_RAMDISK  %@/RamielFiles/ramdisk.dmg",
                                                                   [[NSBundle mainBundle] resourcePath],
                                                                   [[NSBundle mainBundle] resourcePath]]];
                NSMutableDictionary *ramielPrefs = [NSMutableDictionary
                    dictionaryWithDictionary:[NSDictionary
                                                 dictionaryWithContentsOfFile:
                                                     [NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                                [[NSBundle mainBundle] resourcePath]]]];
                if (![[ramielPrefs objectForKey:@"customSHSHPath"] containsString:@"N/A"]) {
                    if ([RamielView debugCheck])
                        NSLog(@"Using user-provided SHSH from: %@", [ramielPrefs objectForKey:@"customSHSHPath"]);
                    dumpshshPath = [ramielPrefs objectForKey:@"customSHSHPath"];
                } else if ([[NSFileManager defaultManager]
                               fileExistsAtPath:[NSString stringWithFormat:@"%@/shsh/%@.shsh",
                                                                           [[NSBundle mainBundle] resourcePath],
                                                                           [dumpDevice getCpid]]]) {
                    dumpshshPath = [NSString stringWithFormat:@"%@/shsh/%@.shsh", [[NSBundle mainBundle] resourcePath],
                                                              [dumpDevice getCpid]];
                } else {
                    dumpshshPath =
                        [NSString stringWithFormat:@"%@/shsh/shsh.shsh", [[NSBundle mainBundle] resourcePath]];
                }
                [RamielView img4toolCMD:[NSString stringWithFormat:@"-c %@/ramdisk.img4 -p "
                                                                   @"%@/RamielFiles/ramdisk.ssh.im4p -s %@",
                                                                   [[NSBundle mainBundle] resourcePath],
                                                                   [[NSBundle mainBundle] resourcePath], dumpshshPath]];

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_label setStringValue:@"Preparing other boot files..."];
                    [self->_prog incrementBy:7.14];
                });
                [self prepareSSHBootChain];

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_label setStringValue:@"Booting SSH Ramdisk..."];
                    [self->_prog incrementBy:7.14];
                });

                // Boot SSH Ramdisk
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self bootDevice];
                });
                while (dumpcon == 0) {
                    NSLog(@"Waiting...");
                    sleep(2);
                }
                dumpcon = 0;

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_label setStringValue:@"Waiting For Device..."];
                    [self->_prog incrementBy:71.40];
                    [self->_prog incrementBy:14.28];
                });

                sleep(15);

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_label setStringValue:@"Dumping SHSH..."];
                    [self->_prog incrementBy:14.28];
                });

                NSTask *task = [[NSTask alloc] init];
                [task setLaunchPath:@"/bin/bash"];
                [task setArguments:@[
                    @"-c", [NSString stringWithFormat:@"%@/ssh/iproxy 2222 44", [[NSBundle mainBundle] resourcePath]]
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
                // ssh -p 2222 root@localhost "dd if=/dev/disk1 bs=256 count=$((0x4000))" | dd of=/tmp/dump.raw
                [RamielView
                    img4toolCMD:[NSString stringWithFormat:@"--convert -s %@/Ramiel/shsh/%llu_%@.shsh /tmp/dump.raw",
                                                           NSSearchPathForDirectoriesInDomains(
                                                               NSDocumentDirectory, NSUserDomainMask, YES)[0],
                                                           (uint64_t)[dumpDevice getEcid], [dumpIPSW getIosVersion]]];

                if ([[NSFileManager defaultManager]
                        fileExistsAtPath:[NSString stringWithFormat:@"%@/Ramiel/shsh/%llu_%@.shsh",
                                                                    NSSearchPathForDirectoriesInDomains(
                                                                        NSDocumentDirectory, NSUserDomainMask, YES)[0],
                                                                    (uint64_t)[dumpDevice getEcid],
                                                                    [dumpIPSW getIosVersion]]]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSAlert *rebootAlert = [[NSAlert alloc] init];
                        [rebootAlert setMessageText:@"SHSH dumped successfully!"];
                        [rebootAlert
                            setInformativeText:
                                [NSString stringWithFormat:@"Dumped SHSH has been saved to your Documents "
                                                           @"folder at the path:  \"%@/Ramiel/shsh/%llu_%@.shsh\"",
                                                           NSSearchPathForDirectoriesInDomains(
                                                               NSDocumentDirectory, NSUserDomainMask, YES)[0],
                                                           (uint64_t)[dumpDevice getEcid], [dumpIPSW getIosVersion]]];
                        rebootAlert.window.titlebarAppearsTransparent = true;
                        [rebootAlert runModal];
                        [[NSFileManager defaultManager] removeItemAtPath:@"/tmp/dump.raw" error:nil];
                        dumpcon = 1;
                        [self.view.window.contentViewController dismissViewController:self];
                    });

                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [RamielView errorHandler:
                            @"Failed to dump SHSH":@"Please reboot into DFU mode and try again."
                                                  :@"Failed to find dumped SHSH file on disk."];

                        [self.view.window.contentViewController dismissViewController:self];
                        return;
                    });
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

- (void)prepareSSHBootChain {

    [RamielView img4toolCMD:[NSString stringWithFormat:@"-e -o %@/RamielFiles/ibss.raw --iv %@ "
                                                       @"--key %@ %@/RamielFiles/ibss.im4p",
                                                       [[NSBundle mainBundle] resourcePath], [dumpKeys getIbssIV],
                                                       [dumpKeys getIbssKEY], [[NSBundle mainBundle] resourcePath]]];

    [RamielView img4toolCMD:[NSString stringWithFormat:@"-e -o %@/RamielFiles/ibec.raw --iv %@ "
                                                       @"--key %@ %@/RamielFiles/ibec.im4p",
                                                       [[NSBundle mainBundle] resourcePath], [dumpKeys getIbecIV],
                                                       [dumpKeys getIbecKEY], [[NSBundle mainBundle] resourcePath]]];

    const char *ibssPath =
        [[NSString stringWithFormat:@"%@/RamielFiles/ibss.raw", [[NSBundle mainBundle] resourcePath]] UTF8String];
    const char *ibssPwnPath =
        [[NSString stringWithFormat:@"%@/RamielFiles/ibss.pwn", [[NSBundle mainBundle] resourcePath]] UTF8String];
    const char *ibecPath =
        [[NSString stringWithFormat:@"%@/RamielFiles/ibec.raw", [[NSBundle mainBundle] resourcePath]] UTF8String];
    const char *ibecPwnPath =
        [[NSString stringWithFormat:@"%@/RamielFiles/ibec.pwn", [[NSBundle mainBundle] resourcePath]] UTF8String];
    const char *args = [@"-v rd=md0 debug=0x14e" UTF8String];
    int ret;
    if ([[dumpIPSW getIosVersion] containsString:@"8."] || [[dumpIPSW getIosVersion] containsString:@"7."]) {
        args = [@"-v rd=md0 debug=0x14e amfi=0xff cs_enforcement_disable=1 amfi_get_out_of_my_way=1" UTF8String];
    }
    if ([[dumpIPSW getIosVersion] containsString:@"9."] || [[dumpIPSW getIosVersion] containsString:@"8."] ||
        [[dumpIPSW getIosVersion] containsString:@"7."]) {
        [RamielView otherCMD:[NSString stringWithFormat:@"%@/iPatcher %s %s", [[NSBundle mainBundle] resourcePath],
                                                        ibssPath, ibssPwnPath]];
    } else {
        sleep(1);
        ret = patchIBXX((char *)ibssPath, (char *)ibssPwnPath, (char *)args, 0);

        if (ret != 0) {
            dispatch_queue_t mainQueue = dispatch_get_main_queue();
            dispatch_sync(mainQueue, ^{
                [RamielView errorHandler:
                    @"Failed to patch iBSS":[NSString stringWithFormat:@"Kairos returned with: %i", ret]:@"N/A"];
                [self->_prog setHidden:TRUE];
                [self.view.window.contentViewController dismissViewController:self];
                return;
            });
        }
    }
    if ([[dumpIPSW getIosVersion] containsString:@"9."] || [[dumpIPSW getIosVersion] containsString:@"8."] ||
        [[dumpIPSW getIosVersion] containsString:@"7."]) {
        patchIBXX((char *)ibecPath, (char *)ibecPwnPath, (char *)args, 1);
        [RamielView otherCMD:[NSString stringWithFormat:@"%@/iPatcher %s %s", [[NSBundle mainBundle] resourcePath],
                                                        ibecPwnPath, ibecPwnPath]];
    } else {
        ret = patchIBXX((char *)ibecPath, (char *)ibecPwnPath, (char *)args, 0);

        if (ret != 0) {
            dispatch_queue_t mainQueue = dispatch_get_main_queue();
            dispatch_sync(mainQueue, ^{
                [RamielView errorHandler:
                    @"Failed to patch iBEC":[NSString stringWithFormat:@"Kairos returned with: %i", ret]:@"N/A"];
                [self->_prog setHidden:TRUE];
                [self.view.window.contentViewController dismissViewController:self];
                return;
            });
        }
    }
    [RamielView img4toolCMD:[NSString stringWithFormat:@"-c %@/RamielFiles/ibss.%@.patched -t ibss "
                                                       @"%@/RamielFiles/ibss.pwn",
                                                       [[NSBundle mainBundle] resourcePath], [dumpDevice getModel],
                                                       [[NSBundle mainBundle] resourcePath]]];

    [RamielView img4toolCMD:[NSString stringWithFormat:@"-c %@/RamielFiles/ibec.%@.patched -t ibec "
                                                       @"%@/RamielFiles/ibec.pwn",
                                                       [[NSBundle mainBundle] resourcePath], [dumpDevice getModel],
                                                       [[NSBundle mainBundle] resourcePath]]];
    NSMutableDictionary *ramielPrefs = [NSMutableDictionary
        dictionaryWithDictionary:[NSDictionary dictionaryWithContentsOfFile:
                                                   [NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                              [[NSBundle mainBundle] resourcePath]]]];
    if (![[ramielPrefs objectForKey:@"customSHSHPath"] containsString:@"N/A"]) {
        if ([RamielView debugCheck])
            NSLog(@"Using user-provided SHSH from: %@", [ramielPrefs objectForKey:@"customSHSHPath"]);
        dumpshshPath = [ramielPrefs objectForKey:@"customSHSHPath"];
    } else if ([[NSFileManager defaultManager]
                   fileExistsAtPath:[NSString stringWithFormat:@"%@/shsh/%@.shsh", [[NSBundle mainBundle] resourcePath],
                                                               [dumpDevice getCpid]]]) {
        dumpshshPath =
            [NSString stringWithFormat:@"%@/shsh/%@.shsh", [[NSBundle mainBundle] resourcePath], [dumpDevice getCpid]];
    } else {
        dumpshshPath = [NSString stringWithFormat:@"%@/shsh/shsh.shsh", [[NSBundle mainBundle] resourcePath]];
    }

    [RamielView img4toolCMD:[NSString stringWithFormat:@"-c %@/ibss.img4 -p %@/RamielFiles/ibss.%@.patched -s %@",
                                                       [[NSBundle mainBundle] resourcePath],
                                                       [[NSBundle mainBundle] resourcePath], [dumpDevice getModel],
                                                       dumpshshPath]];

    [RamielView img4toolCMD:[NSString stringWithFormat:@"-c %@/ibec.img4 -p %@/RamielFiles/ibec.%@.patched -s %@",
                                                       [[NSBundle mainBundle] resourcePath],
                                                       [[NSBundle mainBundle] resourcePath], [dumpDevice getModel],
                                                       dumpshshPath]];

    [RamielView img4toolCMD:[NSString stringWithFormat:@"-c %@/sshLogo.img4 -p %@/ssh/sshLogo.im4p -s %@",
                                                       [[NSBundle mainBundle] resourcePath],
                                                       [[NSBundle mainBundle] resourcePath], dumpshshPath]];
    if ([[dumpIPSW getIosVersion] containsString:@"9."] || [[dumpIPSW getIosVersion] containsString:@"8."] ||
        [[dumpIPSW getIosVersion] containsString:@"7."]) {
        [RamielView
            img4toolCMD:[NSString stringWithFormat:@"-e -o %@/RamielFiles/devicetree.raw --iv %@ "
                                                   @"--key %@ %@/RamielFiles/devicetree.im4p",
                                                   [[NSBundle mainBundle] resourcePath], [dumpKeys getDevicetreeIV],
                                                   [dumpKeys getDevicetreeKEY], [[NSBundle mainBundle] resourcePath]]];
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
                                                       [[NSBundle mainBundle] resourcePath], dumpshshPath]];

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
                                                           [[NSBundle mainBundle] resourcePath], dumpshshPath]];
    }
    if ([[dumpIPSW getIosVersion] containsString:@"8."] || [[dumpIPSW getIosVersion] containsString:@"7."]) {
        [RamielView img4toolCMD:[NSString stringWithFormat:@"-e -s %@ -m %@/RamielFiles/IM4M", dumpshshPath,
                                                           [[NSBundle mainBundle] resourcePath]]];
        [RamielView otherCMD:[NSString stringWithFormat:@"/usr/local/bin/img4 -i %@/RamielFiles/kernel.im4p -o "
                                                        @"%@/kernel.img4 -k %@%@ -M %@/RamielFiles/IM4M -T rkrn -D",
                                                        [[NSBundle mainBundle] resourcePath],
                                                        [[NSBundle mainBundle] resourcePath], [dumpKeys getKernelIV],
                                                        [dumpKeys getKernelKEY], [[NSBundle mainBundle] resourcePath]]];

    } else {
        [self kernelAMFIPatches];
    }
}

- (int)kernelAMFIPatches {
    int ret = 0;

    if ([[dumpIPSW getIosVersion] containsString:@"9."]) {
        [RamielView
            img4toolCMD:[NSString stringWithFormat:@"-e -o %@/RamielFiles/kernel.raw "
                                                   @"--iv %@ --key %@ %@/RamielFiles/kernel.im4p",
                                                   [[NSBundle mainBundle] resourcePath], [dumpKeys getKernelIV],
                                                   [dumpKeys getKernelKEY], [[NSBundle mainBundle] resourcePath]]];
    } else {
        [RamielView img4toolCMD:[NSString stringWithFormat:@"-e -o %@/RamielFiles/kernel.raw "
                                                           @"%@/RamielFiles/kernel.im4p",
                                                           [[NSBundle mainBundle] resourcePath],
                                                           [[NSBundle mainBundle] resourcePath]]];
    }
    NSString *kernel64patcher = [[NSString alloc] init];
    if ([[dumpDevice getCpid] containsString:@"8015"]) {
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
        dictionaryWithDictionary:[NSDictionary dictionaryWithContentsOfFile:
                                                   [NSString stringWithFormat:@"%@/com.moski.RamielSettings.plist",
                                                                              [[NSBundle mainBundle] resourcePath]]]];
    if ([[ramielPrefs objectForKey:@"amsd"] isEqual:@(1)]) {
        [RamielView otherCMD:[NSString stringWithFormat:@"%@/ssh/Kernel64Patcher %@/RamielFiles/kernel.pwn "
                                                        @"%@/RamielFiles/kernel.pwn2 -s",
                                                        [[NSBundle mainBundle] resourcePath],
                                                        [[NSBundle mainBundle] resourcePath],
                                                        [[NSBundle mainBundle] resourcePath]]];
        [[NSFileManager defaultManager]
            removeItemAtPath:[NSString
                                 stringWithFormat:@"%@/RamielFiles/kernel.pwn", [[NSBundle mainBundle] resourcePath]]
                       error:nil];
        [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/RamielFiles/kernel.pwn2",
                                                                                  [[NSBundle mainBundle] resourcePath]]
                                                toPath:[NSString stringWithFormat:@"%@/RamielFiles/kernel.pwn",
                                                                                  [[NSBundle mainBundle] resourcePath]]
                                                 error:nil];
    }
    [RamielView img4toolCMD:[NSString stringWithFormat:@"-e -s %@ -m %@/RamielFiles/IM4M", dumpshshPath,
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
    if ([[dumpIPSW getIosVersion] containsString:@"9."]) {
        [RamielView
            otherCMD:[NSString
                         stringWithFormat:@"/usr/local/bin/img4 -i %@/RamielFiles/kernel.im4p -o "
                                          @"%@/kernel.img4 -k %@%@ -M %@/RamielFiles/IM4M -T rkrn -P %@/kc.bpatch -J",
                                          [[NSBundle mainBundle] resourcePath], [[NSBundle mainBundle] resourcePath],
                                          [dumpKeys getKernelIV], [dumpKeys getKernelKEY],
                                          [[NSBundle mainBundle] resourcePath], [[NSBundle mainBundle] resourcePath]]];
    } else {
        [RamielView
            otherCMD:[NSString
                         stringWithFormat:@"/usr/local/bin/img4 -i %@/RamielFiles/kernel.im4p -o "
                                          @"%@/kernel.img4 -M %@/RamielFiles/IM4M -T rkrn -P %@/kc.bpatch -J",
                                          [[NSBundle mainBundle] resourcePath], [[NSBundle mainBundle] resourcePath],
                                          [[NSBundle mainBundle] resourcePath], [[NSBundle mainBundle] resourcePath]]];
    }

    return ret;
}

- (void)bootDevice {

    [self->_prog incrementBy:-100.00];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_label setStringValue:@"Booting Device..."];
    });

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        irecv_error_t ret = 0;

        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_prog incrementBy:12.5];
            [self->_label setStringValue:@"Sending iBSS..."];
        });
        NSString *err = @"send iBSS";
        NSString *ibss = [NSString stringWithFormat:@"%@/ibss.img4", [[NSBundle mainBundle] resourcePath]];
        ret = [dumpDevice sendImage:ibss];
        if (ret == IRECV_E_NO_DEVICE) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [RamielView errorHandler:
                    @"Failed to send iBSS to device":@"Ramiel wasn't able to reconnect to the device after sending iBSS"
                                                    :@"libirecovery returned: IRECV_E_NO_DEVICE"];
            });
            return;
        }
        if ([[dumpDevice getCpid] containsString:@"8015"] || [[dumpDevice getCpid] containsString:@"8960"] ||
            [[dumpDevice getCpid] containsString:@"8965"] || [[dumpDevice getCpid] containsString:@"8010"]) {
            irecv_reset([dumpDevice getIRECVClient]);
            [dumpDevice closeDeviceConnection];
            [dumpDevice setClient:NULL];
            usleep(1000);
            irecv_client_t temp = NULL;
            irecv_open_with_ecid_and_attempts(&temp, (uint64_t)[dumpDevice getEcid], 5);
            [dumpDevice setIRECVClient:temp];

            ret = [dumpDevice sendImage:ibss];
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
            irecv_reset([dumpDevice getIRECVClient]);
            [dumpDevice closeDeviceConnection];
            [dumpDevice setClient:NULL];
            usleep(1000);
            irecv_client_t temp = NULL;
            irecv_open_with_ecid_and_attempts(&temp, (uint64_t)[dumpDevice getEcid], 5);
            [dumpDevice setIRECVClient:temp];

            ret = [dumpDevice sendImage:ibss];
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
                ret = [dumpDevice sendImage:ibss];
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
        ret = 0;
        while (ret == 0) {

            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_prog incrementBy:12.5];
                [self->_label setStringValue:@"Sending iBEC..."];
            });
            err = @"send iBEC";
            NSString *ibec = [NSString stringWithFormat:@"%@/ibec.img4", [[NSBundle mainBundle] resourcePath]];
            ret = [dumpDevice sendImage:ibec];
            sleep(3);
            if ([[dumpDevice getCpid] containsString:@"8015"]) {
                sleep(2);
            }
            if ([[dumpDevice getCpid] isEqualToString:@"0x8010"] || [[dumpDevice getCpid] isEqualToString:@"0x8011"] ||
                [[dumpDevice getCpid] isEqualToString:@"0x8015"]) {
                ret = [dumpDevice sendImage:ibec];
                sleep(1);
                err = @"send go command";
                NSString *boot = @"go";
                ret = [dumpDevice sendCMD:boot];
                sleep(1);
            }
            err = @"send first bootx command";
            NSString *boot = @"bootx";
            sleep(10);
            irecv_reset([dumpDevice getIRECVClient]);
            [dumpDevice closeDeviceConnection];
            [dumpDevice setClient:NULL];
            usleep(1000);
            irecv_client_t temp = NULL;
            irecv_open_with_ecid_and_attempts(&temp, (uint64_t)[dumpDevice getEcid], 5);
            [dumpDevice setIRECVClient:temp];
            [dumpDevice sendCMD:boot];
            irecv_reset([dumpDevice getIRECVClient]);
            [dumpDevice closeDeviceConnection];
            [dumpDevice setClient:NULL];
            usleep(1000);
            temp = NULL;
            irecv_open_with_ecid_and_attempts(&temp, (uint64_t)[dumpDevice getEcid], 5);
            [dumpDevice setIRECVClient:temp];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_prog incrementBy:12.5];
                [self->_label setStringValue:@"Sending Bootlogo..."];
            });

            NSString *logo = [NSString stringWithFormat:@"%@/sshLogo.img4", [[NSBundle mainBundle] resourcePath]];
            err = @"send BootLogo";
            ret = [dumpDevice sendImage:logo];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_prog incrementBy:12.5];
                [self->_label setStringValue:@"Showing Bootlogo..."];
            });
            err = @"send setpicture command";
            NSString *setpic = @"setpicture 0";
            ret = [dumpDevice sendCMD:setpic];

            err = @"send bgcolor command";
            NSString *colour = @"bgcolor 0 0 0";
            ret = [dumpDevice sendCMD:colour];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_prog incrementBy:12.5];
                [self->_label setStringValue:@"Sending DeviceTree..."];
            });
            NSString *dtree = [NSString stringWithFormat:@"%@/devicetree.img4", [[NSBundle mainBundle] resourcePath]];
            err = @"send Devicetree";
            ret = [dumpDevice sendImage:dtree];

            NSString *dtreeCMD = @"devicetree";
            err = @"boot Devicetree";
            ret = [dumpDevice sendCMD:dtreeCMD];
            NSString *trustCMD = @"firmware";

            if ((([[dumpIPSW getIosVersion] containsString:@"12."] ||
                  [[dumpIPSW getIosVersion] containsString:@"13."] ||
                  [[dumpIPSW getIosVersion] containsString:@"14."]) &&
                 ![[NSFileManager defaultManager]
                     fileExistsAtPath:[NSString stringWithFormat:@"%@/ramdisk.img4",
                                                                 [[NSBundle mainBundle] resourcePath]]]) ||
                ([[dumpDevice getCpid] isEqualToString:@"0x8015"] || [[dumpDevice getCpid] isEqualToString:@"0x8010"] ||
                 [[dumpDevice getCpid] isEqualToString:@"0x7000"])) {

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_prog incrementBy:12.5];
                    [self->_label setStringValue:@"Sending TrustCache..."];
                });
                NSString *trust =
                    [NSString stringWithFormat:@"%@/trustcache.img4", [[NSBundle mainBundle] resourcePath]];
                err = @"send Trustcache";
                ret = [dumpDevice sendImage:trust];
                err = @"boot Trustcache";
                ret = [dumpDevice sendCMD:trustCMD];
            }

            if ([[NSFileManager defaultManager]
                    fileExistsAtPath:[NSString
                                         stringWithFormat:@"%@/ramdisk.img4", [[NSBundle mainBundle] resourcePath]]]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_label setStringValue:@"Sending SSH Ramdisk..."];
                });
                NSString *ramdisk =
                    [NSString stringWithFormat:@"%@/ramdisk.img4", [[NSBundle mainBundle] resourcePath]];
                if ([[dumpDevice getCpid] containsString:@"8015"]) {
                    sleep(5);
                }
                ret = [dumpDevice sendImage:ramdisk];

                if (ret != 1) {
                    ret = [dumpDevice sendCMD:@"ramdisk"];
                }
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_prog incrementBy:12.5];
                [self->_label setStringValue:@"Sending Kernel..."];
            });

            NSString *kernel = [NSString stringWithFormat:@"%@/kernel.img4", [[NSBundle mainBundle] resourcePath]];
            err = @"send Kernel";
            ret = [dumpDevice sendImage:kernel];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_prog incrementBy:100];
                [self->_label setStringValue:@"Booting Device..."];
            });
            NSString *kernelCMD = @"bootx";
            err = @"boot Device";
            ret = [dumpDevice sendCMD:kernelCMD];

            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"Booted device successfully!\n");

                dumpcon = 1;
                return;
            });
            break;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (ret != 0) {
                [self bootErrorReset:err];
                [self.view.window.contentViewController dismissViewController:self];
                return;
            } else {
                if ([[NSFileManager defaultManager]
                        fileExistsAtPath:[NSString stringWithFormat:@"%@/ramdisk.img4",
                                                                    [[NSBundle mainBundle] resourcePath]]]) {
                    [[NSFileManager defaultManager]
                        removeItemAtPath:[NSString
                                             stringWithFormat:@"%@/ramdisk.img4", [[NSBundle mainBundle] resourcePath]]
                                   error:nil];
                }
            }
        });
    });
}
- (void)bootErrorReset:(NSString *)error {

    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_label setStringValue:[NSString stringWithFormat:@"Failed to %@...", error]];
        NSAlert *alert = [[NSAlert alloc] init];
        alert.window.titlebarAppearsTransparent = true;
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:[NSString stringWithFormat:@"Error: Failed to %@...\n\nPlease reboot and "
                                                         @"re-exploit your device then try again...",
                                                         error]];
        [alert runModal];

        [self->_prog setHidden:TRUE];
    });
}
- (IBAction)backButton:(NSButton *)sender {
    [dumpDevice teardown];
    [dumpIPSW teardown];
    [self.view.window.contentViewController dismissViewController:self];
}

@end
