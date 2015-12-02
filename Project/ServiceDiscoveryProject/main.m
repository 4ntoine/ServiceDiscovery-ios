//
//  main.m
//  ServiceDiscoveryProject
//
//  Created by Anton Smirnov on 02.12.15.
//  Copyright © 2015 Anton Smirnov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ServiceDiscoveryProject.h"

#define MULTICAST_GROUP @"239.255.255.240"
#define MULTICAST_PORT 4470

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        ServiceDiscoveryProject *project = [[ServiceDiscoveryProject alloc] initWithGroup:MULTICAST_GROUP
                                                                                  andPort:MULTICAST_PORT];
        [project discover];
        
        // wait until finished
        while (![project isFinished]) {
            [NSThread sleepForTimeInterval:0.1];
        }
    }
    return 0;
}
