package com.example.scamdetection;

import android.os.Bundle;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "notificationListener";

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        NotificationHandler.setMethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL);
    }
}
