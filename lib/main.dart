import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:overlay_support/overlay_support.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:timeago/timeago.dart' as timeago;

// --- Color Palette ---
const Color kDarkBackgroundColor = Color(0xFF1A1E23);
const Color kPrimaryGreenColor = Color(0xFF39D29A);
const Color kCardBackgroundColor = Color(0xFF232832);
const Color kSubtleBorderColor = Color(0x4D39D29A);
const Color kFadedTextColor = Colors.grey;

// --- History Item Model ---
// A simple class to hold the data for each detected event.
class HistoryItem {
  final String message;
  final String result; // "Scam" or "Safe"
  final bool isScam;
  final DateTime timestamp;

  HistoryItem({
    required this.message,
    required this.result,
    required this.isScam,
    required this.timestamp,
  });
}

void main() {
  // Wrap the app with OverlaySupport for notifications
  runApp(const OverlaySupport.global(child: MyApp()));
}

// Main App
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Security App',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: kDarkBackgroundColor,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MainNavigationScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Main Navigation Screen with Bottom Navigation
// This is now the main stateful widget holding the scam detection logic.
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  MainNavigationScreenState createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  
  // --- SCAM DETECTION LOGIC INTEGRATED HERE ---
  static const platform = MethodChannel('notificationListener');
  final String apiUrl = "https://d0d355793b63.ngrok-free.app/check";
  final String secretKey = "E8n-5SP7s0hOY9znRvqdVbwKcLzKhAAlS6utQw0WKKI=";

  late encrypt.Encrypter encrypter;
  late encrypt.Key key;

  // List to store scam/safe results
  final List<HistoryItem> _history = [];

  @override
  void initState() {
    super.initState();
    
    // Initialize encryption
    key = encrypt.Key.fromBase64(secretKey);
    encrypter = encrypt.Encrypter(encrypt.Fernet(key));

    // Set up notification listener from native side
    platform.setMethodCallHandler(_handleNotification);

    // Prompt user to enable notification access on first launch
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
      // Show initial "checking" notification
      showSimpleNotification(
        const Text("Checking message..."),
        subtitle: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
        background: Colors.blue,
        duration: const Duration(seconds: 3),
      );

      // Send to backend for scam detection
      sendMessageToModel(message).then((probability) {
        final bool isScam = probability >= 0.6;
        final String label = isScam ? "🚨 Scam Detected" : "✅ Message is Safe";
        final Color color = isScam ? Colors.red : Colors.green;

        // Show final result notification
        showSimpleNotification(
          Text(label),
          subtitle: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
          background: color,
          duration: const Duration(seconds: 15),
        );
        
        // Add the result to our history list
        setState(() {
          _history.insert(0, HistoryItem(
            message: message, 
            result: isScam ? "Potential scam blocked" : "Message determined to be safe", 
            isScam: isScam, 
            timestamp: DateTime.now()
          ));
        });
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
  // --- END OF SCAM DETECTION LOGIC ---

  late final List<Widget> _screens;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
      // We initialize this here to pass the history list and the request function
    _screens = [
      HomeScreen(history: _history),
      SettingsScreen(onRequestNotificationAccess: _requestNotificationAccess),
      const AccountScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        height: 80,
        decoration: BoxDecoration(
          color: kCardBackgroundColor,
          border: Border(
            top: BorderSide(
              color: Colors.white.withAlpha(26),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home, 'Home'),
            _buildNavItem(1, Icons.settings, 'Settings'),
            _buildNavItem(2, Icons.person, 'Account'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? kPrimaryGreenColor : kFadedTextColor,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? kPrimaryGreenColor : kFadedTextColor,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// Home Screen (Main Security Status)
class HomeScreen extends StatefulWidget {
  final List<HistoryItem> history;
  const HomeScreen({super.key, required this.history});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _progressController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final circleDiameter = screenSize.width * 0.75;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: 0.4 + (_pulseController.value * 0.6),
                          child: CustomPaint(
                            size: Size(circleDiameter, circleDiameter),
                            painter: CircuitPainter(animation: _pulseController, seed: 1),
                          ),
                        );
                      },
                    ),
                    AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _progressController.value * 2 * pi,
                          child: CustomPaint(
                            size: Size(circleDiameter, circleDiameter),
                            painter: CircuitPainter(animation: _progressController, seed: 2),
                          ),
                        );
                      },
                    ),
                    Container(
                      width: circleDiameter * 0.6,
                      height: circleDiameter * 0.6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kDarkBackgroundColor.withAlpha(230),
                        border: Border.all(
                          color: kSubtleBorderColor.withAlpha(128),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: kPrimaryGreenColor,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: kDarkBackgroundColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Protected',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Live Status',
                            style: TextStyle(
                              color: kPrimaryGreenColor,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: index == 0 ? kPrimaryGreenColor : kSubtleBorderColor.withAlpha(128),
                                  shape: BoxShape.circle,
                                ),
                              );
                            }),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 60),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            // Pass the dynamic history list to the next screen
                            builder: (context) => ProtectionHistoryScreen(history: widget.history),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kCardBackgroundColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: kSubtleBorderColor,
                            width: 1,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Protection History',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Protection History Screen
