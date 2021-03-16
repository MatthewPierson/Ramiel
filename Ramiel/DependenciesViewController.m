//
//  DependenciesViewController.m
//  Ramiel
//
//  Created by Matthew Pierson on 12/03/21.
//  Copyright © 2021 moski. All rights reserved.
//

#import "DependenciesViewController.h"
#import "../Pods/SSZipArchive/SSZipArchive/SSZipArchive.h"
#import "RamielView.h"
#include <sys/sysctl.h>

@implementation DependenciesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);
    NSMutableArray *neededTools = [[NSMutableArray alloc] init];
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/local/bin/img4tool"]) {
        [neededTools addObject:@"img4tool"];
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/local/bin/img4"]) {
        [neededTools addObject:@"img4"];
    }
    if (![[NSFileManager defaultManager]
            fileExistsAtPath:[NSString
                                 stringWithFormat:@"%@/Exploits/Fugu/Fugu", [[NSBundle mainBundle] resourcePath]]]) {
        [neededTools addObject:@"Fugu"];
    }
    if (![[NSFileManager defaultManager]
            fileExistsAtPath:[NSString
                                 stringWithFormat:@"%@/Exploits/ipwndfu", [[NSBundle mainBundle] resourcePath]]]) {
        [neededTools addObject:@"ipwndfu"];
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/local/bin/iproxy"]) {
        [neededTools addObject:@"iproxy"];
    }

    NSString *text = @"";
    for (int i = 0; i < neededTools.count; i++) {
        if (i == neededTools.count - 1) {
            text = [NSString stringWithFormat:@"%@ %@", text, neededTools[i]];
        } else {
            text = [NSString stringWithFormat:@"%@ %@,", text, neededTools[i]];
        }
    }
    [self->_neededToolsLabel setStringValue:text];
}

