//
//  CreditsViewController.m
//  Ramiel
//
//  Created by Matthew Pierson on 7/03/21.
//  Copyright © 2021 moski. All rights reserved.
//

#import "CreditsViewController.h"

@implementation CreditsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);
}
- (IBAction)backButton:(id)sender {
    [self.view.window.contentViewController dismissViewController:self];
}

@end
