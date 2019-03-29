#import <Flutter/Flutter.h>
#import <AVFoundation/AVFoundation.h>

@interface AudioPlayer : NSObject

@property NSString* uid;
@property FlutterMethodChannel* channel;
@property NSString* lastUrl;
@property AVPlayer* player;
@property AVPlayerItem* playerItem;
@property bool preloaded;

- (id)initWithUid: (NSString*) uid channel:(FlutterMethodChannel*)channel;
- (void)play: (NSString*) url;
- (void)preload: (NSString*) url;
- (void)pause;
- (void)stop: (bool) completed;
- (void)seek: (double) position;
- (void)releasePlayer;

- (int)getPlayerDuration;

@end