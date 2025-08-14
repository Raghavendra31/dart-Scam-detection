import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:overlay_support/overlay_support.dart';

void main() {
  runApp(const OverlaySupport.global(child: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const platform = MethodChannel('notificationListener');

  // Change to your active ngrok endpoint
  final String apiUrl = "https://ac4e71263aac.ngrok-free.app/check";

  @override
  void initState() {
    super.initState();
    platform.setMethodCallHandler(_handleNotification);
  }

  Future<void> _handleNotification(MethodCall call) async {
    if (call.method == "onNotification") {
      final Map<String, dynamic> notification =
          Map<String, dynamic>.from(call.arguments);
      _processNotification(notification);
    }
  }

  void _processNotification(Map<String, dynamic> notification) {
    final String package = notification['package'] ?? '';
    final String title = notification['title'] ?? '';
    final String text = notification['text'] ?? '';
    final String message = "$title\n$text";

    if (_isSocialApp(package)) {
      // Show instant "Checking..." banner
      showSimpleNotification(
        Text("Checking message..."),
        subtitle: Text(message),
        background: Colors.blue,
        duration: const Duration(seconds: 3),
      );

      // Run scam detection
      sendMessageToModel(message).then((result) {
        showSimpleNotification(
          Text("Detected: $result"),
          subtitle: Text(message),
          background:
              result.toLowerCase() == "scam" ? Colors.red : Colors.green,
          duration: const Duration(seconds: 5),
        );
      });
    }

    debugPrint("Notification from: $package\n$message");
  }

  bool _isSocialApp(String package) {
    return package.contains("whatsapp") ||
        package.contains("telegram") ||
        package.contains("instagram");
  }

  Future<String> sendMessageToModel(String message) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prediction = data['prediction'] ?? 0;
        return prediction == 1 ? "Scam" : "Safe";
      } else {
        debugPrint("❌ Server error: ${response.statusCode}");
        return "Server Error";
      }
    } catch (e) {
      debugPrint("❌ Network error: $e");
      return "Network Error";
    }
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            "🚨 Scam Detector is running in background",
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}


// ngrok http 5000 