//
//  ASServicePublisher.h
//  ServiceDiscovery-ios
//
//  Created by Anton Smirnov on 01.12.15.
//  Copyright © 2015 Anton Smirnov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ASMode.h"
#import "GCDAsyncSocket.h"
#import "GCDAsyncUdpSocket.h"

@class ASServiceInfo;

#define PUBLISHER_ERROR_PARSE @"ParseError"

// -------------------------------------------------------------------------------------------------

@protocol ASServicePublisherDelegate

- (void) didStartPublish;
- (void) didFinishPublish;
- (BOOL) acceptServiceRequestForHost:(NSString*)host
                            withType:(NSString*)type
                            withMode:(ASMode)mode; // return true to accept request
- (void) didNotFindServiceForHost:(NSString*)host
                         withType:(NSString*)type
                         withMode:(ASMode)mode; // no service by type found in registered services
- (void) didSendServiceResponse:(NSString*)host
                    serviceInfo:(ASServiceInfo*)serviceInfo;
- (void) didFailWithError:(NSError*)error;

@end

// -------------------------------------------------------------------------------------------------

@interface ASServicePublisher : NSObject <GCDAsyncUdpSocketDelegate>

@property id<ASServicePublisherDelegate> delegate;
@property dispatch_queue_t delegateQueue;

@property (readonly) NSString *multicastGroup;
@property (readonly) int multicastPort;

- (instancetype) initWithMulticastGroup:(NSString*)multicastGroup
                                andPort:(int)multicastPort
                            andDelegate:(id<ASServicePublisherDelegate>)delegate;

- (void) registerService:(ASServiceInfo*)serviceInfo;
- (void) unregisterService:(ASServiceInfo*)serviceInfo;

- (BOOL) start;
- (void) stop;
- (BOOL) isStarted;

@end

// -------------------------------------------------------------------------------------------------