class ProtectionHistoryScreen extends StatelessWidget {
  // Accepts the list of history items
  final List<HistoryItem> history;
  const ProtectionHistoryScreen({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Protection History',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              // If history is empty, show a message. Otherwise, show the list.
              child: history.isEmpty 
              ? const Center(
                  child: Text(
                    "No events recorded yet.",
                    style: TextStyle(color: kFadedTextColor, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final item = history[index];
                    // New logic to determine the description based on the scam status
                    final String description = item.isScam
                        ? 'High probability of malicious intent. Look for suspicious links, urgent language, and requests for personal info.'
                        : 'The content did not match known scam patterns. It appears to be legitimate and safe.';
                    return _buildHistoryItem(
                      item.message,
                      item.result,
                      description, // Pass the new description here
                      timeago.format(item.timestamp), // Format timestamp nicely
                      item.isScam ? Icons.warning_amber_rounded : Icons.shield_outlined,
                      !item.isScam
                    );
                  },
                ),
            ),
          ],
        ),
      ),
    );
  }

  // Updated to include the new description parameter
  Widget _buildHistoryItem(String title, String subtitle, String description, String time, IconData icon, bool isSuccess) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: kSubtleBorderColor.withAlpha(128),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSuccess ? kPrimaryGreenColor : Colors.orange,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: kFadedTextColor,
                    fontSize: 14,
                  ),
                ),
                // New Text widget for the description
                Text(
                  description,
                  style: const TextStyle(
                    color: kFadedTextColor,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: const TextStyle(
              color: kFadedTextColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// Settings Screen
class SettingsScreen extends StatefulWidget {
  final VoidCallback onRequestNotificationAccess;
  const SettingsScreen({super.key, required this.onRequestNotificationAccess});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  Map<String, bool> settings = {
    'realTimeProtection': true,
    'autoScan': true,
    'notifications': false,
  };

  void _toggleSetting(String key) {
    setState(() {
      settings[key] = !settings[key]!;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // This item now has an action to request permissions
                  _buildSettingsItem('Enable Notification Access', 'Required for real-time protection', Icons.notifications_active, 'realTimeProtection', isButton: true),
                  _buildSettingsItem('Auto Scan', 'Schedule automatic scans', Icons.schedule, 'autoScan'),
                  _buildSettingsItem('Security Alerts', 'Receive alerts for critical issues', Icons.notifications, 'notifications'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem(String title, String subtitle, IconData icon, String settingKey, {bool isButton = false}) {
    return GestureDetector(
      onTap: isButton ? widget.onRequestNotificationAccess : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCardBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: kSubtleBorderColor.withAlpha(128),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: kPrimaryGreenColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: kFadedTextColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (isButton)
              const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16)
            else
              Switch(
                value: settings[settingKey] ?? false,
                onChanged: (value) => _toggleSetting(settingKey),
                activeTrackColor: kPrimaryGreenColor,
                activeColor: Colors.white,
              ),
          ],
        ),
      ),
    );
  }
}

// Account Screen (No changes needed)
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'Account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: kPrimaryGreenColor,
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'John Doe',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Premium User',
                    style: TextStyle(
                      color: kPrimaryGreenColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildAccountItem('Profile Settings', Icons.person_outline),
                  _buildAccountItem('Subscription', Icons.card_membership),
                  _buildAccountItem('Privacy Policy', Icons.privacy_tip_outlined),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withAlpha(26),
                        foregroundColor: Colors.red,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.red.withAlpha(128),
                            width: 1,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountItem(String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: kCardBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: kSubtleBorderColor.withAlpha(128),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: kPrimaryGreenColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
        ],
      ),
    );
  }
}

// CircuitPainter (No changes needed)
class CircuitPainter extends CustomPainter {
  final Animation<double> animation;
  final int seed;

