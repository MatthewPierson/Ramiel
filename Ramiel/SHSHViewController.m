//
//  SHSHViewController.m
//  Ramiel
//
//  Created by Matthew Pierson on 2/01/21.
//  Copyright © 2021 moski. All rights reserved.
//

#import "SHSHViewController.h"
#import "Device.h"
#import "RamielView.h"

@implementation SHSHViewController

NSMutableArray *finalSHSHHost;
NSMutableArray *finalConan;
NSString *ecid;
NSComboBox *comboBoxList;
int check;
Device *d;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);
    [self->_label setStringValue:@"Checking \"shsh.host\" for SHSH..."];
    [self->_label setAlignment:NSTextAlignmentCenter];
    [self->_prog startAnimation:NULL];
    d = [RamielView getConnectedDeviceInfo];
    [d resetConnection];
    [d setIRECVDeviceInfo:[d getIRECVClient]];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        sleep(1);
        [self shshDownload];
    });
}

- (IBAction)downloadButtonHandler:(NSButton *)sender {
    if (check == 0) {
        if (comboBoxList.indexOfSelectedItem == -1) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [RamielView errorHandler:@"Invalid choice":@"N/A":@"N/A"];
            });

            return;
        }
        NSString *pickedURL =
            [NSString stringWithFormat:@"https://shsh.host/%@//%@", ecid, comboBoxList.objectValueOfSelectedItem];

        // Get contents of this new URL, then get link to SHSH file :)
        pickedURL =
            [pickedURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSURL *shshPage = [NSURL URLWithString:pickedURL];
        NSURLRequest *shshRequest = [NSURLRequest requestWithURL:shshPage];
        NSData *shshData = [NSURLConnection sendSynchronousRequest:shshRequest returningResponse:nil error:nil];
        if (shshData != NULL) {

            // Add check here for different generators, some people have multiple
            // shsh files with different generators
            NSString *dataString = [[NSString alloc] initWithData:shshData encoding:NSASCIIStringEncoding];
            NSArray *shshFiles = [NSArray arrayWithArray:[dataString componentsSeparatedByString:@"<td><a href = '"]];
            NSMutableArray *shshList = [[NSMutableArray alloc] init];
            NSMutableArray *generatorList = [[NSMutableArray alloc] init];
            for (int i = 1; i < shshFiles.count; i++) {
                NSString *te = [shshFiles[i] componentsSeparatedByString:@"'>"][0];
                NSString *ge =
                    [NSString stringWithFormat:@"0x%@", [[shshFiles[i] componentsSeparatedByString:@"<td>0x"][1]
                                                            componentsSeparatedByString:@"</td>"][0]];
                if (![generatorList containsObject:ge]) { // Ensure that only new entries are added, no need to show
                                                          // multiples of the same generator
                    [shshList addObject:te];
                    [generatorList addObject:ge];
                }
            }
            NSString *shshDownloadURL;
            if (shshList.count > 1) {
                NSComboBox *comboBox = [[NSComboBox alloc] initWithFrame:NSMakeRect(0, 0, 175, 30)];
                for (int i = 0; i < shshList.count; i++) {
                    [comboBox addItemWithObjectValue:generatorList[i]];
                }
                [comboBox setEditable:NO];
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"Download"];
                [alert setMessageText:@"Please pick the generator you would like to download:"];
                [alert setAccessoryView:comboBox];
                alert.window.titlebarAppearsTransparent = TRUE;
                [alert runModal];

                while (comboBox.indexOfSelectedItem == -1) {
                    [alert runModal];
                }
                shshDownloadURL = shshList[comboBox.indexOfSelectedItem];
            } else {
                shshDownloadURL = shshList[0];
            }

            shshDownloadURL = [shshDownloadURL
                stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
            NSURL *url = [NSURL URLWithString:shshDownloadURL];
            NSData *urlData = [NSData dataWithContentsOfURL:url];
            if (urlData) {
                NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES);
                NSString *generator = [NSString stringWithUTF8String:[urlData bytes]];
                NSString *savePath;
                if (![generator containsString:@"<string>0x"]) {
                    generator = @"No Generator Found";
                    savePath = [NSString
                        stringWithFormat:@"%@/%@-%@.shsh", paths[0], ecid, comboBoxList.objectValueOfSelectedItem];
                } else {
                    generator = [generator componentsSeparatedByString:@"<string>0x"][1];
                    generator = [generator componentsSeparatedByString:@"</string>"][0];
                    generator = [NSString stringWithFormat:@"0x%@", generator];
                    savePath = [NSString stringWithFormat:@"%@/%@-%@-%@.shsh", paths[0], ecid, generator,
                                                          comboBoxList.objectValueOfSelectedItem];
                }

                [urlData writeToFile:savePath atomically:YES];
                if ([[NSFileManager defaultManager] fileExistsAtPath:savePath]) {
                    NSAlert *success = [[NSAlert alloc] init];
                    [success setMessageText:@"Successfully saved SHSH!"];
                    [success
                        setInformativeText:
                            [NSString stringWithFormat:@"SHSH saved to: \"%@\"\nThe generator for your SHSH is \"%@\"",
                                                       savePath, generator]];
                    success.window.titlebarAppearsTransparent = true;
                    [success runModal];
                } else {
                    NSAlert *failed = [[NSAlert alloc] init];
                    [failed setMessageText:@"Failed to saved SHSH!"];
                    [failed
                        setInformativeText:@"Please try again, if the issue persists then open an issue on GitHub."];
                    failed.window.titlebarAppearsTransparent = true;
                    [failed runModal];
                }
            }
        }
    } else {

        if (comboBoxList.indexOfSelectedItem == -1) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [RamielView errorHandler:@"Invalid choice":@"N/A":@"N/A"];
            });
            return;
        }

        NSString *pickedURL = [NSString stringWithFormat:@"https://stor.tsssaver.1conan.com/shsh/%@/%@/noapnonce/",
                                                         ecid, comboBoxList.objectValueOfSelectedItem];

        // Get contents of this new URL, then get link to SHSH file :)
        pickedURL =
            [pickedURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSURL *shshPage = [NSURL URLWithString:pickedURL];

        NSURLRequest *shshRequest = [NSURLRequest requestWithURL:shshPage];
        NSData *shshData = [NSURLConnection sendSynchronousRequest:shshRequest returningResponse:nil error:nil];
        if (shshData != NULL) {

            // Add check here for different generators, some people have multiple
            // shsh files with different generators
            NSString *dataString = [[NSString alloc] initWithData:shshData encoding:NSASCIIStringEncoding];
            if ([dataString containsString:@"404"]) { // Some pages have
                                                      // generator-0x1111111111111111
                                                      // instead of no-apnonce :/
                pickedURL = [NSString
                    stringWithFormat:@"https://stor.tsssaver.1conan.com/shsh/%@/%@/generator-0x1111111111111111/", ecid,
                                     comboBoxList.objectValueOfSelectedItem];
                pickedURL = [pickedURL
                    stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
                shshPage = [NSURL URLWithString:pickedURL];

                shshRequest = [NSURLRequest requestWithURL:shshPage];
                shshData = [NSURLConnection sendSynchronousRequest:shshRequest returningResponse:nil error:nil];
                dataString = [[NSString alloc] initWithData:shshData encoding:NSASCIIStringEncoding];
            }
            NSString *tempString = [dataString
                componentsSeparatedByString:@"Parent directory/</a></td><td class=\"size\">-</td><td "
                                            @"class=\"date\">-</td></tr><tr><td class=\"link\"><a href=\""][1];
            NSString *shshDownloadURL = [tempString componentsSeparatedByString:@"\" title="][0];
            if ([pickedURL containsString:@"generator-0x1111111111111111"]) {
                shshDownloadURL = [NSString
                    stringWithFormat:@"https://stor.tsssaver.1conan.com/shsh/%@/%@/generator-0x1111111111111111/%@",
                                     ecid, comboBoxList.objectValueOfSelectedItem, shshDownloadURL];
            } else {
                shshDownloadURL =
                    [NSString stringWithFormat:@"https://stor.tsssaver.1conan.com/shsh/%@/%@/noapnonce/%@", ecid,
                                               comboBoxList.objectValueOfSelectedItem, shshDownloadURL];
            }

            shshDownloadURL = [shshDownloadURL
                stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
            NSURL *url = [NSURL URLWithString:shshDownloadURL];
            NSData *urlData = [NSData dataWithContentsOfURL:url];
            if (urlData) {
                NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES);
                NSString *savePath = [NSString
                    stringWithFormat:@"%@/%@-%@.shsh", paths[0], ecid, comboBoxList.objectValueOfSelectedItem];
                [urlData writeToFile:savePath atomically:YES];
                NSString *generator = [NSString stringWithUTF8String:[urlData bytes]];
                if (![generator containsString:@"<string>0x"]) {
                    generator = @"No Generator Found";
                } else {
                    generator = [generator componentsSeparatedByString:@"<string>0x"][1];
                    generator = [generator componentsSeparatedByString:@"</string>"][0];
                    generator = [NSString stringWithFormat:@"0x%@", generator];
                }
                if ([[NSFileManager defaultManager] fileExistsAtPath:savePath]) {
                    NSAlert *success = [[NSAlert alloc] init];
                    [success setMessageText:@"Successfully saved SHSH!"];
                    [success
                        setInformativeText:
                            [NSString stringWithFormat:@"SHSH saved to: \"%@\"\nThe generator for your SHSH is \"%@\"",
                                                       savePath, generator]];
                    success.window.titlebarAppearsTransparent = true;
                    [success runModal];
                } else {
                    NSAlert *failed = [[NSAlert alloc] init];
                    [failed setMessageText:@"Failed to saved SHSH!"];
                    [failed
                        setInformativeText:@"Please try again, if the issue persists then open an issue on GitHub."];
                    failed.window.titlebarAppearsTransparent = true;
                    [failed runModal];
                }
            }
        }
    }
    [self->_label setStringValue:@"Please select another SHSH file to download,\nor press Close to return to Settings"];
}

