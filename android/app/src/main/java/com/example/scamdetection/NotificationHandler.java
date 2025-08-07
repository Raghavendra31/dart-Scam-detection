package com.example.scamdetection;

import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.os.Bundle;
import android.util.Log;

import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.BinaryMessenger;

public class NotificationHandler extends NotificationListenerService {

    private static MethodChannel channel;

    public static void setMethodChannel(BinaryMessenger messenger, String channelName) {
        channel = new MethodChannel(messenger, channelName);
    }

    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        String packageName = sbn.getPackageName();
        Bundle extras = sbn.getNotification().extras;

        String title = extras.getString("android.title", "");
        String text = extras.getString("android.text", "");

        if (channel != null) {
            try {
                channel.invokeMethod("onNotification", createNotificationMap(packageName, title, text));
            } catch (Exception e) {
                Log.e("NotificationHandler", "Error sending notification to Flutter", e);
            }
        }
    }

    private static java.util.Map<String, String> createNotificationMap(String pkg, String title, String text) {
        java.util.Map<String, String> map = new java.util.HashMap<>();
        map.put("package", pkg);
        map.put("title", title);
        map.put("text", text);
        return map;
    }
}
