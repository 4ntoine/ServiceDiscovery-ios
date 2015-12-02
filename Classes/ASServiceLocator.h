//
//  ASServiceLocator.h
//  ServiceDiscovery-ios
//
//  Created by Anton Smirnov on 02.12.15.
//  Copyright © 2015 Anton Smirnov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ASMode.h"
#import "GCDAsyncSocket.h"
#import "GCDAsyncUdpSocket.h"

#define LOCATOR_ERROR_PARSE @"ParseError"

// -------------------------------------------------------------------------------------------------

@class ASServiceInfo;

// -------------------------------------------------------------------------------------------------

@protocol ASServiceLocatorDelegate

- (void) didStartDiscovery;
- (void) didFinishDiscovery;
- (void) didDiscoverService:(ASServiceInfo*)sericeInfo onHost:(NSString*)host;
- (void) didFailWithError:(NSError*)error;

@end

// -------------------------------------------------------------------------------------------------

@interface ASServiceLocator : NSObject <GCDAsyncUdpSocketDelegate,GCDAsyncSocketDelegate>

@property id<ASServiceLocatorDelegate> delegate;
@property dispatch_queue_t delegateQueue;

@property int responsePort;
@property int responseTimeoutMillis;
@property ASMode mode;

- (instancetype) initWithMulticastGroup:(NSString*)multicastGroup
                       andMulticastPort:(int)multicastPort
                        andResponsePort:(int)responsePort
                            andDelegate:(id<ASServiceLocatorDelegate>)delegate;

- (void) discover:(NSString*)type;
- (BOOL) isDiscovering;
- (BOOL) cancelDescovery;

@end
