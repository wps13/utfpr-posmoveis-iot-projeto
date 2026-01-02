import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  static const String _broker = '127.0.0.1';
  static const int _port = 1883;
  static const String _topic = 'room/app';
  static const String _clientId = 'smart_lamp_flutter_client';

  MqttServerClient? _client;
  final _lampStateController = StreamController<bool>.broadcast();

  Stream<bool> get lampStateStream => _lampStateController.stream;

  Future<void> connect() async {
    _client = MqttServerClient(_broker, _clientId);
    _client!.port = _port;
    _client!.logging(on: false);
    _client!.keepAlivePeriod = 60;
    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;
    _client!.autoReconnect = true;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(_clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    _client!.connectionMessage = connMessage;

    try {
      debugPrint('MQTT: Connecting to broker at $_broker:$_port...');
      await _client!.connect();
    } on NoConnectionException catch (e) {
      debugPrint('MQTT: Connection exception - $e');
      _client!.disconnect();
      return;
    } on SocketException catch (e) {
      debugPrint('MQTT: Socket exception - $e');
      _client!.disconnect();
      return;
    }

    if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
      debugPrint('MQTT: Connected successfully');
      _subscribeToTopic();
    } else {
      debugPrint(
        'MQTT: Connection failed - status: ${_client!.connectionStatus}',
      );
      _client!.disconnect();
    }
  }

  void _subscribeToTopic() {
    debugPrint('MQTT: Subscribing to topic: $_topic');
    _client!.subscribe(_topic, MqttQos.atLeastOnce);

    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      final recMess = messages[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(
        recMess.payload.message,
      );

      debugPrint(
        'MQTT: Received message on topic ${messages[0].topic}: $payload',
      );

      // Parse the message to determine lamp state
      final isOn = _parseMessage(payload);
      _lampStateController.add(isOn);
    });
  }

  bool _parseMessage(String message) {
    final trimmed = message.trim();

    // Handle "0" or "1" strings
    if (trimmed == '1') {
      return true;
    } else if (trimmed == '0') {
      return false;
    }

    // Fallback: try to parse as integer
    final intValue = int.tryParse(trimmed);
    if (intValue != null) {
      return intValue != 0;
    }

    // Default to off if unable to parse
    debugPrint('MQTT: Unable to parse message "$message", defaulting to OFF');
    return false;
  }

  void _onConnected() {
    debugPrint('MQTT: Client connected');
  }

  void _onDisconnected() {
    debugPrint('MQTT: Client disconnected');
  }

  void disconnect() {
    debugPrint('MQTT: Disconnecting...');
    _client?.disconnect();
  }

  void dispose() {
    disconnect();
    _lampStateController.close();
  }
}
