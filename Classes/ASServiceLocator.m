//
//  ASServiceLocator.m
//  ServiceDiscovery-ios
//
//  Created by Anton Smirnov on 02.12.15.
//  Copyright © 2015 Anton Smirnov. All rights reserved.
//

#import "ASServiceLocator.h"
#import "Discovery.pb.h"
#import "GCDAsyncUdpSocket.h"
#import "GCDAsyncSocket.h"
#import "ASServiceInfo.h"

// -------------------------------------------------------------------------------------------------

@interface ASCancellableTimer : NSObject

- (instancetype) initWithQueue:(dispatch_queue_t)queue andInterval:(int)intervalMillis forTarget:(id)target withSelector:(SEL)selector;
- (void) start;
- (void) cancel;

@end

@implementation ASCancellableTimer
{
    dispatch_queue_t _queue;
    int _intervalMillis;
    id _target;
    SEL _selector;
    
    BOOL _cancelled;
}

- (instancetype) initWithQueue:(dispatch_queue_t)queue andInterval:(int)intervalMillis forTarget:(id)target withSelector:(SEL)selector {
    if (self = [super init]) {
        _queue = queue;
        _intervalMillis = intervalMillis;
        _target = target;
        _selector = selector;
        
        _cancelled = NO;
    }
    return self;
}

- (void) didFinish {
    if (!_cancelled) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [_target performSelector:_selector];
        #pragma clang diagnostic pop
    }
}

- (void) start {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_intervalMillis * NSEC_PER_MSEC)), _queue, ^{
        [self didFinish];
    });
}

- (void) cancel {
    _cancelled = YES;
}

@end

// -------------------------------------------------------------------------------------------------

@implementation ASServiceLocator
{
    NSString *_type;
    BOOL _discovering;
    
    NSString *_multicastGroup;
    int _multicastPort;
    
    GCDAsyncUdpSocket *_sendSocket;
    GCDAsyncUdpSocket *_receiveUdpSocket;
    GCDAsyncSocket *_receiveTcpSocket;
    
    ASCancellableTimer *_timer;
}

- (instancetype) initWithMulticastGroup:(NSString*)multicastGroup
                       andMulticastPort:(int)multicastPort
                        andResponsePort:(int)responsePort
                            andDelegate:(id<ASServiceLocatorDelegate>)delegate {
    if (self = [super init]) {
        _multicastGroup = multicastGroup;
        _multicastPort = multicastPort;
        _responsePort = responsePort;
        _delegate = delegate;
        
        _mode = ASMODE_UDP;
        _responseTimeoutMillis = 3 * 1000; // 3 sec
    }
    return self;
}

- (BOOL) isDiscovering {
    return _discovering;
}

- (void) stopDiscovery {
    [self stopListening];
    _discovering = NO;
    
    dispatch_async(_delegateQueue, ^{
        [_delegate didFinishDiscovery];
    });
}

- (BOOL) startListening {
    return _mode == ASMODE_TCP
            ? [self startListeningTcp]
            : [self startListeningUdp];
}

- (BOOL) startListeningTcp {
    _receiveTcpSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_delegateQueue];
    
    NSError *error;
    
    if (![_receiveTcpSocket acceptOnPort:_responsePort error:&error]) {
        NSLog(@"Failed to open response TCP socket: %@", error);
        
        dispatch_async(_delegateQueue, ^{
            [_delegate didFailWithError:error];
        });
    }
    
    return YES;
}

- (BOOL) startListeningUdp {
    _receiveUdpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self
                                            delegateQueue:_delegateQueue];
    
    NSError *error;
    if (![_receiveUdpSocket bindToPort:_responsePort error:&error]) {
        NSLog(@"Failed to bind to port %i: %@", _multicastPort, error);
        [_receiveUdpSocket close];
        
        dispatch_async(_delegateQueue, ^{
            [_delegate didFailWithError:error];
        });
        return NO;
    }
    
    if (![_receiveUdpSocket joinMulticastGroup:_multicastGroup error:&error]) {
        NSLog(@"Failed to join multicast group %@: %@", _multicastGroup, error);
        [_receiveUdpSocket close];
        
        dispatch_async(_delegateQueue, ^{
            [_delegate didFailWithError:error];
        });
        return NO;
    }
    
    if (![_receiveUdpSocket beginReceiving:&error]) {
        NSLog(@"Failed to begin receiving: %@", error);
        [_receiveUdpSocket close];
        
        dispatch_async(_delegateQueue, ^{
            [_delegate didFailWithError:error];
        });
        return NO;
    }
    
    // event 'started'
    dispatch_async(_delegateQueue, ^{
        NSLog(@"Started to publish");
        [_delegate didStartDiscovery];
    });
    
    return YES;
}

