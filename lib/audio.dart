import 'dart:async';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

enum AudioPlayerState
{
    /// Audio file is preparing for playback
    /// This can be by fetching the file or reading it
    LOADING,

    /// When the file is fully loaded
    READY,

    PLAYING,

    PAUSED,

    STOPPED
}

enum AudioPlayerErrorCode
{
    MISSING_URL,

    /// File or network related operation errors
    IO,

    /// Media server died
    SERVER_DIED,

    /// Video is streamed but no valid progressive playback
    NOT_VALID_FOR_PROGRESSIVE_PLAYBACK,

    /// Bitstream is not conforming to the related coding standard or file spec
    MALFORMED,

    /// Bitstream is conforming to the related coding standard or file spec, but
    /// the media framework does not support the feature
    UNSUPPORTED,

    /// Some operation takes too long to complete
    TIMED_OUT,

    UNKNOWN
}

class AudioPlayerError
{
    AudioPlayerErrorCode code;
    String message;

    AudioPlayerError(this.code, this.message);
}

class AudioPlayerErrorCodeType
{
    String code;

    AudioPlayerErrorCodeType(this.code);
}

class AudioPlayer
{
    static const MethodChannel _channel = const MethodChannel("audio");

    final StreamController<AudioPlayerState> _playerStateController = StreamController<AudioPlayerState>.broadcast();
    final StreamController<double> _playerPositionController = StreamController<double>.broadcast();
    final StreamController<int> _playerBufferingController = StreamController<int>.broadcast();
    final StreamController<AudioPlayerError> _playerErrorController = StreamController<AudioPlayerError>.broadcast();

    String uid;
    AudioPlayerState _state = AudioPlayerState.STOPPED;
    int _duration = 0;
    bool _completed = false;

    /// Interval ms of how often the position stream will be called
    int _positionUpdateInterval;
    bool _ready = false;

    Stream<AudioPlayerState> get onPlayerStateChanged => _playerStateController.stream;
    Stream<double> get onPlayerPositionChanged => _playerPositionController.stream;
    Stream<int> get onPlayerBufferingChanged => _playerBufferingController.stream;
    Stream<AudioPlayerError> get onPlayerError => _playerErrorController.stream;

    AudioPlayer({positionInterval = 200})
    {
        uid = new Uuid().v4();
        _positionUpdateInterval = positionInterval;
    }

    AudioPlayerState get state => _state;

    /// Duration of the audio, will be updated once the audio state is PLAYING
    int get duration => _duration;

    /// You can know when audio is [stop]ed if it's stopped by reaching the end of the audio or not
    bool get isCompleted => _completed;

    Future<void> play(String url) async
    {
        if (url == null)
            return _onError(new AudioPlayerError(AudioPlayerErrorCode.MISSING_URL, "Missing url when trying to play. Please provide it with audioPlayer.url = your_url"));

        await invoke("player.play", {"url": url, "positionInterval": _positionUpdateInterval});
    }

    Future<void> preload(String url) async
    {
        if (url == null)
            return _onError(new AudioPlayerError(AudioPlayerErrorCode.MISSING_URL, "Missing url when trying to preload. Please provide it with audioPlayer.url = your_url"));

        await invoke("player.preload", {"url": url, "positionInterval": _positionUpdateInterval});
    }

    Future<void> pause() async
    {
        await invoke("player.pause", null);
    }

    Future<void> stop() async
    {
        await invoke("player.stop", null);
    }

    Future<void> seek(double position) async
    {
        await invoke("player.seek", {"position": position});
    }

    Future<void> release() async
    {
        await invoke("player.release", null);
    }

    Future<void> invoke(String name, Map<String, dynamic> data) async
    {
        if (data == null)
            data = {};

        data["uid"] = uid;
        await _channel.invokeMethod(name, data);
    }

    void onBuffering(int percent)
    {
        if (!_ready && _state != AudioPlayerState.LOADING)
        {
            _state = AudioPlayerState.LOADING;
            _playerStateController.add(_state);

            if (percent == 100)
            {
                _ready = true;
                _state = AudioPlayerState.READY;
            }
        }

        _playerBufferingController.add(percent);
    }

    void onCurrentPosition(dynamic position)
    {
        if (position is int)
            position = (position as int).toDouble();

        print("player.onCurrentPosition: $position");
        _playerPositionController.add(position);
    }

    void onPlay(int duration)
    {
        _ready = true;
        _duration = duration;
        _state = AudioPlayerState.PLAYING;
        _playerStateController.add(_state);
    }

    void onReady(int duration)
    {
        _duration = duration;
        _state = AudioPlayerState.READY;
        _playerStateController.add(_state);
    }

    void onPause()
    {
        _state = AudioPlayerState.PAUSED;
        _playerStateController.add(_state);
    }