- (IBAction)shshHostButtonHandle:(NSButton *)sender {

    [self->_label setStringValue:@"Please pick the iOS version for the SHSH you wish to download:"];
    [self->_shshHostButton setHidden:TRUE];
    [self->_conanButton setHidden:TRUE];
    [self->_shshHostButton setEnabled:FALSE];
    [self->_conanButton setEnabled:FALSE];

    NSArray *orderedSHSHHost = [[NSOrderedSet orderedSetWithArray:finalSHSHHost] array];
    comboBoxList = [[NSComboBox alloc] initWithFrame:NSMakeRect(0, 0, 100, 30)];
    for (int i = 0; i < [orderedSHSHHost count]; ++i) {
        [comboBoxList addItemWithObjectValue:[orderedSHSHHost objectAtIndex:i]];
    }
    comboBoxList.editable = false;
    [comboBoxList setPlaceholderString:@"Select here"];
    [comboBoxList setFrame:CGRectMake((self.view.frame.size.width / 2) - (comboBoxList.frame.size.width / 2),
                                      (self.view.frame.size.height / 2) - 40, comboBoxList.frame.size.width,
                                      comboBoxList.frame.size.height)];
    [self.view addSubview:comboBoxList];
    NSLog(@"%ld", (long)comboBoxList.indexOfSelectedItem);
    [self->_download setHidden:FALSE];
    [self->_download setEnabled:TRUE];
    check = 0;
}

