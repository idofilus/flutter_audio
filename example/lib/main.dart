import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio/audio.dart';

void main() => runApp(AudioApp());

class AudioRecorder extends StatefulWidget
{
    @override
    State<StatefulWidget> createState() => AudioRecorderState();
}

class AudioRecorderState extends State<AudioRecorder>
{
    @override
    Widget build(BuildContext context)
    {
        return Container(
            padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
            child: Column(
                children: <Widget>[
                    Text("Audio Recorder")
                ],
            ),
        );
    }
}

@immutable
class AudioPlayerDemo extends StatefulWidget
{
    final String url;

    AudioPlayerDemo(this.url);

    @override
    State<StatefulWidget> createState() => AudioPlayerDemoState();
}

class AudioPlayerDemoState extends State<AudioPlayerDemo>
{
    Audio audioPlayer = new Audio(single: true);
    AudioPlayerState state = AudioPlayerState.STOPPED;
    double position = 0;
    StreamSubscription<AudioPlayerState> _playerStateSubscription;
    StreamSubscription<double> _playerPositionController;
    StreamSubscription<int> _playerBufferingSubscription;
    StreamSubscription<AudioPlayerError> _playerErrorSubscription;

    @override
    void initState()
    {
        _playerStateSubscription = audioPlayer.onPlayerStateChanged.listen((AudioPlayerState state)
        {
            print("onPlayerStateChanged: ${audioPlayer.uid} $state");

            if (mounted)
                setState(() => this.state = state);
        });

        _playerPositionController = audioPlayer.onPlayerPositionChanged.listen((double position)
        {
            print("onPlayerPositionChanged: ${audioPlayer.uid} $position ${audioPlayer.duration}");

            if (mounted)
                setState(() => this.position = position);
        });

        _playerBufferingSubscription = audioPlayer.onPlayerBufferingChanged.listen((int percent)
        {
            print("onPlayerBufferingChanged: ${audioPlayer.uid} $percent");
        });

        _playerErrorSubscription = audioPlayer.onPlayerError.listen((AudioPlayerError error)
        {
            throw("onPlayerError: ${error.code} ${error.message}");
        });

        audioPlayer.preload(widget.url);

        super.initState();
    }

    @override
    Widget build(BuildContext context)
    {
        Widget status = Container();

        print("[build] uid=${audioPlayer.uid} duration=${audioPlayer.duration} state=$state");

        switch (state)
        {
            case AudioPlayerState.LOADING:
            {
                status = Container(
                    padding: const EdgeInsets.all(12.0),
                    child: Container(
                        child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2.0)),
                        width: 24.0,
                        height: 24.0
                    )
                );
                break;
            }

            case AudioPlayerState.PLAYING:
            {
                status = IconButton(icon: Icon(Icons.pause, size: 28.0), onPressed: onPause);
                break;
            }

            case AudioPlayerState.READY:
            case AudioPlayerState.PAUSED:
            case AudioPlayerState.STOPPED:
            {
                status = IconButton(icon: Icon(Icons.play_arrow, size: 28.0), onPressed: onPlay);

                if (state == AudioPlayerState.STOPPED)
                    audioPlayer.seek(0.0);

                break;
            }
        }

        return Container(
            padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
            child: Column(
                children: <Widget>[
                    //Text("Audio Player"),
                    Text(audioPlayer.uid),
                    Row(
                        children: <Widget>[
                            status,
                            Slider(
                                max: audioPlayer.duration.toDouble(),
                                value: position.toDouble(),
                                onChanged: onSeek,
                            ),
                            Text("${audioPlayer.duration.toDouble()}ms")
                        ],
                    )
                ],
            ),
        );
    }

    @override
    void dispose()
    {
        _playerStateSubscription.cancel();
        _playerPositionController.cancel();
        _playerBufferingSubscription.cancel();
        _playerErrorSubscription.cancel();
        audioPlayer.release();
        super.dispose();
    }

    onPlay()
    {
        audioPlayer.play(widget.url);
    }

    onPause()
    {
        audioPlayer.pause();
    }

    onSeek(double value)
    {
        // Note: We can only seek if the audio is ready
        audioPlayer.seek(value);
    }
}

class AudioApp extends StatefulWidget
{

    @override
    _AudioAppState createState() => _AudioAppState();
}

class _AudioAppState extends State<AudioApp>
{
    @override
    void initState()
    {
        super.initState();
    }

    @override
    Widget build(BuildContext context)
    {
        return MaterialApp(
            home: Scaffold(
                appBar: AppBar(
                    title: const Text("Audio"),
                ),
                body: ListView(
                    children: <Widget>[
                        //AudioPlayerDemo("https://firebasestorage.googleapis.com/v0/b/openso"), // Test the error handling
                        AudioPlayerDemo("https://firebasestorage.googleapis.com/v0/b/opensource-11ed5.appspot.com/o/flutter_audio_plugin%2FSampleAudio_0.4mb.mp3?alt=media&token=a6334d66-dc48-4562-b126-ed7004b18e5c"),
                        AudioPlayerDemo("https://firebasestorage.googleapis.com/v0/b/opensource-11ed5.appspot.com/o/flutter_audio_plugin%2F456235__greek555__loop-mix-128-bpm.mp3?alt=media&token=3d4f4357-a143-46bd-89c1-0b3fbaa9a9e9"),
                    ],
                ),
            ),
        );
    }
}
