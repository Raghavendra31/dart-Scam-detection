package com.example.scamdetection;

import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.os.Bundle;
import android.util.Log;

import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.BinaryMessenger;

public class NotificationHandler extends NotificationListenerService {
    private static final String CHANNEL = "notificationListener";
    private static MethodChannel methodChannel;

    // Called when service is connected
    @Override
    public void onListenerConnected() {
        super.onListenerConnected();
        Log.d("NotificationHandler", "Notification listener connected");
    }

    // Called when notification is posted
    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        Bundle extras = sbn.getNotification().extras;
        String packageName = sbn.getPackageName();
        String title = extras.getString("android.title", "");
        String text = extras.getString("android.text", "");

        Log.d("NotificationHandler", "Package: " + packageName + ", Title: " + title + ", Text: " + text);

        if (methodChannel != null) {
            methodChannel.invokeMethod("onNotification", createNotificationMap(packageName, title, text));
        } else {
            Log.w("NotificationHandler", "MethodChannel is null. Cannot send notification to Flutter.");
        }
    }

    // Called from MainActivity to set the MethodChannel
    public static void setMethodChannel(BinaryMessenger messenger, String channelName) {
        methodChannel = new MethodChannel(messenger, channelName);
    }

    // Create map to send to Flutter
    private static Map<String, Object> createNotificationMap(String packageName, String title, String text) {
        Map<String, Object> map = new HashMap<>();
        map.put("package", packageName);
        map.put("title", title);
        map.put("text", text);
        return map;
    }
}
