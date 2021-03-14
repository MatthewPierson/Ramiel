//
//  Device.m
//  Ramiel
//
//  Created by Matthew Pierson on 9/02/21.
//  Copyright © 2021 moski. All rights reserved.
//

#import "Device.h"
#import "RamielView.h"

@implementation Device
// Init //
- (id)initDeviceID {
    self = [super self];
    if (self) {

        irecv_client_t client = NULL;

        while (TRUE) {
            irecv_error_t err = irecv_open_with_ecid(&client, (uint64_t)[self getEcid]);
            if (err == IRECV_E_UNSUPPORTED) {
                fprintf(stderr, "ERROR: %s\n", irecv_strerror(err));
                return NULL;
            } else if (err != IRECV_E_SUCCESS)
                sleep(1);
            else
                break;
        }

        [self setClient:client];
        if (self.getIRECVClient != NULL) {
            irecv_device_t d = NULL;
            [self setIRECVDevice:d];
            if (self.getIRECVDevice != NULL) {
                [self setModel:[NSString stringWithFormat:@"%s", self.getIRECVDevice->product_type]];
                [self setHardware_model:[NSString stringWithFormat:@"%s", self.getIRECVDevice->hardware_model]];
                [self setIRECVDeviceInfo:(self.getIRECVClient)];
                [self setCpid:[NSString stringWithFormat:@"0x%04x", self.getIRECVDeviceInfo.cpid]];
                if (self.getIRECVDeviceInfo.bdid > 9) {
                    [self setBdid:[NSString stringWithFormat:@"0x%u", self.getIRECVDeviceInfo.bdid]];
                } else {
                    [self setBdid:[NSString stringWithFormat:@"0x0%u", self.getIRECVDeviceInfo.bdid]];
                }
                [self setSrtg:[NSString stringWithFormat:@"%s", self.getIRECVDeviceInfo.srtg]];
                [self setSerial_string:[NSString stringWithFormat:@"%s", self.getIRECVDeviceInfo.serial_string]];
                [self setEcid:self.getIRECVDeviceInfo.ecid];
                [self setClosedState:0];
            }
        }
    }
    return self;
}
// Getters //
- (NSString *)getModel {
    return self.model;
};
- (NSString *)getCpid {
    return self.cpid;
};
- (NSString *)getBdid {
    return self.bdid;
};
- (NSString *)getHardware_model {
    return self.hardware_model;
};
- (NSString *)getSrtg {
    return self.srtg;
};
- (NSString *)getSerial_string {
    return self.serial_string;
};
- (uint64_t)getEcid {
    return self.ecid;
};
- (int)getClosedState {
    return self.closed;
}
- (irecv_client_t)getIRECVClient {
    return (self.client);
};
- (irecv_error_t)getIRECVError {
    return self.error;
};
- (irecv_device_t)getIRECVDevice {
    return (self.device);
};
- (struct irecv_device_info)getIRECVDeviceInfo {
    return self.device_info;
};
// Setters //
- (void)setIRECVClient:(irecv_client_t)client {
    if (client == NULL) {
        self.client = NULL;
    } else {
        self.client = client;
        [self setClosedState:0];
    }
}
- (void)setIRECVError:(irecv_error_t)error {
    self.error = error;
}
- (void)setIRECVDevice:(irecv_device_t)device {
    irecv_devices_get_device_by_client((self.getIRECVClient), &device);
    self.device = *(&device);
}
- (void)setIRECVDeviceInfo:(irecv_client_t)client {
    self.device_info = *(irecv_get_device_info(self.getIRECVClient));
}
- (void)setClosedState:(int)closedState {
    self.closed = closedState;
    if ([RamielView debugCheck])
        NSLog(@"Setting closedState to: %d", closedState);
}
// Interactive Functions //
- (irecv_error_t)sendImage:(NSString *)filePath {
    irecv_error_t error;

    if (filePath == NULL) { // No point trying to boot a file that doesn't exist...
        return 1;
    }
    if ([RamielView debugCheck])
        NSLog(@"Sending file to device: %@", filePath);

    const char *charPath = [filePath UTF8String];
    if ([self getIRECVClient] == 0) {
        NSLog(@"Failed to send %@ image", filePath);
        return IRECV_E_NO_DEVICE;
    }
    irecv_event_subscribe([self getIRECVClient], IRECV_PROGRESS, NULL, NULL);
    error = irecv_send_file([self getIRECVClient], charPath, 1);

    [self resetConnection];

    return error;
}
- (irecv_error_t)sendCMD:(NSString *)cmd {
    irecv_error_t error;
    if ([RamielView debugCheck])
        NSLog(@"Sending command to device: %@", cmd);
    const char *charCMD = [cmd UTF8String];
    if ([self getIRECVClient] == 0) {
        NSLog(@"Failed to send %@ commmand", cmd);
        return IRECV_E_NO_DEVICE;
    }
    error = irecv_send_command([self getIRECVClient], charCMD);

    [self resetConnection];

    return error;
}
- (irecv_error_t)resetConnection {
    irecv_error_t error = 0;
    [self closeDeviceConnection];

    int i;
    for (i = 0; i <= 5; i++) {
        irecv_client_t temp = NULL;
        error = irecv_open_with_ecid(&temp, (uint64_t)[self getEcid]);
        [self setIRECVClient:temp];
        if (error == IRECV_E_UNSUPPORTED) {
            fprintf(stderr, "ERROR: %s\n", irecv_strerror(error));
            break;
        } else if (error != IRECV_E_SUCCESS)
            sleep(1);
        else
            break;
    }
    return error;
}
// Other Functions //
- (void)reclaimDeviceClient {
    // TODO: Finish
    NSLog(@"TODO: Make this function");
}
- (void)closeDeviceConnection {
    if (self.getClosedState == 0) {
        irecv_close(self.getIRECVClient);
        [self setClosedState:1];
    }
}
- (int)runCheckm8 {
    int ret = 0;
    NSString *binaryName, *flags, *pwnCheck, *cpid;
    cpid = [self getCpid];
    if ([cpid containsString:@"7000"]) {
        binaryName = @"eclipsa7000";
        flags = @"";
        pwnCheck = @"Now you can boot untrusted images.";
    } else if ([cpid containsString:@"7001"]) {
        binaryName = @"eclipsa7001";
        flags = @"";
        pwnCheck = @"Now you can boot untrusted images.";
    } else if ([cpid containsString:@"8000"]) {
        binaryName = @"eclipsa8000";
        flags = @"";
        pwnCheck = @"Now you can boot untrusted images.";
    } else if ([cpid containsString:@"8003"]) {
        binaryName = @"eclipsa8003";
        flags = @"";
        pwnCheck = @"Now you can boot untrusted images.";
    } else if ([cpid containsString:@"8960"] || [cpid containsString:@"8965"]) {
        binaryName = @"iPwnder32";
        flags = @"-p";
        pwnCheck = @"Device is now in pwned DFU mode!";
    } else if ([cpid containsString:@"8010"] || [cpid containsString:@"8011"]) {
        binaryName = @"Fugu/Fugu";
        flags = @"rmsigchks";
        pwnCheck = @"-> You can now send an iBSS with broken signature";
    } else if ([cpid containsString:@"8015"]) {
        binaryName = @"ipwndfu";
        flags = @"-p";
        pwnCheck = @"Device is now in pwned DFU Mode.";
    } else {
        NSLog(@"Will add supprt for CPID:%@ soon!", cpid);
        return 1;
    }

    [self closeDeviceConnection];
    NSTask *exploitTask = [[NSTask alloc] init];
    [exploitTask setLaunchPath:@"/bin/bash"];
    if ([cpid containsString:@"8015"]) {
        [exploitTask setArguments:@[
            @"-c", [NSString stringWithFormat:@"cd %@/Exploits/ipwndfu && ./%@ %@",
                                              [[NSBundle mainBundle] resourcePath], binaryName, flags]
        ]];
    } else {

        [exploitTask setArguments:@[
            @"-c",
            [NSString stringWithFormat:@"%@/Exploits/%@ %@", [[NSBundle mainBundle] resourcePath], binaryName, flags]
        ]];
    }
    NSPipe *pipe = [NSPipe pipe];
    [exploitTask setStandardOutput:pipe];
    NSFileHandle *file = [pipe fileHandleForReading];
    [exploitTask launch];

    NSData *data = [file readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    if ([cpid containsString:@"8015"] && [output containsString:pwnCheck]) {
        flags = @"--patch";
        pwnCheck = @"and debug the next boot stages";
        NSTask *exploitTask2 = [[NSTask alloc] init];
        [exploitTask2 setLaunchPath:@"/bin/bash"];
        [exploitTask2 setArguments:@[
            @"-c", [NSString stringWithFormat:@"cd %@/Exploits/ipwndfu && ./%@ %@",
                                              [[NSBundle mainBundle] resourcePath], binaryName, flags]
        ]];
        NSPipe *pipe2 = [NSPipe pipe];
        [exploitTask2 setStandardOutput:pipe2];
        NSFileHandle *file2 = [pipe2 fileHandleForReading];
        [exploitTask2 launch];
        NSData *data2 = [file2 readDataToEndOfFile];
        output = [[NSString alloc] initWithData:data2 encoding:NSUTF8StringEncoding];
    }
    irecv_client_t temp = NULL;
    irecv_open_with_ecid_and_attempts(&temp, (uint64_t)[self getEcid], 5);
    [self setIRECVClient:temp];
    if ([output containsString:pwnCheck]) {
        NSAlert *checkWorked = [[NSAlert alloc] init];
        [checkWorked setMessageText:@"Successfully exploited device!"];
        [checkWorked setInformativeText:@"Device is now ready to accept custom images"];
        checkWorked.window.titlebarAppearsTransparent = true;
        [checkWorked runModal];
        if ([cpid containsString:@"8960"] || [cpid containsString:@"8965"]) {
            irecv_reset([self getIRECVClient]);
            [self closeDeviceConnection];
            [self setClient:NULL];
            usleep(1000);
            irecv_client_t temp = NULL;
            irecv_open_with_ecid_and_attempts(&temp, (uint64_t)[self getEcid], 5);
            [self setIRECVClient:temp];
        }
        return ret;
    } else {
        [RamielView errorHandler:@"Failed to exploit device":@"Please reboot device and re-enter DFU mode.":output];
        return 1;
    }
}

- (void)teardown {
    [self setBdid:NULL];
    [self setCpid:NULL];
    [self setEcid:(uint64_t)NULL];
    [self setSrtg:NULL];
    [self setModel:NULL];
}

+ (instancetype)initDevice {
    return [[Device alloc] initDeviceID];
}

@end
