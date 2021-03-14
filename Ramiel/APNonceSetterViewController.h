//
//  APNonceSetterViewController.h
//  Ramiel
//
//  Created by Matthew Pierson on 4/03/21.
//  Copyright © 2021 moski. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface APNonceSetterViewController : NSViewController

@property (weak) IBOutlet NSButton *backButton;
@property (weak) IBOutlet NSTextField *generatorEntry;
@property (weak) IBOutlet NSButton *setNonceButton;
@property (weak) IBOutlet NSTextField *label;
@property (weak) IBOutlet NSProgressIndicator *prog;

@end
