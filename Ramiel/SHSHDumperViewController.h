//
//  SHSHDumperViewController.h
//  Ramiel
//
//  Created by Matthew Pierson on 21/02/21.
//  Copyright © 2021 moski. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SHSHDumperViewController : NSViewController

@property (weak) IBOutlet NSTextField *label;
@property (weak) IBOutlet NSProgressIndicator *prog;
@property (weak) IBOutlet NSButton *dumpSHSHButton;

@end
