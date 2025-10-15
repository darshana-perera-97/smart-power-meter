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

  // Get current data from Firebase Realtime Database
  static Future<PowerMeterData?> getCurrentPowerMeterData() async {
    try {
      final url = '$_baseUrl$_dataPath?auth=$_apiKey';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return PowerMeterData.fromMap(data);
      } else {
        print('HTTP Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting power meter data: $e');
      return null;
    }
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
