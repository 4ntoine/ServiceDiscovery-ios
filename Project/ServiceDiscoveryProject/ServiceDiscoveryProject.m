//
//  ServiceDiscoveryProject.m
//  ServiceDiscoveryProject
//
//  Created by Anton Smirnov on 02.12.15.
//  Copyright © 2015 Anton Smirnov. All rights reserved.
//

#import "ServiceDiscoveryProject.h"
#import "ASServiceInfo.h"


#define RESPONSE_PORT (MULTICAST_PORT + 1)

#define SERVICE_TYPE @"MyServiceType1"
#define SERVICE_PORT 1204
#define SERVICE_TITLE @"Hello world"

@implementation ServiceDiscoveryProject
{
    ASServiceLocator *_locator;
    ASServiceInfo *_foundServiceInfo;
    
    BOOL _finished;
}

- (BOOL) isFinished {
    return _finished;
}

- (instancetype) initWithGroup:(NSString*)group andPort:(int)port {
    if (self = [super init]) {
        _locator = [[ASServiceLocator alloc] initWithMulticastGroup:group
                                                   andMulticastPort:port
                                                    andResponsePort:(port + 1)
                                                        andDelegate:self];
        _locator.mode = ASMODE_UDP;
        _locator.responseTimeoutMillis = 3000; // 3s
        _locator.delegateQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        _finished = NO;
    }
    return self;
}

- (void) discover {
    [_locator discover:SERVICE_TYPE];
}

#pragma mark - Locator delegate

- (void) didStartDiscovery {
    NSLog(@"Started discovery");
}

- (void) didFinishDiscovery {
    _finished = YES;
    NSLog(@"Finished discovery");
}

- (void) didDiscoverService:(ASServiceInfo*)serviceInfo onHost:(NSString*)host {
    NSLog(@"Discovered service with title \"%@\" on %@:%i", serviceInfo.title, host, serviceInfo.port);
    
    _foundServiceInfo = serviceInfo;
}

- (void) didFailWithError:(NSError*)error {
    NSLog(@"Failed with error:%@", error);
}

@end
