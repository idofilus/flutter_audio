package com.idofilus.audio;

import java.util.WeakHashMap;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/**
 * AudioPlugin
 */
public class AudioPlugin implements MethodCallHandler
{
    private static final String TAG = AudioPlugin.class.getName();

    private MethodChannel channel;
    private static WeakHashMap<String, AudioPlayer> players = new WeakHashMap<>();

    /**
     * Plugin registration.
     */
    public static void registerWith(Registrar registrar)
    {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "audio");
        channel.setMethodCallHandler(new AudioPlugin(registrar, channel));
    }

    public AudioPlugin(Registrar registrar, MethodChannel channel)
    {
        this.channel = channel;
    }

    @Override
    public void onMethodCall(MethodCall call, Result result)
    {
        String uid = call.argument("uid");

        System.out.println(String.format("onMethodCall method=%s uid=%s", call.method, uid));

        // Make sure we have the audio player ready
        initialize(uid);

        switch (call.method)
        {
            case "player.play":
                players.get(uid).play((String)call.argument("url"), (int)call.argument("positionInterval"));
                result.success(null);
                break;

            case "player.preload":
                players.get(uid).preload((String)call.argument("url"), (int)call.argument("positionInterval"));
                result.success(null);
                break;

            case "player.pause":
                players.get(uid).pause();
                result.success(null);
                break;

            case "player.stop":
                players.get(uid).stop(false);
                result.success(null);
                break;

            case "player.seek":
                players.get(uid).seek((double) call.argument("position"));
                result.success(null);
                break;

            case "player.release":
                players.get(uid).release();
                result.success(null);
                break;

            default:
                result.notImplemented();
                break;
        }
    }

    /// Initialize the media player
    private void initialize(final String uid)
    {
        if (players.containsKey(uid))
            return;

        players.put(uid, new AudioPlayer(channel, uid));
    }
}
