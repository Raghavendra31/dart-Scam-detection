package com.example.scamdetection;

import android.content.Intent;
import android.os.Bundle;
import android.service.notification.StatusBarNotification;
import android.util.Log;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "notificationListener";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        NotificationHandler.setMethodChannel(getFlutterEngine().getDartExecutor().getBinaryMessenger(), CHANNEL);
    }
}
