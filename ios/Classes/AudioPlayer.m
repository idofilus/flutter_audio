#import "AudioPlayer.h"

#import <UIKit/UIKit.h>
#import <AVKit/AVKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

@implementation AudioPlayer

- (id)initWithUid: (NSString*) uid channel:(FlutterMethodChannel*)channel
{
    self = [super init];

    if (self)
    {
        self.uid = uid;
        self.channel = channel;
        self.preloaded = false;
    }

    if (self.channel)
        NSLog(@"Valid channel!");

    return self;
}

- (void)play: (NSString*) url
{
    NSLog(@"playing [%@]= %@", _uid, url);

    if (_lastUrl == nil || ![url isEqualToString:_lastUrl])
    {
        [self preload:url];
        _preloaded = false;
    }
    else
    {
        [self playAudio];
    }
}

-(void)playAudio
{
    [_player play];
    [_channel invokeMethod:@"player.onPlay" arguments:@{@"uid": _uid, @"argument": @([self getPlayerDuration])}];
}

- (void)preload: (NSString*) url
{
    NSLog(@"preload [%@]= %@", _uid, url);

    _lastUrl = url;

    [_channel invokeMethod:@"player.onBuffering" arguments:@{@"uid": _uid, @"argument": @(0)}];

    // Create AVAsset using URL
    AVAsset *asset = [AVAsset assetWithURL:[NSURL URLWithString:url]];

    // Create AVPlayerItem using AVAsset
    _playerItem = [[AVPlayerItem alloc] initWithAsset:asset];

    // Initialise AVPlayer
    _player = [AVPlayer playerWithPlayerItem:_playerItem];

    // Register for playback end notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidReachEnd:) 
        name:AVPlayerItemDidPlayToEndTimeNotification object:_playerItem];

    // Register observer for events of AVPlayer status
    [_player addObserver:self forKeyPath:@"status" options:0 context:nil];
    [_playerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:0 context:nil];

    id _observer = [_player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2) queue:dispatch_get_main_queue() usingBlock:^(CMTime time)
    {
        int _progress = CMTimeGetSeconds(time);
        NSLog(@"_progress=%d", _progress);
    }];

    CMTime interval = CMTimeMakeWithSeconds(0.2, NSEC_PER_SEC);
    id timeObserver = [_player addPeriodicTimeObserverForInterval:interval queue:nil usingBlock:^(CMTime time)
    {
        //[self onTimeInterval:time];
        int _progress = CMTimeGetSeconds(_playerItem.currentTime) * 1000;

        if (_progress >= 0)
        {
            NSLog(@"_progress=%d", _progress);
            [_channel invokeMethod:@"player.onCurrentPosition" arguments:@{@"uid": _uid, @"argument": @(_progress)}];
        }
    }];

    _preloaded = true;
}

- (void)playerItemDidReachEnd:(NSNotification *)notification
{
    NSLog(@"playerItemDidReachEnd");
    [self stop:true];
}

- (void)pause
{
    NSLog(@"pause [%@]", _uid);
    [_player pause];
    [_channel invokeMethod:@"player.onPause" arguments:@{@"uid": _uid}];
}

- (void)stop: (bool) completed
{
    NSLog(@"stop [%@] %d", _uid, completed);
    [_player pause];
    [_player seekToTime:CMTimeMake(0, 1)];
    [_player replaceCurrentItemWithPlayerItem:_playerItem];
    [_channel invokeMethod:@"player.onStop" arguments:@{@"uid": _uid, @"argument": @(completed)}];
}

- (void)seek: (double) position
{
    NSLog(@"seek [%@] %.20f", _uid, position);
    [_player seekToTime:CMTimeMakeWithSeconds(position / 1000, 1)];
    [_channel invokeMethod:@"player.onCurrentPosition" arguments:@{@"uid": _uid, @"argument": @(position)}];
}

- (void)releasePlayer
{
    NSLog(@"release [%@]", _uid);
}

- (int)getPlayerDuration
{
    return CMTimeGetSeconds(_playerItem.duration) * 1000;
}

- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context 
{

    if (object == _player && [keyPath isEqualToString:@"status"]) 
    {
        if (_player.status == AVPlayerStatusFailed) 
        {
            NSLog(@"AVPlayer Failed");

        }
         else if (_player.status == AVPlayerStatusReadyToPlay) 
         {
            NSLog(@"AVPlayerStatusReadyToPlay [onReady:duration=%d or %d]", [self getPlayerDuration], CMTimeGetSeconds(_playerItem.asset.duration) * 1000);

            if (_preloaded)
            {
                [_channel invokeMethod:@"player.onReady" arguments:@{@"uid": _uid, @"argument": @([self getPlayerDuration])}];
            }
            else
            {
                [self playAudio];
            }
        }
         else if (_player.status == AVPlayerItemStatusUnknown)
         {
            NSLog(@"AVPlayer Unknown");
        }
    }
    else if (object == _player && [keyPath isEqualToString:@"loadedTimeRanges"])
    {
        NSArray* timeRanges = (NSArray*)[change objectForKey:NSKeyValueChangeNewKey];

        NSLog(@"timerange 2");

        if (timeRanges && [timeRanges count]) 
        {
            CMTimeRange timerange = [[timeRanges objectAtIndex:0]CMTimeRangeValue];
            NSLog(@"timerange 3");
        }
    }
    else
    {
        //[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)dealloc 
{
    /*[[NSNotificationCenter defaultCenter] removeObserver:self];

    // Register observer for events of AVPlayer status
    [_player removeObserver:self forKeyPath:@"status" options:0 context:nil];
    [_playerItem removeObserver:self forKeyPath:@"loadedTimeRanges" options:0 context:nil];*/
}

@end