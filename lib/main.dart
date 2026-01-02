import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_lamp/services/mqtt_service.dart';
import 'dart:async';

class LampStateNotifier with ChangeNotifier {
  bool _isLampOn = false;
  final MqttService _mqttService = MqttService();
  StreamSubscription<bool>? _mqttSubscription;

  LampStateNotifier() {
    _initializeMqtt();
  }

  bool get isLampOn => _isLampOn;

  Future<void> _initializeMqtt() async {
    // Connect to MQTT broker
    await _mqttService.connect();

    // Subscribe to lamp state updates from MQTT
    _mqttSubscription = _mqttService.lampStateStream.listen((isOn) {
      _isLampOn = isOn;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _mqttSubscription?.cancel();
    _mqttService.dispose();
    super.dispose();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LampStateNotifier>(
      create: (context) => LampStateNotifier(),
      builder: (context, child) => MaterialApp(
        title: 'App de controle de lâmpada',
        theme: ThemeData(
          primarySwatch: Colors.blueGrey,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const LampStatusPage(),
      ),
    );
  }
}

class LampStatusPage extends StatelessWidget {
  const LampStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lâmpada inteligente')),
      body: Center(
        child: Consumer<LampStateNotifier>(
          builder: (context, lampState, child) {
            final bool isLampOn = lampState.isLampOn;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  isLampOn ? Icons.lightbulb : Icons.lightbulb_outline,
                  color: isLampOn ? Colors.yellow[700] : Colors.grey[400],
                  size: 150.0,
                ),
                const SizedBox(height: 30),
                Text(
                  isLampOn ? 'Lâmpada ligada' : 'Lâmpada desligada',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: isLampOn ? Colors.green : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

void main() {
  runApp(const MyApp());
}
