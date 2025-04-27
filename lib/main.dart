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
  double _temperature = 0.0;
  bool _alertActive = false;
  int _countdown = 30;

  Timer? _alertTimer;
  dynamic _connectedDevice;
  dynamic _accelChar;
  dynamic _tempChar;
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
      _tempChar = await service.getCharacteristic("your-temperature-char-uuid");
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

    await _tempChar.startNotifications();
    _tempChar.valueChanged.listen((value) {
      final temp = value.buffer.asByteData().getFloat32(0, Endian.little);
      setState(() {
        _temperature = temp;
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
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('Real-Time IMU Sensor Data:'),
              const SizedBox(height: 10),
              Text(
                'Acceleration: ${_acceleration.toStringAsFixed(2)} m/s²',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                'Temperature: ${_temperature.toStringAsFixed(2)} °C',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => _makePhoneCall('3179910554'),
                child: const Text('Test Emergency Call'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _searchAndConnectToBluetoothDevice,
                child: const Text('Search and Connect to Helmet (BLE)'),
              ),
              const SizedBox(height: 10),
              if (_connectedDevice != null)
                Text('Connected to: ${_connectedDevice.name}'),
              const SizedBox(height: 30),
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
                          '$_countdown',
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
                      child: const Text('I am okay, cancel the call'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
