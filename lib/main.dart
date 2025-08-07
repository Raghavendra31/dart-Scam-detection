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
    platform.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == "onNotification") {
      final Map<dynamic, dynamic> notification = Map.from(call.arguments);
      _processNotification(notification);
    }
  }

  Future<void> _processNotification(Map notification) async {
    final String package = notification['package'] ?? '';
    final String title = notification['title'] ?? '';
    final String text = notification['text'] ?? '';
    final String message = "$title\n$text";

    if (package.contains("whatsapp") ||
        package.contains("telegram") ||
        package.contains("instagram")) {
      final result = await sendMessageToModel(message);
      showSimpleNotification(
        Text("Detected: $result"),
        subtitle: Text(message),
        background: result.toLowerCase() == "scam" ? Colors.red : Colors.green,
        duration: const Duration(seconds: 4),
      );
    }
  }

  Future<String> sendMessageToModel(String message) async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.39:5000/check'), // ✅ fixed endpoint
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prediction = data['prediction'] ?? 0;

        // ✅ Convert prediction to label
        return prediction == 1 ? "Scam" : "Safe";
      } else {
        return "Server Error";
      }
    } catch (e) {
      debugPrint("Error contacting model: $e");
      return "Network Error";
    }
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text("Scam Detector is running in background"),
        ),
      ),
    );
  }
}