- (void) stopListening {
    if (_receiveTcpSocket != nil) {
        [_receiveTcpSocket disconnectAfterReading];
        _receiveTcpSocket = nil;
    }
    
    if (_receiveUdpSocket != nil) {
        [_receiveUdpSocket close];
        _receiveUdpSocket = nil;
    }
}

- (BOOL) sendRequest {
    ASDtoServiceRequestBuilder *builder = [ASDtoServiceRequest builder];
    [builder setType:_type];
    [builder setPort:_responsePort];
    [builder setMode: (_mode == ASMODE_TCP ? ASDtoServiceRequestModeTCP : ASDtoServiceRequestModeUDP)];
    ASDtoServiceRequest *request = [builder build];
    NSLog(@"Built service request:\n%@", request);
    
    GCDAsyncUdpSocket *socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self
                                            delegateQueue:_delegateQueue];
    
    NSError *error;
    if (![socket bindToPort:_multicastPort error:&error]) {
        NSLog(@"Failed to bind to port %i: %@", _multicastPort, error);
        [socket close];
        
        dispatch_async(_delegateQueue, ^{
            [_delegate didFailWithError:error];
        });
        return NO;
    }
    
    if (![socket joinMulticastGroup:_multicastGroup error:&error]) {
        NSLog(@"Failed to join multicast group %@: %@", _multicastGroup, error);
        [socket close];
        
        dispatch_async(_delegateQueue, ^{
            [_delegate didFailWithError:error];
        });
        return NO;
    }
    
    [socket sendData:request.data
              toHost:_multicastGroup
                port:_multicastPort
         withTimeout:0
                 tag:0];
    
    NSLog(@"Request sent");
    
    return YES;
}

- (void) didTimeout {
//    NSLog(@"Discovery timeout");
    [self stopDiscovery];
}

- (void) startTimer {
    _timer = [[ASCancellableTimer alloc] initWithQueue:_delegateQueue
                                           andInterval:_responseTimeoutMillis
                                             forTarget:self
                                          withSelector:@selector(didTimeout)];
    [_timer start];
}

- (void) stopTimer {
    if (_timer != nil) {
        [_timer cancel];
        _timer = nil;
    }
}

- (void) discover:(NSString*)type {
    if (_discovering)
        return;
    
    _type = type;
    _discovering = YES;
    
    // prepare to receive response
    [self startListening];
    
    // send request
    if (![self sendRequest]) {
        
        dispatch_async(_delegateQueue, ^{
            [_delegate didFinishDiscovery];
        });
        
        [self stopDiscovery];
    }
        
    [self startTimer];
}

- (BOOL) cancelDescovery {
    if (!_discovering)
        return NO;
    
    [self stopDiscovery];
    [self stopTimer];
    return YES;
}

- (void) didReceiveResponseBytes:(NSData*)data fromHost:(NSString*)host {
    ASDtoServiceResponse *response;
    @try {
         response = [ASDtoServiceResponse parseFromData:data];
        NSLog(@"Received response:\n%@", response);
    } @catch (NSException *e) {
        NSError *error = [NSError errorWithDomain:LOCATOR_ERROR_PARSE
                                             code:0
                                         userInfo:nil];
        [_delegate didFailWithError:error];
        return;
    }
    
    ASServiceInfo *serviceInfo = [[ASServiceInfo alloc] initWithPort:response.port
                                                             andType:response.type
                                                            andTitle:response.title
                                                          andPayload:response.payload];
    
    [_delegate didDiscoverService:serviceInfo
                           onHost:host];
}

#pragma mark - GCDAsyncUdpSocket delegate

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address {
    
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(NSError *)error {
    // nothing (handled while connect/send)
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag {
    // nothing
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error {
    [_delegate didFailWithError:error];
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data
      fromAddress:(NSData *)address
withFilterContext:(id)filterContext {
    
    NSString *host;
    uint16_t port = 0;
    [GCDAsyncUdpSocket getHost:&host port:&port fromAddress:address];
    
    [self didReceiveResponseBytes:data fromHost:host];
}

#pragma mark - GCDAsyncSocket delegate

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    
    NSString *host;
    uint16_t port = 0;
    [GCDAsyncSocket getHost:&host port:&port fromAddress:data];
    
    [self didReceiveResponseBytes:data fromHost:host];
}

@end
