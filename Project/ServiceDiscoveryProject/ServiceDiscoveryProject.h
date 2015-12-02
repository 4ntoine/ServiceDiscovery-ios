//
//  ServiceDiscoveryProject.h
//  ServiceDiscoveryProject
//
//  Created by Anton Smirnov on 02.12.15.
//  Copyright © 2015 Anton Smirnov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ASServiceLocator.h"

@interface ServiceDiscoveryProject : NSObject <ASServiceLocatorDelegate>

- (instancetype) initWithGroup:(NSString*)group andPort:(int)port;

- (void) discover;
- (BOOL) isFinished;

@end
