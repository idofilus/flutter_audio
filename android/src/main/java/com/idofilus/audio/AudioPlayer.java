package com.idofilus.audio;

import android.media.AudioAttributes;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.os.Build;
import android.os.Handler;
import android.provider.MediaStore;
import android.util.Log;

import java.io.IOException;
import java.util.HashMap;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/**
 * AudioPlugin
 */
public class AudioPlayer
{
    private static final String TAG = AudioPlayer.class.getName();

    private MethodChannel channel;
    private String uid;
    private MediaPlayer player;
    private int handleInterval;
    private Handler handler = new Handler();
    private boolean preloaded = false;
    private boolean loaded = false;
    private String lastUrl;

    public AudioPlayer(MethodChannel channel, String uid)
    {
        this.channel = channel;
        this.uid = uid;
    }

    MediaPlayer getPlayer()
    {
        return player;
    }

    /// Initialize the media player
    private void initialize()
    {
        if (player != null)
            return;

        player = new MediaPlayer();
        player.setOnBufferingUpdateListener(new MediaPlayer.OnBufferingUpdateListener()
        {
            @Override
            public void onBufferingUpdate(MediaPlayer mp, final int percent)
            {
                // TODO: TEST onBufferingUpdate on release

                Log.v(TAG, String.format("[onBufferingUpdate] percent=%d", percent));
                invoke("player.onBuffering", percent);

                if (percent == 100 && !loaded)
                {
                    loaded = true;

                    if (preloaded)
                        invoke("player.onReady", player.getDuration());
                    else
                        playAudio();
                }
            }
        });

        player.setOnCompletionListener(new MediaPlayer.OnCompletionListener()
        {
            @Override
            public void onCompletion(MediaPlayer mp)
            {
                stop(true);
            }
        });

        player.setOnErrorListener(new MediaPlayer.OnErrorListener()
        {
            @Override
            public boolean onError(MediaPlayer mp, int what, int extra)
            {
                switch (what)
                {
                    case MediaPlayer.MEDIA_ERROR_IO:
                        AudioPlayer.this.onError("IO");
                        break;

                    case MediaPlayer.MEDIA_ERROR_SERVER_DIED:
                        AudioPlayer.this.onError("SERVER_DIED");
                        break;

                    case MediaPlayer.MEDIA_ERROR_NOT_VALID_FOR_PROGRESSIVE_PLAYBACK:
                        AudioPlayer.this.onError("NOT_VALID_FOR_PROGRESSIVE_PLAYBACK");
                        break;

                    case MediaPlayer.MEDIA_ERROR_MALFORMED:
                        AudioPlayer.this.onError("MALFORMED");
                        break;

                    case MediaPlayer.MEDIA_ERROR_UNSUPPORTED:
                        AudioPlayer.this.onError("UNSUPPORTED");
                        break;

                    case MediaPlayer.MEDIA_ERROR_TIMED_OUT:
                        AudioPlayer.this.onError("TIMED_OUT");
                        break;

                    case MediaPlayer.MEDIA_ERROR_UNKNOWN:
                    default:
                        AudioPlayer.this.onError("UNKNOWN");
                        break;
                }

                return true;
            }
        });

        // TODO: Volume ?
    }

    private void playAudio()
    {
        initialize();
        player.start();
        handler.post(sendPayload);
        invoke("player.onPlay", player.getDuration());
    }

    /// Release the media player
    void release()
    {
        if (player != null)
        {
            player.stop();
            player.release();
        }
    }

    void play(String url, int positionInterval)
    {
        Log.v(TAG, "playing: " + url);

        if (lastUrl == null || !lastUrl.equals(url))
        {
            preload(url, positionInterval);
            preloaded = false;
        }
        else
            playAudio();
    }

    void preload(String url, int positionInterval)
    {
        try
        {
            lastUrl = url;

            invoke("player.onBuffering", 0);

            loaded = false;
            initialize();

            player.reset();

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP)
            {
                player.setAudioAttributes(new AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build());
            }
            else
            {
                player.setAudioStreamType(AudioManager.STREAM_MUSIC);
            }

            player.setDataSource(url);
            player.prepareAsync();

            handleInterval = positionInterval;
            preloaded = true;
        }
        catch (IOException e)
        {
            onError(e, "player.error.datasource", String.format("Failed to play audio, invalid data source: %s", e.getMessage()));
        }
    }

    void pause()
    {
        handler.removeCallbacks(sendPayload);

        if (player != null && player.isPlaying())
            player.pause();

        invoke("player.onPause", null);
    }

    /// completed flag will determine if the audio stopped by completion
    void stop(boolean completed)
    {
        handler.removeCallbacks(sendPayload);

        if (player != null && player.isPlaying())
            player.stop();

        invoke("player.onStop", completed);
    }

    void seek(double position)
    {
        if (player == null || position == player.getCurrentPosition())
            return;

        player.seekTo((int)position);
        invoke("player.onCurrentPosition", position);
    }

    private Runnable sendPayload = new Runnable()
    {
        @Override
        public void run()
        {
            if (player.isPlaying())
            {
                int position = player.getCurrentPosition();
                Log.v(TAG, String.format("[position update of %d] uid=%s position=%d", handleInterval, uid, position));
                invoke("player.onCurrentPosition", position);
            }

            handler.postDelayed(this, handleInterval);
        }
    };

    private void onError(IOException e, final String code, final String message)
    {
        Log.e(TAG, message);
        channel.invokeMethod("player.onError", new HashMap<String, String>() {{
            put("uid", uid);
            put("code", code);
            put("message", message);
        }});
    }

    private void onError(final String code)
    {
        Log.e(TAG, String.format("onError::code %s", code));
        channel.invokeMethod("player.onError.code", new HashMap<String, String>() {{
            put("uid", uid);
            put("code", code);
        }});
    }

    private void invoke(String name, Object argument)
    {
        HashMap<String, Object> data = new HashMap<>();
        data.put("uid", uid);
        data.put("argument", argument);

        Log.v(TAG, String.format("[invoke] %s %s => ", name, uid) + argument);
        channel.invokeMethod(name, data);
    }
}
