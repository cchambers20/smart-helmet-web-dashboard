import 'package:flutter/material.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_web_bluetooth/flutter_web_bluetooth.dart';
import 'dart:typed_data'; // Needed for Endian

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
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

  Timer? _alertTimer;
  dynamic _connectedDevice;
  dynamic _accelChar;
  dynamic _crashChar;

  @override
  void dispose() {
    _alertTimer?.cancel();
    _disconnectFromDevice();
    super.dispose();
  }

  Future<void> _disconnectFromDevice() async {
    if (_connectedDevice != null) {
      try {
        await _connectedDevice.disconnect();
        print("Device disconnected.");
      } catch (e) {
        print("Error disconnecting device: $e");
      }
    }
  }

  Future<void> _searchAndConnectToBluetoothDevice() async {
    final bluetooth = FlutterWebBluetooth.instance;
    try {
      final isAvailable = await bluetooth.isAvailable.first;
      if (!isAvailable) {
        print("Bluetooth is not available on this browser/device.");
        return;
      }

      final device = await bluetooth.requestDevice(RequestOptionsBuilder.acceptAllDevices());

      if (device == null) {
        print("No device selected.");
        return;
      }

      print("Device selected: ${device.name}");
      await device.connect();

      setState(() {
        _connectedDevice = device;
      });

      final server = await device.gatt!.connect();
      final service = await server.getPrimaryService("your-service-uuid-here");

      _accelChar = await service.getCharacteristic("your-acceleration-char-uuid");
      _crashChar = await service.getCharacteristic("your-crash-char-uuid");

      await _setupNotifications();

      print("Successfully connected to ${device.name}!");
    } catch (e) {
      print("Bluetooth connection error: $e");
    }
  }

  Future<void> _setupNotifications() async {
    await _accelChar.startNotifications();
    _accelChar.valueChanged.listen((value) {
      final accel = value.buffer.asByteData().getFloat32(0, Endian.little);
      setState(() {
        _acceleration = accel;
      });
    });

    await _crashChar.startNotifications();
    _crashChar.valueChanged.listen((value) {
      if (value.isNotEmpty && value[0] == 1) {
        _startAlertCountdown();
      }
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

  void _cancelAlert() {
    setState(() {
      _alertActive = false;
    });
    _alertTimer?.cancel();
  }

  void _sendEmergencyAlert() {
    print("Emergency alert sent to family members!");
    _makePhoneCall('3179910554');
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      print("Could not launch $phoneNumber");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Helmet Status',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.speed, size: 48, color: Colors.blue),
                      const SizedBox(height: 10),
                      Text(
                        'Acceleration',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${_acceleration.toStringAsFixed(2)} m/s²',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: _searchAndConnectToBluetoothDevice,
                icon: const Icon(Icons.bluetooth),
                label: const Text('Connect to Helmet (BLE)'),
              ),
              const SizedBox(height: 10),

              if (_connectedDevice != null)
                Text('Connected to: ${_connectedDevice.name}'),

              const SizedBox(height: 30),

              if (_alertActive)
                Card(
                  color: Colors.red.shade100,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.warning, size: 48, color: Colors.red),
                        const SizedBox(height: 10),
                        const Text(
                          'Crash Detected!',
                          style: TextStyle(color: Colors.red, fontSize: 24, fontWeight: FontWeight.bold),
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
                              '$_countdown',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _cancelAlert,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text('I am okay, cancel alert'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
