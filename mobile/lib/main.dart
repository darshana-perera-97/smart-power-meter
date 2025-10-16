import 'package:flutter/material.dart';
import 'firebase_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Power Meter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          brightness: Brightness.light,
          primary: Colors.black,
          onPrimary: Colors.white,
          secondary: Colors.grey,
          onSecondary: Colors.black,
          surface: Colors.white,
          onSurface: Colors.black,
          background: Colors.white,
          onBackground: Colors.black,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.black, width: 1),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      home: const PowerMeterHomePage(),
    );
  }
}

class PowerMeterHomePage extends StatefulWidget {
  const PowerMeterHomePage({super.key});

  @override
  State<PowerMeterHomePage> createState() => _PowerMeterHomePageState();
}

class _PowerMeterHomePageState extends State<PowerMeterHomePage> {
  PowerMeterData? _currentData;
  PowerMeterData? _lastData;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    // Auto-refresh every 2 seconds to check for key changes
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _loadData();
        _startAutoRefresh(); // Continue auto-refresh
      }
    });
  }

  Future<void> _loadData() async {
    try {
      final data = await FirebaseService.getCurrentPowerMeterData();
      setState(() {
        _lastData = _currentData;
        _currentData = data;
        _isLoading = false;
        _errorMessage = '';
      });
    } catch (e) {
    setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Power Meter'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildSplashScreen() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo/Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: const Icon(
                Icons.flash_on,
                color: Colors.white,
                size: 60,
              ),
            ),
            const SizedBox(height: 30),
            
            // App Title
            const Text(
              'Smart Power Meter',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            
            // Subtitle
            const Text(
              'Real-time Power Monitoring',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),
            
            // Loading Indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            
            // Loading Text
            const Text(
              'Connecting to power meter...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildSplashScreen();
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.black,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.black),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_currentData == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.power_off,
              size: 64,
              color: Colors.black,
            ),
            SizedBox(height: 16),
            Text('No data available'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildPowerCard(),
          const SizedBox(height: 16),
          _buildVoltageCurrentCard(),
          const SizedBox(height: 16),
          _buildDeviceInfoCard(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    // Check if device is live based on key changes
    bool isLive = false;
    if (_currentData != null && _lastData != null) {
      isLive = _currentData!.key != _lastData!.key;
    } else if (_currentData != null) {
      // First load - consider it live if we have data
      isLive = true;
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isLive ? Icons.wifi : Icons.wifi_off,
              color: isLive ? Colors.black : Colors.grey,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Device Status',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    isLive ? 'Live' : 'Offline',
                    style: TextStyle(
                      color: isLive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'Key: ${_currentData?.key ?? 0}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerCard() {
    // Check if device is live based on key changes
    bool isLive = false;
    if (_currentData != null && _lastData != null) {
      isLive = _currentData!.key != _lastData!.key;
    } else if (_currentData != null) {
      isLive = true;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Power Consumption',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSimpleMetric(
                    'Live Power',
                    isLive ? '${_currentData!.livePower.toStringAsFixed(2)} W' : '0.00 W',
                    Icons.flash_on,
                    isLive ? Colors.black : Colors.grey,
                  ),
                ),
                Expanded(
                  child: _buildSimpleMetric(
                    'Total Power',
                    '${_currentData!.totalPower.toStringAsFixed(2)} kWh',
                    Icons.battery_charging_full,
                    Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoltageCurrentCard() {
    // Check if device is live based on key changes
    bool isLive = false;
    if (_currentData != null && _lastData != null) {
      isLive = _currentData!.key != _lastData!.key;
    } else if (_currentData != null) {
      isLive = true;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Electrical Parameters',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSimpleMetric(
                    'Voltage',
                    isLive ? '${_currentData!.voltage.toStringAsFixed(1)} V' : '0.0 V',
                    Icons.electrical_services,
                    isLive ? Colors.black : Colors.grey,
                  ),
                ),
                Expanded(
                  child: _buildSimpleMetric(
                    'Current',
                    isLive ? '${_currentData!.current.toStringAsFixed(3)} A' : '0.000 A',
                    Icons.electric_bolt,
                    isLive ? Colors.black : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Device Information',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Device ID: ${_currentData!.device}'),
            Text('Last Updated: ${_currentData!.timestamp.toString().substring(0, 19)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleMetric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}