- (IBAction)conanButtonHandle:(NSButton *)sender {

    [self->_label setStringValue:@"Please pick the iOS version for the SHSH you wish to download:"];
    [self->_shshHostButton setHidden:TRUE];
    [self->_conanButton setHidden:TRUE];
    [self->_shshHostButton setEnabled:FALSE];
    [self->_conanButton setEnabled:FALSE];

    NSArray *orderedConan = [[NSOrderedSet orderedSetWithArray:finalConan] array];
    comboBoxList = [[NSComboBox alloc] initWithFrame:NSMakeRect(0, 0, 100, 30)];
    for (int i = 0; i < [orderedConan count]; ++i) {
        [comboBoxList addItemWithObjectValue:[orderedConan objectAtIndex:i]];
    }
    comboBoxList.editable = false;
    [comboBoxList setPlaceholderString:@"Select here"];
    [comboBoxList setFrame:CGRectMake((self.view.frame.size.width / 2) - (comboBoxList.frame.size.width / 2),
                                      (self.view.frame.size.height / 2) - 40, comboBoxList.frame.size.width,
                                      comboBoxList.frame.size.height)];
    [self.view addSubview:comboBoxList];
    NSLog(@"%ld", (long)comboBoxList.indexOfSelectedItem);
    [self->_download setHidden:FALSE];
    [self->_download setEnabled:TRUE];
    check = 1;
}

