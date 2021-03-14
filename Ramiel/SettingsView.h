//
//  SettingsView.h
//  Ramiel
//
//  Created by Matthew Pierson on 5/09/20.
//  Copyright © 2020 moski. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SettingsView : NSViewController

@property (weak) IBOutlet NSTextField *titleLabel;
@property (weak) IBOutlet NSButton *bootargsCheck;
@property (weak) IBOutlet NSButton *bootlogoCheck;
@property (weak) IBOutlet NSButton *bootlogoButton;
@property (weak) IBOutlet NSButton *bootargsButton;
@property (weak) IBOutlet NSButton *dualbootCheck;
@property (weak) IBOutlet NSButton *dualbootButton;
@property (weak) IBOutlet NSButton *ignoreIPSWVerification;
@property (weak) IBOutlet NSButton *apnonceButton;
@property (weak) IBOutlet NSButton *toggleDebugMode;
@property (weak) IBOutlet NSButton *amfiToggle;
@property (weak) IBOutlet NSButton *amsdToggle;
@property (weak) IBOutlet NSButton *dumpSHSH;
@property (weak) IBOutlet NSButton *exitRecMode;
@property (weak) IBOutlet NSButton *showSHSH;
@property (weak) IBOutlet NSButton *localSHSHButton;

@end
