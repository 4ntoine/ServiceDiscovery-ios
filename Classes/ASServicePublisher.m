//
//  ASServicePublisher.m
//  ServiceDiscovery-ios
//
//  Created by Anton Smirnov on 01.12.15.
//  Copyright © 2015 Anton Smirnov. All rights reserved.
//

#import "ASServicePublisher.h"
#import "ASServiceInfo.h"
#import "GCDAsyncUdpSocket.h"
#import "GCDAsyncSocket.h"
#import "Discovery.pb.h"
#import "ASMode.h"

@implementation ASServicePublisher
{
    NSMutableArray<ASServiceInfo*> *_services;
    BOOL _started;
    GCDAsyncUdpSocket *_socket;
}

- (instancetype) initWithMulticastGroup:(NSString*)multicastGroup
                                andPort:(int)multicastPort
                            andDelegate:(id<ASServicePublisherDelegate>)delegate {
    if (self = [super init]) {
        _multicastGroup = multicastGroup;
        _multicastPort = multicastPort;
        _delegate = delegate;
        
        _services = [[NSMutableArray alloc] init];
        _started = NO;
        _delegateQueue = dispatch_get_main_queue(); // by default main queue is used
    }
    return self;
}

- (void) registerService:(ASServiceInfo*)serviceInfo {
    [_services addObject:serviceInfo];
}

- (void) unregisterService:(ASServiceInfo*)serviceInfo {
    [_services removeObject:serviceInfo];
}

- (BOOL) startListening {
    _socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self
                                            delegateQueue:_delegateQueue];
    
    NSError *error;
    if (![_socket bindToPort:_multicastPort error:&error]) {
        NSLog(@"Failed to bind to port %i: %@", _multicastPort, error);
        [_socket close];
        
        [_delegate didFailWithError:error];
        return NO;
    }
    
    if (![_socket joinMulticastGroup:_multicastGroup error:&error]) {
        NSLog(@"Failed to join multicast group %@: %@", _multicastGroup, error);
        [_socket close];
        
        [_delegate didFailWithError:error];
        return NO;
    }
    
    if (![_socket beginReceiving:&error]) {
        NSLog(@"Failed to begin receiving: %@", error);
        [_socket close];
        
        [_delegate didFailWithError:error];
        return NO;
    }
    
    // event 'started'
    dispatch_async(_delegateQueue, ^{
        NSLog(@"Started to publish");
        [_delegate didStartPublish];
    });
    
    return YES;
}

- (void) stopListening {
    [_socket close];
    
    // event 'started'
    dispatch_async(_delegateQueue, ^{
        NSLog(@"Stopped to publish");
        [_delegate didFinishPublish];
    });
}

- (BOOL) start {
    if (_started)
        return NO;
    
    return [self startListening];
}

- (void) stop {
    if (!_started)
        return;
    
    [self stopListening];
    
    _started = NO;
}

- (BOOL) isStarted {
    return _started;
}

- (NSArray<ASServiceInfo*>*) findServices:(NSString*)type {
    NSMutableArray *result = [[NSMutableArray alloc] init];
    
    for (ASServiceInfo *eachInfo in _services)
        if ([eachInfo.type caseInsensitiveCompare:type] == NSOrderedSame) // case insensitive!
            [result addObject:eachInfo];
    
    return result;
}

- (void) sendTcpResponse:(ASDtoServiceResponse*)response
             toToHost:(NSString*)host
              andPort:(int)port {
    GCDAsyncSocket *sendSocket = [[GCDAsyncSocket alloc] initWithDelegate:nil
                                                            delegateQueue:_delegateQueue];
    [sendSocket writeData:response.data withTimeout:0 tag:0];
    [sendSocket disconnectAfterWriting];
    
    NSLog(@"Sent TCP response to %@:%i", host, port);
}

- (void) sendUdpResponse:(ASDtoServiceResponse*)response
                  toPort:(int)port {
    
    [_socket sendData:response.data
                  toHost:_multicastGroup
                    port:port
             withTimeout:0
                     tag:0];
    
    NSLog(@"Sent UDP response to %@:%i", _multicastGroup, port);
}

- (void) sendResponse:(ASDtoServiceResponse*)response
               toHost:(NSString*)host
              andPort:(int)port
              andMode:(ASMode)mode
                 info:(ASServiceInfo*)serviceInfo
{
    if (mode == ASMODE_TCP) {
        // TCP
        [self sendTcpResponse:response
                     toToHost:host
                      andPort:port];
    } else {
        // UDP
        [self sendUdpResponse:response
                       toPort:port];
    }
    
    dispatch_async(_delegateQueue, ^{
        [_delegate didSendServiceResponse:host serviceInfo:serviceInfo];
    });
}

#pragma mark - GCDAsyncUdpSocket delegate

/**
 * Called when the socket has received the requested datagram.
 **/
- (void)udpSocket:(GCDAsyncUdpSocket *)sock
   didReceiveData:(NSData *)data
      fromAddress:(NSData *)address
withFilterContext:(id)filterContext {
    ASDtoServiceRequest *request;
    @try {
        request = [ASDtoServiceRequest parseFromData:data];
    } @catch (NSException *e) {
        NSError *parseError = [NSError errorWithDomain:PUBLISHER_ERROR_PARSE
                                                  code:0
                                              userInfo:nil];
        [_delegate didFailWithError:parseError];
        return;
    }
    NSLog(@"ServiceRequest received:\n%@", request);
    
    ASMode mode = (request.mode == ASDtoServiceRequestModeUDP ? ASMODE_UDP : ASMODE_TCP);
    NSString *host;
    uint16_t port = 0;
    [GCDAsyncUdpSocket getHost:&host port:&port fromAddress:address];
    
    if ([_delegate acceptServiceRequestForHost:host withType:request.type withMode:mode]) {
        NSLog(@"Service request accepted");
    } else {
        NSLog(@"Service request rejected");
        return;
    }
    
    NSArray<ASServiceInfo*> *foundServices = [self findServices:request.type];
    if (foundServices.count > 0) {
        NSLog(@"%i services found", (int)foundServices.count);
    } else {
        NSLog(@"No services found");
        
        // in delegate thread
        dispatch_async(_delegateQueue, ^{
            [_delegate didNotFindServiceForHost:host withType:request.type withMode:mode];
        });
        return;
    }
    
    for (ASServiceInfo *eachInfo in foundServices) {
        ASDtoServiceResponseBuilder *builder = [ASDtoServiceResponse builder];
        
        // required
        [builder setPort:eachInfo.port];
        [builder setType:eachInfo.type];
        
        // optional
        if (eachInfo.title != nil)
            [builder setTitle:eachInfo.title];
        
        if (eachInfo.payload != nil)
            [builder setPayload:eachInfo.payload];
        
        ASDtoServiceResponse *response = [builder build];
        NSLog(@"Response built:\n%@", response);
        
        [self sendResponse:response
                    toHost:host
                   andPort:request.port
                   andMode:mode
                      info:eachInfo];
    }
    
}

@end
