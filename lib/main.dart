import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Helmet App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Smart Helmet Dashboard'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  double _acceleration = 0.0;
  bool _alertActive = false;
  int _countdown = 30;
  Timer? _sensorTimer;
  Timer? _alertTimer;

  @override
  void initState() {
    super.initState();
    _startMockSensorData();
  }

  void _startMockSensorData() {
    _sensorTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _acceleration = Random().nextDouble() * 10;
        if (_acceleration > 7.0) {
          _startAlertCountdown();
        }
      });
    });
  }

  void _startAlertCountdown() {
    if (_alertActive) return;
    setState(() {
      _alertActive = true;
      _countdown = 30;
    });
    _alertTimer?.cancel();
    _alertTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
        _sendEmergencyAlert();
      }
    });
  }

  void _sendEmergencyAlert() {
    print("Emergency alert sent to family members!");
    _makePhoneCall('3179910554'); //my phone number as of now
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      print("Could not launch \$phoneNumber");
    }
  }

  void _cancelAlert() {
    setState(() {
      _alertActive = false;
    });
    _alertTimer?.cancel();
  }

  @override
  void dispose() {
    _sensorTimer?.cancel();
    _alertTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Real-Time IMU Sensor Data:'),
            Text(
              'Acceleration: \${_acceleration.toStringAsFixed(2)} m/s²',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 30),

            ElevatedButton(
            onPressed: () => _makePhoneCall('1234567890'), // Replace with real number
            child: const Text('Test Emergency Call'),
          ),
            if (_alertActive)
              Column(
                children: [
                  const Text(
                    'Alert! Crash detected.',
                    style: TextStyle(color: Colors.red, fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: _countdown / 30,
                          strokeWidth: 8,
                          color: Colors.red,
                        ),
                      ),
                      Text(
                        '\$_countdown',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _cancelAlert,
                    child: const Text('I am okay'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
