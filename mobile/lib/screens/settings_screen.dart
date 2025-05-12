import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../services/user_settings_service.dart';
import '../services/data_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final NotificationService _notificationService;
  late final AuthService _authService;
  late final UserSettingsService _settingsService;
  late final DataService _dataService;

  String? _userEmail;
  Map<String, dynamic> _settings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService();
    _authService = AuthService();
    _settingsService = UserSettingsService();
    _dataService = DataService();
    _loadSettings();
    _loadUserInfo();
  }

  void _loadSettings() {
    // Listen to settings changes
    _settingsService.settingsStream.listen((settings) {
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    });

    // Get current settings
    _settings = _settingsService.currentSettings;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadUserInfo() async {
    final email = await _authService.getCurrentUserEmail();
    setState(() {
      _userEmail = email;
    });
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    await _settingsService.updateSettings({key: value});

    // Update notification service if needed
    if (key == 'notifications') {
      await _notificationService.updateSettings(
        healthAdviceEnabled: value,
        extremeValueAlertsEnabled: value,
        dailyReportsEnabled: value,
      );
    }
  }

  Future<void> _updateNestedSetting(String path, dynamic value) async {
    await _settingsService.updateNestedSetting(path, value);
  }

  Future<void> _updateRefreshRate(int seconds) async {
    await _settingsService.updateSettings({'refresh_rate': seconds});
    await _dataService.updateRefreshRate(seconds);
  }

  Future<void> _logout() async {
    // Show a confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout ?? false) {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // User Info Section
          _buildSectionTitle('Account'),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Email'),
            subtitle: Text(_userEmail ?? 'Not logged in'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: _logout,
          ),

          const SizedBox(height: 24),
          _buildSectionTitle('Data Settings'),
          const SizedBox(height: 8),

          // Refresh Rate Setting
          _buildRefreshRateOption(),

          const SizedBox(height: 24),
          _buildSectionTitle('Notifications'),
          const SizedBox(height: 8),

          // Health Advice Toggle
          _buildToggleOption(
            title: 'Health Advice',
            subtitle: 'Receive periodic health advice based on air quality',
            value: _settings['health_advice_enabled'] ?? true,
            onChanged: (value) =>
                _updateSetting('health_advice_enabled', value),
          ),

          const Divider(),

          // Extreme Value Alerts Toggle
          _buildToggleOption(
            title: 'Extreme Value Alerts',
            subtitle: 'Receive alerts when sensors detect extreme values',
            value: _settings['extreme_value_alerts_enabled'] ?? true,
            onChanged: (value) =>
                _updateSetting('extreme_value_alerts_enabled', value),
          ),

          const Divider(),

          // Daily Reports Toggle
          _buildToggleOption(
            title: 'Daily Reports',
            subtitle: 'Receive daily air quality reports at 5 PM',
            value: _settings['daily_reports_enabled'] ?? true,
            onChanged: (value) =>
                _updateSetting('daily_reports_enabled', value),
          ),

          const SizedBox(height: 24),
          _buildSectionTitle('Sensor Thresholds'),
          const SizedBox(height: 8),

          // Threshold Settings
          _buildThresholdOption('CO2', 'ppm', 'thresholds.co2'),
          _buildThresholdOption('PM2.5', 'μg/m³', 'thresholds.pm25'),
          _buildThresholdOption('PM10', 'μg/m³', 'thresholds.pm10'),
          _buildThresholdOption('VOC', 'mg/m³', 'thresholds.voc'),

          const SizedBox(height: 32),
          _buildSectionTitle('About'),
          const SizedBox(height: 8),
          const ListTile(
            title: Text('Air Quality Monitor'),
            subtitle: Text('Version 1.0.0'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildToggleOption({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildRefreshRateOption() {
    final refreshRate = _settings['refresh_rate'] ?? 30;
    final options = [5, 10, 30, 60, 300]; // 5s, 10s, 30s, 1min, 5min

    return ListTile(
      title: const Text('Data Refresh Rate'),
      subtitle: Text(_formatRefreshRate(refreshRate)),
      trailing: DropdownButton<int>(
        value: options.contains(refreshRate) ? refreshRate : 30,
        items: options.map((seconds) {
          return DropdownMenuItem(
            value: seconds,
            child: Text(_formatRefreshRate(seconds)),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            _updateRefreshRate(value);
          }
        },
      ),
    );
  }

  Widget _buildThresholdOption(String sensorName, String unit, String path) {
    final currentValue = _settingsService.getNestedSetting<num>(path) ?? 0;

    return ListTile(
      title: Text('$sensorName Threshold'),
      subtitle: Text('Current: $currentValue $unit'),
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () =>
            _showThresholdEditDialog(sensorName, unit, path, currentValue),
      ),
    );
  }

  String _formatRefreshRate(int seconds) {
    if (seconds < 60) {
      return '$seconds seconds';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    } else {
      final hours = seconds ~/ 3600;
      return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    }
  }

  Future<void> _showThresholdEditDialog(
      String sensorName, String unit, String path, num currentValue) async {
    final controller = TextEditingController(text: currentValue.toString());

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set $sensorName Threshold'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Threshold value',
            suffixText: unit,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      final newValue = num.tryParse(result);
      if (newValue != null) {
        await _updateNestedSetting(path, newValue);
      }
    }

    controller.dispose();
  }
}
