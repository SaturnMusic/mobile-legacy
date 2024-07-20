package com.ryanheise.just_audio;

import android.app.Activity;
import android.content.Context;
import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import java.util.HashMap;
import java.util.List;
import java.util.ArrayList;
import java.util.Map;

public class MainMethodCallHandler implements MethodCallHandler {

    private final Context applicationContext;
    private final BinaryMessenger messenger;
    private ActivityPluginBinding activityPluginBinding;

    private final Map<String, AudioPlayer> players = new HashMap<>();

    public MainMethodCallHandler(Context applicationContext,
            BinaryMessenger messenger) {
        this.applicationContext = applicationContext;
        this.messenger = messenger;
    }

    void setActivityPluginBinding(ActivityPluginBinding activityPluginBinding) {
        this.activityPluginBinding = activityPluginBinding;
        for (AudioPlayer player : players.values()) {
            player.setActivityPluginBinding(activityPluginBinding);
        }
    }

    @Override
    public void onMethodCall(MethodCall call, @NonNull Result result) {
        final Map<?, ?> request = call.arguments();
        switch (call.method) {
        case "init": {
            String id = (String)request.get("id");
            if (players.containsKey(id)) {
                result.error("Platform player " + id + " already exists", null, null);
                break;
            }
            final AudioPlayer player = new AudioPlayer(applicationContext, messenger, id);
            players.put(id, player);
            if (activityPluginBinding != null) {
                player.setActivityPluginBinding(activityPluginBinding);
            }
            result.success(null);
            break;
        }
        case "disposePlayer": {
            String id = (String)request.get("id");
            AudioPlayer player = players.get(id);
            if (player != null) {
                player.dispose();
                players.remove(id);
            }
            result.success(new HashMap<String, Object>());
            break;
        }
        default:
            result.notImplemented();
            break;
        }
    }

    void dispose() {
        for (AudioPlayer player : new ArrayList<AudioPlayer>(players.values())) {
            player.dispose();
        }
    }
}
