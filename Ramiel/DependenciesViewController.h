//
//  DependenciesViewController.h
//  Ramiel
//
//  Created by Matthew Pierson on 12/03/21.
//  Copyright © 2021 moski. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface DependenciesViewController : NSViewController

@property (weak) IBOutlet NSTextField *topLabel;
@property (weak) IBOutlet NSTextField *neededToolsLabel;
@property (weak) IBOutlet NSButton *goButton;
@property (weak) IBOutlet NSProgressIndicator *spinner;

@end
