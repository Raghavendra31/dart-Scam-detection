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

  @override
  void initState() {
    super.initState();
    platform.setMethodCallHandler(_handleNotification);
  }

  /// Handles incoming method calls from Android
  Future<void> _handleNotification(MethodCall call) async {
    if (call.method == "onNotification") {
      final Map<String, dynamic> notification =
          Map<String, dynamic>.from(call.arguments);
      await _processNotification(notification);
    }
  }

  /// Processes the notification and sends it to the model
  Future<void> _processNotification(Map<String, dynamic> notification) async {
    final String package = notification['package'] ?? '';
    final String title = notification['title'] ?? '';
    final String text = notification['text'] ?? '';
    final String message = "$title\n$text";

    if (_isSocialApp(package)) {
      final String result = await sendMessageToModel(message);
      _showScamNotification(message, result);
    }

    debugPrint("Notification from: $package\n$message");
  }

  /// Checks if the notification is from a social app
  bool _isSocialApp(String package) {
    return package.contains("whatsapp") ||
        package.contains("telegram") ||
        package.contains("instagram");
  }

  /// Sends the message to your Python scam detection model
  Future<String> sendMessageToModel(String message) async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.39:5000/check'), // 🔁 Your Flask API endpoint
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prediction = data['prediction'] ?? 0;
        return prediction == 1 ? "Scam" : "Safe";
      } else {
        return "Server Error";
      }
    } catch (e) {
      debugPrint("❌ Error contacting model: $e");
      return "Network Error";
    }
  }

  /// Shows the scam detection result as a notification banner
  void _showScamNotification(String message, String result) {
    showSimpleNotification(
      Text("Detected: $result"),
      subtitle: Text(message),
      background: result.toLowerCase() == "scam" ? Colors.red : Colors.green,
      duration: const Duration(seconds: 4),
    );
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