  CircuitPainter({required this.animation, required this.seed}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final random = Random(seed);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
      
    final innerRadiusLimit = radius * 0.4;
    final innerDotCount = 80;
    for (int i = 0; i < innerDotCount; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final dist = random.nextDouble() * innerRadiusLimit;
      final x = center.dx + dist * cos(angle);
      final y = center.dy + dist * sin(angle);

      paint.color = kPrimaryGreenColor.withAlpha((50 + random.nextInt(150)));
      paint.strokeWidth = 1.0 + random.nextDouble() * 1.5;
      canvas.drawCircle(Offset(x, y), 0.5 + random.nextDouble() * 1.5, paint);

      if (random.nextDouble() > 0.6) {
        final lineLength = 5.0 + random.nextDouble() * 15;
        final lineAngle = random.nextDouble() * 2 * pi;
        final endX = x + lineLength * cos(lineAngle);
        final endY = y + lineLength * sin(lineAngle);
        paint.strokeWidth = 0.5 + random.nextDouble() * 1.0;
        canvas.drawLine(Offset(x, y), Offset(endX, endY), paint);
      }
    }

    final dotCount = 40;
    for (int i = 0; i < dotCount; i++) {
      final angle = (2 * pi / dotCount) * i + (animation.value * 0.2);
      final dotRadius = radius * (0.8 + random.nextDouble() * 0.2);
      final x = center.dx + dotRadius * cos(angle);
      final y = center.dy + dotRadius * sin(angle);
      paint.color = kPrimaryGreenColor.withAlpha((80 + (170 * random.nextDouble())).toInt());
      paint.strokeWidth = 1.0;
      canvas.drawCircle(Offset(x, y), 1.5, paint);
    }

    final ringCount = 5;
    for (int i = 0; i < ringCount; i++) {
      final ringRadius = radius * (0.3 + (i * 0.14));
      if (ringRadius < innerRadiusLimit * 1.2 && random.nextDouble() > 0.5) continue;

      if (random.nextBool()) {
        final dashWidth = 10.0 + random.nextDouble() * 5;
        final dashSpace = 8.0 + random.nextDouble() * 5;
        double startAngle = random.nextDouble() * pi;
        final sweep = pi * (0.5 + random.nextDouble() * 1.5);
        for (double d = startAngle; d < startAngle + sweep; d += (dashWidth + dashSpace) / ringRadius) {
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: ringRadius),
            d,
            dashWidth / ringRadius,
            false,
            paint..color = kPrimaryGreenColor.withAlpha(50 + random.nextInt(100)).withBlue(random.nextInt(50)).withRed(random.nextInt(50))
                ..strokeWidth = 0.5 + random.nextDouble(),
          );
        }
      } else {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: ringRadius),
          random.nextDouble() * 2 * pi,
          pi * (0.5 + random.nextDouble() * 1.5),
          false,
          paint..color = kPrimaryGreenColor.withAlpha(50 + random.nextInt(100)).withBlue(random.nextInt(50)).withRed(random.nextInt(50))
               ..strokeWidth = 0.5 + random.nextDouble(),
        );
      }
    }

    final traceCount = 40;
    for (int i = 0; i < traceCount; i++) {
      final startRadiusFactor = random.nextDouble();
      final endRadiusFactor = random.nextDouble();
      final startRadius = radius * startRadiusFactor;
      final endRadius = radius * endRadiusFactor;
      final angle1 = random.nextDouble() * 2 * pi;
      final angle2 = random.nextDouble() * 2 * pi;
      final startPoint = Offset(
        center.dx + startRadius * cos(angle1),
        center.dy + startRadius * sin(angle1),
      );
      final endPoint = Offset(
        center.dx + endRadius * cos(angle2),
        center.dy + endRadius * sin(angle2),
      );
      paint.color = kPrimaryGreenColor.withAlpha(100 + random.nextInt(155));
      paint.strokeWidth = 0.5 + random.nextDouble() * 1.5;
      canvas.drawLine(startPoint, endPoint, paint);

      if (random.nextDouble() > 0.7) {
        canvas.drawCircle(startPoint, 1.0 + random.nextDouble(), paint..strokeWidth = 0.5);
      }
      if (random.nextDouble() > 0.7) {
        canvas.drawCircle(endPoint, 1.0 + random.nextDouble(), paint..strokeWidth = 0.5);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CircuitPainter oldDelegate) {
    return animation.value != oldDelegate.animation.value || seed != oldDelegate.seed;
  }
}