#import "AudioPlugin.h"
#import "AudioPlayer.h"

#import <UIKit/UIKit.h>
#import <AVKit/AVKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

static FlutterMethodChannel* channel;
static NSMutableDictionary* players;

@implementation AudioPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar
{
    channel = [FlutterMethodChannel methodChannelWithName:@"audio" binaryMessenger:[registrar messenger]];
    AudioPlugin* instance = [[AudioPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result
{
    NSString* uid = call.arguments[@"uid"];

    NSLog(@"handleMethodCall: [%@] %@", call.method, uid);

    for(NSString *key in [call.arguments allKeys]) {
        NSLog(@"handleMethodCall ARG=%@, VALUE=%@", key, [call.arguments objectForKey:key]);
    }

    if (![players objectForKey:uid])
        players[uid] = [[AudioPlayer alloc] initWithUid:uid channel:channel];

    if ([@"player.play" isEqualToString:call.method])
    {
        [players[uid] play:call.arguments[@"url"]];
        result(nil);
    }
    else if ([@"player.preload" isEqualToString:call.method])
    {
        [players[uid] preload:call.arguments[@"url"]];
        result(nil);
    }
    else if ([@"player.pause" isEqualToString:call.method])
    {
        [players[uid] pause];
        result(nil);
    }
    else if ([@"player.stop" isEqualToString:call.method])
    {
        [players[uid] stop:call.arguments[@"completed"]];
        result(nil);
    }
    else if ([@"player.seek" isEqualToString:call.method])
    {
        NSLog(@"position = %.20f", [call.arguments[@"position"] doubleValue]);
        [players[uid] seek:[call.arguments[@"position"] doubleValue]];
        result(nil);
    }
    else if ([@"player.release" isEqualToString:call.method])
    {
        [players[uid] releasePlayer];
        result(nil);
    }
    else
    {
        result(FlutterMethodNotImplemented);
    }
}

- (id)init
{
    self = [super init];
    
    if (self)
    {
        players = [[NSMutableDictionary alloc] init];
    }

    return self;
}

@end
