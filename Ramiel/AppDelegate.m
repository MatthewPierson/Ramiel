//
//  AppDelegate.m
//  Ramiel
//
//  Created by Matthew Pierson on 9/08/20.
//  Copyright © 2020 moski. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    [[NSApplication sharedApplication] keyWindow].alphaValue = 0.99;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:
    (NSApplication *)application { // Make app fully close when exit is pressed
    // Can also have a popup show here if I'd like :) Might come in handy sometime
    return YES;
}

@end
