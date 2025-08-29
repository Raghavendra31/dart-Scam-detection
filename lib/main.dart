import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:overlay_support/overlay_support.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

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

  // Change to your ngrok endpoint or PC IP
  final String apiUrl = "https://7e51381214c1.ngrok-free.app/check";

  // Encryption key (Fernet Base64)
  final String secretKey = "LhUNV5gb0I4jxj8dyyh2EYg-p7v8349H9dsR_GPI664=";

  late encrypt.Encrypter encrypter;
  late encrypt.Key key;

  @override
  void initState() {
    super.initState();

    key = encrypt.Key.fromBase64(secretKey);
    encrypter = encrypt.Encrypter(encrypt.Fernet(key));

    // Set up notification listener
    platform.setMethodCallHandler(_handleNotification);

    // Prompt user to enable notification access
    _requestNotificationAccess();
  }

  Future<void> _requestNotificationAccess() async {
    try {
      await platform.invokeMethod('requestNotificationAccess');
    } catch (e) {
      debugPrint("Could not open notification access settings: $e");
    }
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
      // Show initial notification
      showSimpleNotification(
        const Text("Checking message..."),
        subtitle: Text(message),
        background: Colors.blue,
        duration: const Duration(seconds: 3),
      );

      // Send to backend for scam detection
      sendMessageToModel(message).then((probability) {
        // Convert probability to label
        final String label = probability >= 0.6 ? "🚨 Scam" : "✅ Safe";
        final Color color = probability >= 0.6 ? Colors.red : Colors.green;

        // Show notification with label and message
        showSimpleNotification(
          Text(label),
          subtitle: Text(message),
          background: color,
          duration: const Duration(seconds: 15),
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

  Future<double> sendMessageToModel(String message) async {
    try {
      // Encrypt message
      final encrypted = encrypter.encrypt(message).base64;
      debugPrint("📤 Encrypted outgoing message: $encrypted");

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'data': encrypted}),
      );

      debugPrint("📥 Raw server response: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Use the correct key from your backend
        final probability = (data['scam_probability'] ?? 0.0).toDouble();
        return probability;
      } else {
        debugPrint("❌ Server error: ${response.statusCode}");
        return 0.0;
      }
    } catch (e) {
      debugPrint("❌ Network error: $e");
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            "🚨 scam detector is running in background",
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
