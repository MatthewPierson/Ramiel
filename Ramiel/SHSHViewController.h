//
//  SHSHViewController.h
//  Ramiel
//
//  Created by Matthew Pierson on 2/01/21.
//  Copyright © 2021 moski. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SHSHViewController : NSViewController

@property (weak) IBOutlet NSTextField *label;
@property (weak) IBOutlet NSProgressIndicator *prog;
@property (weak) IBOutlet NSButton *conanButton;
@property (weak) IBOutlet NSButton *shshHostButton;
@property (weak) IBOutlet NSButton *download;

@end