    void onStop(bool completed)
    {
        _completed = completed;
        _state = AudioPlayerState.STOPPED;
        _playerStateController.add(_state);
    }

    AudioPlayerError _getErrorInstance(final String errorCode)
    {
        AudioPlayerErrorCode code;
        String message;

        switch (errorCode)
        {
            case "IO":
                code = AudioPlayerErrorCode.IO;
                message = "File or network related operation errors";
                break;

            case "SERVER_DIED":
                code = AudioPlayerErrorCode.SERVER_DIED;
                message = "Media server died";
                break;

            case "NOT_VALID_FOR_PROGRESSIVE_PLAYBACK":
                code = AudioPlayerErrorCode.NOT_VALID_FOR_PROGRESSIVE_PLAYBACK;
                message = "Video is streamed but no valid progressive playback";
                break;

            case "MALFORMED":
                code = AudioPlayerErrorCode.MALFORMED;
                message = "Bitstream is not conforming to the related coding standard or file spec";
                break;

            case "UNSUPPORTED":
                code = AudioPlayerErrorCode.UNSUPPORTED;
                message = "Bitstream is conforming to the related coding standard or file spec, but the media framework does not support the feature";
                break;

            case "TIMED_OUT":
                code = AudioPlayerErrorCode.TIMED_OUT;
                message = "Some operation takes too long to complete";
                break;

            default:
                code = AudioPlayerErrorCode.UNKNOWN;
                message = "Unknown error";
                break;
        }

        return AudioPlayerError(code, message);
    }

    void _onError(AudioPlayerError error)
    {
        stop();
        _playerErrorController.add(error);
    }

    void _onErrorCode(AudioPlayerErrorCodeType error)
    {
        stop();
        _playerErrorController.add(_getErrorInstance(error.code));
    }
}

class Audio
{
    static const MethodChannel _channel = const MethodChannel("audio");
    static Map<String, AudioPlayer> players = {};
    AudioPlayer player;
    bool single;

    Stream<AudioPlayerState> get onPlayerStateChanged => player._playerStateController.stream;
    Stream<double> get onPlayerPositionChanged => player._playerPositionController.stream;
    Stream<int> get onPlayerBufferingChanged => player._playerBufferingController.stream;
    Stream<AudioPlayerError> get onPlayerError => player._playerErrorController.stream;

    String get uid => player.uid;
    AudioPlayerState get state => player.state;
    int get duration => player.duration;
    bool get isCompleted => player.isCompleted;

    /// Create [Audio] reference
    ///
    /// [single] will pause all the other players and make sure only 1 player play at a time
    /// [positionInterval] is the delay between each stream update on the player position
    Audio({
        this.single = false,
        positionInterval = 200
    })
    {
        _channel.setMethodCallHandler(_onChannelMethod);

        player = new AudioPlayer(positionInterval: positionInterval);
        players[player.uid] = player;
    }

    Future<void> _onChannelMethod(MethodCall call) async
    {
        Map<dynamic, dynamic> data = call.arguments;
        print("[_onChannelMethod] method=${call.method} arguments=${call.arguments} ${(call.arguments as Map)["uid"]}");

        AudioPlayer player = players[data["uid"]];

        if (player == null)
        {
            print("[_onChannelMethod] ERROR: No player available at uid=${(call.arguments as Map)["uid"]}");
            return;
        }

        dynamic argument = data["argument"];

        switch (call.method)
        {
            case "player.onBuffering":
                player.onBuffering(argument);
                break;

            case "player.onCurrentPosition":
                player.onCurrentPosition(argument);
                break;

            case "player.onPlay":
                player.onPlay(argument);
                break;

            case "player.onReady":
                player.onReady(argument);
                break;

            case "player.onPause":
                player.onPause();
                break;

            case "player.onStop":
                player.onStop(argument);
                break;

            case "player.onError":
                player._onError(argument);
                break;

            case "player.onError.code":
                player._onErrorCode(argument);
                break;

            default:
                throw new ArgumentError("Unknown channel method ${call.method}");
        }
    }

    Future<void> play(String url) async
    {
        // Make sure all the other players is paused
        if (single)
        {
            players.forEach((uid, player)
            {
                player.pause();
            });
        }

        await player.play(url);
    }

    Future<void> preload(String url) async
    {
        await player.preload(url);
    }

    Future<void> pause() async
    {
        await player.pause();
    }

    Future<void> stop() async
    {
        await player.stop();
    }

    Future<void> seek(double position) async
    {
        await player.seek(position);
    }

    Future<void> release() async
    {
        await player.release();
    }

    static void stopAll()
    {
        players.forEach((uid, player)
        {
            player.stop();
        });
    }

    void _onError(AudioPlayerError error)
    {
        player._onError(error);
    }
}
