//
//  ASServiceInfo.h
//  ServiceDiscovery-ios
//
//  Created by Anton Smirnov on 01.12.15.
//  Copyright © 2015 Anton Smirnov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ASServiceInfo : NSObject

@property (readonly) int port;
@property (readonly) NSString *type;
@property (readonly) NSString *title;
@property (readonly) NSData *payload;

- (instancetype) initWithPort:(int)port andType:(NSString*)type andTitle:(NSString*)title andPayload:(NSData*)payload;
- (instancetype) initWithPort:(int)port andType:(NSString*)type andTitle:(NSString*)title;
- (instancetype) initWithPort:(int)port andType:(NSString*)type;

@end
