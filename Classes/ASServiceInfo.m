//
//  ASServiceInfo.m
//  ServiceDiscovery-ios
//
//  Created by Anton Smirnov on 01.12.15.
//  Copyright © 2015 Anton Smirnov. All rights reserved.
//

#import "ASServiceInfo.h"

@implementation ASServiceInfo

- (instancetype) initWithPort:(int)port andType:(NSString*)type andTitle:(NSString*)title andPayload:(NSData*)payload {
    if (self = [super init]) {
        _port = port;
        _type = type;
        _title = title;
        _payload = payload;
    }
    return self;
}

- (instancetype) initWithPort:(int)port andType:(NSString*)type andTitle:(NSString*)title {
    self = [self initWithPort:port andType:type andTitle:title andPayload:nil];
    return self;
}

- (instancetype) initWithPort:(int)port andType:(NSString*)type {
    self = [self initWithPort:port andType:type andTitle:nil];
    return self;
}

@end
