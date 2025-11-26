import 'dart:convert';
import 'package:http/http.dart' as http;

class PowerMeterData {
  final double voltage;
  final double current;
  final double livePower;
  final double totalPower;
  final int battery;
  final String device;
  final int key;
  final String status;
  final DateTime timestamp;

  PowerMeterData({
    required this.voltage,
    required this.current,
    required this.livePower,
    required this.totalPower,
    required this.battery,
    required this.device,
    required this.key,
    required this.status,
    required this.timestamp,
  });

  factory PowerMeterData.fromMap(Map<String, dynamic> map) {
    return PowerMeterData(
      voltage: (map['voltage'] ?? 0.0).toDouble(),
      current: (map['current'] ?? 0.0).toDouble(),
      livePower: (map['livepower'] ?? 0.0).toDouble(),
      totalPower: (map['totalpower'] ?? 0.0).toDouble(),
      battery: map['battery'] ?? 0,
      device: map['device'] ?? '',
      key: map['key'] ?? 0,
      status: map['status'] ?? '',
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'voltage': voltage,
      'current': current,
      'livepower': livePower,
      'totalpower': totalPower,
      'battery': battery,
      'device': device,
      'key': key,
      'status': status,
    };
  }
}

class FirebaseService {
  static const String _baseUrl = 'https://power-meter-7d423-default-rtdb.asia-southeast1.firebasedatabase.app';
  static const String _apiKey = 'AIzaSyCM3qjVP_Y5OBKs0ti8aZbbWbaasx-dhAM';
  static const String _dataPath = '/002.json';
  static const String _switchPath = '/switch/002.json';

  // Get current data from Firebase Realtime Database
  static Future<PowerMeterData?> getCurrentPowerMeterData() async {
    try {
      final url = '$_baseUrl$_dataPath?auth=$_apiKey';
      print('Fetching data from: $url');
      final response = await http.get(Uri.parse(url));
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        print('Parsed data: $data');
        return PowerMeterData.fromMap(data);
      } else {
        print('HTTP Error: ${response.statusCode} - ${response.body}');
        // Return mock data for testing when Firebase fails
        return _getMockData();
      }
    } catch (e) {
      print('Error getting power meter data: $e');
      // Return mock data for testing when Firebase fails
      return _getMockData();
    }
  }

  // Mock data for testing when Firebase is not available
  static PowerMeterData _getMockData() {
    print('Using mock data for testing');
    return PowerMeterData(
      voltage: 220.5,
      current: 1.25,
      livePower: 275.6,
      totalPower: 15.8,
      battery: 79,
      device: "003",
      key: 1234, // Fixed key to simulate offline device
      status: "ok",
      timestamp: DateTime.now(),
    );
  }

  static Future<bool> getSwitchState() async {
    final url = '$_baseUrl$_switchPath?auth=$_apiKey';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final decoded = response.body.isEmpty ? false : json.decode(response.body);
      return _parseSwitchValue(decoded);
    }

    throw Exception('Failed to load switch state (${response.statusCode})');
  }

  static Future<void> setSwitchState(bool value) async {
    final url = '$_baseUrl$_switchPath?auth=$_apiKey';
    final response = await http.put(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(value),
    );

    if (response.statusCode >= 400) {
      throw Exception('Failed to update switch state (${response.statusCode})');
    }
  }

  static bool _parseSwitchValue(dynamic raw) {
    if (raw is bool) {
      return raw;
    }
    if (raw is num) {
      return raw != 0;
    }
    if (raw is String) {
      final normalized = raw.toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'on';
    }
    return false;
  }

  // Stream to simulate real-time updates (polling every 2 seconds)
  static Stream<PowerMeterData?> getPowerMeterDataStream() async* {
    while (true) {
      try {
        final data = await getCurrentPowerMeterData();
        yield data;
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        print('Stream error: $e');
        yield null;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  // Get historical data (if you want to store multiple readings)
  static Future<List<PowerMeterData>> getHistoricalData({int limit = 10}) async {
    try {
      final url = '$_baseUrl/history.json?auth=$_apiKey&orderBy="\$key"&limitToLast=$limit';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data.values
            .map((item) => PowerMeterData.fromMap(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error getting historical data: $e');
      return [];
    }
  }
}
