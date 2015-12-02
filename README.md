# ServiceDiscovery-ios

## Intro

It's a simple service discovery protocol (like Zeroconf or WS-Discovery) and framework implemented in ObjectiveC.
Services are available to publish their :
* `int port` (required)
* `NSString *type` (required)
* `NSString *title` (optional)
* `NSData *payload` (optional)

## Usage

### Publish service info

    // const
    #define MULTICAST_GROUP @"239.255.255.240"
    #define MULTICAST_PORT 4470
    #define RESPONSE_PORT (MULTICAST_PORT + 1)

    #define SERVICE_TYPE @"MyServiceType1"
    #define SERVICE_PORT 1204
    #define SERVICE_TITLE @"Hello world"

    // publish
    publisher = [[ASServicePublisher alloc] initWithMulticastGroup:MULTICAST_GROUP
                                                           andPort:MULTICAST_PORT
                                                       andDelegate:self];

    publisher.delegateQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    ASServiceInfo *serviceInfo = [[ASServiceInfo alloc] initWithPort:SERVICE_PORT
                                                             andType:SERVICE_TYPE
                                                            andTitle:SERVICE_TITLE
                                                          andPayload:somePayload];
    [publisher registerService:serviceInfo];
    
### Discover services

    locator = [[ASServiceLocator alloc] initWithMulticastGroup:group
                                              andMulticastPort:port
                                               andResponsePort:(port + 1)
                                                   andDelegate:self];
    locator.mode = ASMODE_UDP;
    locator.responseTimeoutMillis = 3000; // 3s
    locator.delegateQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    ...

    - (void) didDiscoverService:(ASServiceInfo*)serviceInfo onHost:(NSString*)host {
        NSLog(@"Discovered service with title \"%@\" on %@:%i", serviceInfo.title, host, serviceInfo.port);
    }

## How it works

1. Publisher listens for UDP milticast requests from Locator.
2. Locator starts listening for response (UDP or TCP, depends on locator `mode`) and sends `ServiceRequest` with required fields:
  * `string type` // service type to discover
  * `Mode mode` // TCP or UDP response mode
  * `int port` // either TCP or UDP port for response
3. Publisher receives request, accepts or rejects it (in listener `boolean onServiceRequestReceived()` or comparing requested and actual service type) and sends `ServiceResponse` over TCP directly to requester host and port in request (if TCP mode reponse was in request) or UDP multicast response (same UDP group but port in request).
4. Locator receives response and notifies service is found.
    
## Testing

See `Project/` for more information. Average discovery time in my home network is about 60 ms.

## How to build

Just use `CocoaPod`:

1. clone `ASServiceDiscovery-ios` repo:
> git clone https://github.com/4ntoine/ServiceDiscovery-ios

2. add to your project 'Podfile':
> pod 'ASServiceDiscovery', path := '(path to cloned repo 'ASServiceDiscovery.podspec' file)'

3. install pod:
> pod install

## Implementations

See according Java implementation:
https://github.com/4ntoine/ServiceDiscovery-java

## License
Free for non-commercial usage, contact for commercial usage.

## Author
Anton Smirnov

dev [at] antonsmirnov [dot] name

2015