- (IBAction)go:(NSButton *)sender {

    [self->_topLabel setHidden:TRUE];
    [self->_neededToolsLabel setStringValue:@""];
    [self->_spinner startAnimation:nil];
    [self->_spinner setHidden:FALSE];
    [self->_goButton setEnabled:FALSE];
    [self->_goButton setHidden:TRUE];

    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/local/bin/img4tool"]) {
        [self->_neededToolsLabel setStringValue:@"Downloading img4tool..."];
        NSString *stringURL = @"https://github.com/tihmstar/img4tool/releases/"
                              @"download/193/buildroot_macos-latest.zip";
        NSURL *url = [NSURL URLWithString:stringURL];
        NSData *urlData = [NSData dataWithContentsOfURL:url];
        if (urlData) {

            NSString *filePath = [NSString stringWithFormat:@"%@/img4tool.zip", [[NSBundle mainBundle] resourcePath]];
            [urlData writeToFile:filePath atomically:YES];

            [SSZipArchive
                unzipFileAtPath:[NSString stringWithFormat:@"%@/img4tool.zip", [[NSBundle mainBundle] resourcePath]]
                  toDestination:[NSString stringWithFormat:@"%@/", [[NSBundle mainBundle] resourcePath]]];

            [[NSFileManager defaultManager]
                moveItemAtPath:[NSString stringWithFormat:@"%@/buildroot_macos-latest/usr/local/bin/img4tool",
                                                          [[NSBundle mainBundle] resourcePath]]
                        toPath:@"/usr/local/bin/img4tool"
                         error:nil];

            [[NSFileManager defaultManager]
                moveItemAtPath:[NSString stringWithFormat:@"%@/buildroot_macos-latest/usr/"
                                                          @"local/include/img4tool",
                                                          [[NSBundle mainBundle] resourcePath]]
                        toPath:@"/usr/local/include/"
                         error:nil];

            [[NSFileManager defaultManager]
                moveItemAtPath:[NSString stringWithFormat:@"%@/buildroot_macos-latest/usr/"
                                                          @"local/lib/libimg4tool.a",
                                                          [[NSBundle mainBundle] resourcePath]]
                        toPath:@"/usr/local/lib/libimg4tool.a"
                         error:nil];
            [[NSFileManager defaultManager]
                moveItemAtPath:[NSString stringWithFormat:@"%@/buildroot_macos-latest/usr/"
                                                          @"local/lib/libimg4tool.la",
                                                          [[NSBundle mainBundle] resourcePath]]
                        toPath:@"/usr/local/lib/libimg4tool.la"
                         error:nil];
            [[NSFileManager defaultManager]
                moveItemAtPath:[NSString stringWithFormat:@"%@/buildroot_macos-latest/usr/"
                                                          @"local/lib/pkgconfig/libimg4tool.pc",
                                                          [[NSBundle mainBundle] resourcePath]]
                        toPath:@"/usr/local/lib/pkgconfig/libimg4tool.pc"
                         error:nil];

            [[NSFileManager defaultManager]
                removeItemAtPath:[NSString stringWithFormat:@"%@/buildroot_macos-latest",
                                                            [[NSBundle mainBundle] resourcePath]]
                           error:nil];
            [RamielView otherCMD:@"/bin/chmod 777 /usr/local/bin/img4tool"];
            if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/local/bin/img4tool"]) {
                NSAlert *fail = [[NSAlert alloc] init];
                [fail setMessageText:@"Download Failed: Failed to download img4tool from GitHub"];
                fail.window.titlebarAppearsTransparent = TRUE;
                [fail runModal];
            }
        } else {
            NSAlert *fail = [[NSAlert alloc] init];
            [fail setMessageText:@"Download Failed: Failed to download img4tool from GitHub"];
            fail.window.titlebarAppearsTransparent = TRUE;
            [fail runModal];
        }
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/local/bin/img4"]) {
        [self->_neededToolsLabel setStringValue:@"Downloading img4..."];

        NSString *stringURL = @"https://github.com/xerub/img4lib/releases/download/"
                              @"1.0/img4lib-2020-10-27.tar.gz";
        NSURL *url = [NSURL URLWithString:stringURL];
        NSData *urlData = [NSData dataWithContentsOfURL:url];
        if (urlData) {

            NSString *filePath = @"/tmp/img4lib.tar.gz";
            [urlData writeToFile:filePath atomically:YES];

            [RamielView otherCMD:@"/usr/bin/tar -xvf /tmp/img4lib.tar.gz -C /tmp"];

            [[NSFileManager defaultManager] moveItemAtPath:@"/tmp/img4lib-2020-10-27/apple/img4"
                                                    toPath:@"/usr/local/bin/img4"
                                                     error:nil];

            [RamielView otherCMD:@"/bin/chmod 777 /usr/local/bin/img4"];
            if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/local/bin/img4"]) {
                NSAlert *fail = [[NSAlert alloc] init];
                [fail setMessageText:@"Download Failed: Failed to download img4 from GitHub"];
                fail.window.titlebarAppearsTransparent = TRUE;
                [fail runModal];
            }
        } else {
            NSAlert *fail = [[NSAlert alloc] init];
            [fail setMessageText:@"Download Failed: Failed to download img4 from GitHub"];
            fail.window.titlebarAppearsTransparent = TRUE;
            [fail runModal];
        }
    }

    if (![[NSFileManager defaultManager]
            fileExistsAtPath:[NSString stringWithFormat:@"%@/Exploits/Fugu/Fugu",
                                                        [[NSBundle mainBundle]
                                                            resourcePath]]]) { // Check if Fugu is downloaded
        [self->_neededToolsLabel setStringValue:@"Downloading Fugu..."];
        NSString *stringURL = @"https://github.com/LinusHenze/Fugu/releases/"
                              @"download/v0.4/Fugu_v0.4.zip";
        NSURL *url = [NSURL URLWithString:stringURL];
        NSData *urlData = [NSData dataWithContentsOfURL:url];
        if (urlData) {

            NSString *filePath = [NSString stringWithFormat:@"%@/Fugu.zip", [[NSBundle mainBundle] resourcePath]];
            [urlData writeToFile:filePath atomically:YES];

            [SSZipArchive
                unzipFileAtPath:[NSString stringWithFormat:@"%@/Fugu.zip", [[NSBundle mainBundle] resourcePath]]
                  toDestination:[NSString stringWithFormat:@"%@/", [[NSBundle mainBundle] resourcePath]]];

            [[NSFileManager defaultManager]
                moveItemAtPath:[NSString stringWithFormat:@"%@/Fugu", [[NSBundle mainBundle] resourcePath]]
                        toPath:[NSString
                                   stringWithFormat:@"%@/Exploits/Fugu/Fugu", [[NSBundle mainBundle] resourcePath]]
                         error:nil];
            [[NSFileManager defaultManager]
                moveItemAtPath:[NSString stringWithFormat:@"%@/shellcode", [[NSBundle mainBundle] resourcePath]]
                        toPath:[NSString
                                   stringWithFormat:@"%@/Exploits/Fugu/shellcode", [[NSBundle mainBundle] resourcePath]]
                         error:nil];
            [[NSFileManager defaultManager]
                moveItemAtPath:[NSString stringWithFormat:@"%@/LICENSE", [[NSBundle mainBundle] resourcePath]]
                        toPath:[NSString
                                   stringWithFormat:@"%@/Exploits/Fugu/LICENSE", [[NSBundle mainBundle] resourcePath]]
                         error:nil];

            [[NSFileManager defaultManager]
                removeItemAtPath:[NSString stringWithFormat:@"%@/Fugu.zip", [[NSBundle mainBundle] resourcePath]]
                           error:nil];
            [[NSFileManager defaultManager]
                removeItemAtPath:[NSString stringWithFormat:@"%@/README.md", [[NSBundle mainBundle] resourcePath]]
                           error:nil];
            [[NSFileManager defaultManager]
                removeItemAtPath:[NSString stringWithFormat:@"%@/3rdParty.txt", [[NSBundle mainBundle] resourcePath]]
                           error:nil];
            [RamielView otherCMD:[NSString stringWithFormat:@"/bin/chmod 777 %@/Exploits/Fugu/Fugu",
                                                            [[NSBundle mainBundle] resourcePath]]];
            if (![[NSFileManager defaultManager]
                    fileExistsAtPath:[NSString stringWithFormat:@"%@/Exploits/Fugu/Fugu",
                                                                [[NSBundle mainBundle] resourcePath]]]) {
                NSAlert *fail = [[NSAlert alloc] init];
                [fail setMessageText:@"Download Failed: Failed to download Fugu from GitHub"];
                fail.window.titlebarAppearsTransparent = TRUE;
                [fail runModal];
            }
        } else {
            NSAlert *fail = [[NSAlert alloc] init];
            [fail setMessageText:@"Download Failed: Failed to download Fugu from GitHub"];
            fail.window.titlebarAppearsTransparent = TRUE;
            [fail runModal];
        }
    }

    if (![[NSFileManager defaultManager]
            fileExistsAtPath:[NSString stringWithFormat:@"%@/Exploits/ipwndfu",
                                                        [[NSBundle mainBundle]
                                                            resourcePath]]]) { // Check if Fugu is downloaded
        [self->_neededToolsLabel setStringValue:@"Downloading ipwndfu..."];
        NSString *stringURL = @"https://github.com/MatthewPierson/ipwndfuA11/archive/main.zip";
        NSURL *url = [NSURL URLWithString:stringURL];
        NSData *urlData = [NSData dataWithContentsOfURL:url];
        if (urlData) {

            NSString *filePath = [NSString stringWithFormat:@"%@/ipwndfu.zip", [[NSBundle mainBundle] resourcePath]];
            [urlData writeToFile:filePath atomically:YES];

            [SSZipArchive
                unzipFileAtPath:[NSString stringWithFormat:@"%@/ipwndfu.zip", [[NSBundle mainBundle] resourcePath]]
                  toDestination:[NSString stringWithFormat:@"%@/", [[NSBundle mainBundle] resourcePath]]];

            [[NSFileManager defaultManager]
                moveItemAtPath:[NSString stringWithFormat:@"%@/ipwndfuA11-main", [[NSBundle mainBundle] resourcePath]]
                        toPath:[NSString stringWithFormat:@"%@/Exploits/ipwndfu", [[NSBundle mainBundle] resourcePath]]
                         error:nil];

            [[NSFileManager defaultManager]
                removeItemAtPath:[NSString stringWithFormat:@"%@/ipwndfu.zip", [[NSBundle mainBundle] resourcePath]]
                           error:nil];
            [RamielView otherCMD:[NSString stringWithFormat:@"chmod 777 %@/Exploits/ipwndfu/ipwndfu",
                                                            [[NSBundle mainBundle] resourcePath]]];
            if (![[NSFileManager defaultManager]
                    fileExistsAtPath:[NSString stringWithFormat:@"%@/Exploits/ipwndfu/ipwndfu",
                                                                [[NSBundle mainBundle] resourcePath]]]) {
                NSAlert *fail = [[NSAlert alloc] init];
                [fail setMessageText:@"Download Failed: Failed to download ipwndfu from GitHub"];
                fail.window.titlebarAppearsTransparent = TRUE;
                [fail runModal];
            }
        } else {
            NSAlert *fail = [[NSAlert alloc] init];
            [fail setMessageText:@"Download Failed: Failed to download ipwndfu from GitHub"];
            fail.window.titlebarAppearsTransparent = TRUE;
            [fail runModal];
        }
    }
    NSString *brewPath;
    if (@available(macOS 11.0, *)) {
        int ret = 0;
        size_t size = sizeof(ret);
        sysctlbyname("sysctl.proc_translated", &ret, &size, NULL, 0);
        if (ret == 1) {
            brewPath = @"/opt/homebrew/bin/brew"; // We are running on arm64 via rosetta2
        } else {
            brewPath = @"/usr/local/bin/brew"; // We are running on x86_64 on intel
        }
    } else {
        brewPath = @"/usr/local/bin/brew";
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:brewPath]) {
        NSAlert *exiting = [[NSAlert alloc] init];
        [exiting setMessageText:@"Please install Homebrew from \"https://brew.sh\", as it is required to install some "
                                @"dependencies (usbmuxd/iproxy) but must be done manually."];
        [exiting setInformativeText:@"Once you have done this, please reopen Ramiel."];
        exiting.window.titlebarAppearsTransparent = true;
        [exiting addButtonWithTitle:@"Open brew.sh"];
        [exiting addButtonWithTitle:@"Exit"];
        NSModalResponse dlChoice = [exiting runModal];
        if (dlChoice != NSAlertFirstButtonReturn) {
            exit(0);
        } else {
            NSURL *url = [[NSURL alloc] initWithString:@"https://brew.sh"];
            [[NSWorkspace sharedWorkspace] openURL:url];
            exit(0);
        }
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/local/bin/iproxy"]) {
        [self->_neededToolsLabel
            setStringValue:@"Installing libimobiledevice via Brew... (This may take a few minutes)"];
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath:@"/bin/bash"];
        [task setArguments:@[@"-c", [NSString stringWithFormat:@"%@ install libimobiledevice", brewPath]]];
        [task launch];
        [task waitUntilExit];
        int status = [task terminationStatus];
        if (status != 0) {
            NSAlert *fail = [[NSAlert alloc] init];
            [fail setMessageText:@"Install Failed: Failed to install libimobiledevice with Brew"];
            fail.window.titlebarAppearsTransparent = TRUE;
            [fail runModal];
        }
    }
    NSString *prefix;
    if (@available(macOS 11.0, *)) {
        if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/python3"]) {
            NSAlert *devCMDAlert = [[NSAlert alloc] init];
            [devCMDAlert setInformativeText:
                             @"Error: Command Line Developer Tools are not installed. Please manually open terminal "
                             @"and run \"xcode-select --install\", then reopen Ramiel once it completes."];
            devCMDAlert.window.titlebarAppearsTransparent = TRUE;
            [devCMDAlert runModal];
            exit(0);
        }
        prefix = @"/usr/bin";
    } else {
        prefix = @"/usr/local/bin";
    }
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/bash"];
    [task setArguments:@[@"-c", [NSString stringWithFormat:@"%@/pip3 list | grep paramiko", prefix]]];
    NSPipe *out = [NSPipe pipe];
    [task setStandardOutput:out];
    [task launch];
    [task waitUntilExit];

    NSFileHandle *read = [out fileHandleForReading];
    NSData *dataRead = [read readDataToEndOfFile];
    NSString *stringRead = [[NSString alloc] initWithData:dataRead encoding:NSUTF8StringEncoding];
    if (![stringRead containsString:@"paramiko"]) {
        [RamielView otherCMD:[NSString stringWithFormat:@"%@/pip3 install --user paramiko", prefix]];
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:@"/usr/local/bin/iproxy"] &&
        [fm fileExistsAtPath:[NSString stringWithFormat:@"%@/Exploits/ipwndfu/ipwndfu",
                                                        [[NSBundle mainBundle] resourcePath]]] &&
        [fm fileExistsAtPath:[NSString
                                 stringWithFormat:@"%@/Exploits/Fugu/Fugu", [[NSBundle mainBundle] resourcePath]]] &&
        [fm fileExistsAtPath:@"/usr/local/bin/img4"] && [fm fileExistsAtPath:@"/usr/local/bin/img4tool"]) {
        [self->_neededToolsLabel setStringValue:@"Done!"];
        [self->_spinner stopAnimation:nil];
        [self->_spinner setHidden:TRUE];
        NSAlert *success = [[NSAlert alloc] init];
        [success setMessageText:@"Successfully downloaded all needed tools!"];
        [success setInformativeText:@"Ramiel will now proceed to the main page."];
        success.window.titlebarAppearsTransparent = TRUE;
        [success runModal];
        NSString *content = @"IHaveALongDriveAheadOfMe\n";
        NSData *fileContents = [content dataUsingEncoding:NSUTF8StringEncoding];
        [[NSFileManager defaultManager]
            createFileAtPath:[NSString stringWithFormat:@"%@/dlDone", [[NSBundle mainBundle] resourcePath]]
                    contents:fileContents
                  attributes:nil];
        [self.view.window.contentViewController dismissViewController:self];
    } else {
        NSAlert *fail = [[NSAlert alloc] init];
        [fail setMessageText:@"Failed to install needed tools, please reopen Ramiel and try again."];
        fail.window.titlebarAppearsTransparent = TRUE;
        [fail runModal];
        exit(0);
    }
}

- (IBAction)exitButton:(NSButton *)sender {
    exit(0);
}

@end