- (void)shshDownload {
    ecid = [NSString stringWithFormat:@"%llu", [d getEcid]];
    NSURL *shshHostURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://shsh.host/%@/", ecid]];

    NSURLRequest *shshHostRequest = [NSURLRequest requestWithURL:shshHostURL];
    NSData *shshHostData = [NSURLConnection sendSynchronousRequest:shshHostRequest returningResponse:nil error:nil];
    finalSHSHHost = [[NSMutableArray alloc] init];
    if (shshHostData != NULL) {

        NSString *dataString = [[NSString alloc] initWithData:shshHostData encoding:NSASCIIStringEncoding];
        if ([dataString containsString:@"<tr>"]) {
            NSArray *shshHostArray = [dataString componentsSeparatedByString:@"<td>"];
            for (int i = 0; i < shshHostArray.count; i++) {
                if ([shshHostArray[i] containsString:[NSString stringWithFormat:@"%@/", shshHostURL]]) {
                    NSString *tempString = [shshHostArray[i] componentsSeparatedByString:@"<a href = '"][1];
                    tempString = [tempString componentsSeparatedByString:@"'>"][0];
                    tempString = [tempString
                        componentsSeparatedByString:[NSString stringWithFormat:@"https://shsh.host/%@//", ecid]][1];
                    [finalSHSHHost addObject:tempString];
                }
            }
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_label setStringValue:@"Checking \"tsssaver.1conan.com\" for SHSH..."];
    });
    NSURL *conanURL =
        [NSURL URLWithString:[NSString stringWithFormat:@"https://stor.tsssaver.1conan.com/shsh/%@/", ecid]];

    NSURLRequest *conanRequest = [NSURLRequest requestWithURL:conanURL];
    NSData *conanData = [NSURLConnection sendSynchronousRequest:conanRequest returningResponse:nil error:nil];
    finalConan = [[NSMutableArray alloc] init];
    if (conanData != NULL) {

        NSString *dataString = [[NSString alloc] initWithData:conanData encoding:NSASCIIStringEncoding];
        if ([dataString containsString:@"class=\"link\""]) {
            NSArray *conanArray = [dataString componentsSeparatedByString:@"<tr><td class=\"link\"><a href=\""];
            for (int i = 0; i < conanArray.count; i++) {
                if ([conanArray[i] containsString:@"/"]) {
                    NSString *tempString = [conanArray[i] componentsSeparatedByString:@"/\" title=\""][0];
                    if (tempString.length < 9) {
                        [finalConan addObject:tempString];
                    }
                }
            }
        }
    }

    if ([finalConan count] == 0 && [finalSHSHHost count] == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_label setStringValue:@"Failed to find any valid SHSH..."];
        });
        return;
    }

    check = 0;

    if ([finalConan count] > 0 && [finalSHSHHost count] > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_label setStringValue:
                              @"Found SHSH on both shsh.host and 1conan.\nWhich site would you like to download from?"];
            [self->_conanButton setHidden:FALSE];
            [self->_conanButton setEnabled:TRUE];
            [self->_shshHostButton setHidden:FALSE];
            [self->_shshHostButton setEnabled:TRUE];
        });

    } else if ([finalConan count] > 0 && [finalSHSHHost count] == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self conanButtonHandle:NULL];
        });
    } else if ([finalConan count] == 0 && [finalSHSHHost count] > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self shshHostButtonHandle:NULL];
        });
    }
}

- (IBAction)backButton:(NSButton *)sender {
    d = NULL;
    [self.view.window.contentViewController dismissViewController:self];
}

@end
