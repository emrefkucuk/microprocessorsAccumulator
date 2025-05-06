import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final NotificationService _notificationService;
  late final AuthService _authService;
  String? _userEmail;

  bool _healthAdviceEnabled = true;
  bool _extremeValueAlertsEnabled = true;
  bool _dailyReportsEnabled = true;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService();
    _authService = AuthService();
    _loadSettings();
    _loadUserInfo();
  }

  void _loadSettings() {
    setState(() {
      _healthAdviceEnabled = _notificationService.healthAdviceEnabled;
      _extremeValueAlertsEnabled =
          _notificationService.extremeValueAlertsEnabled;
      _dailyReportsEnabled = _notificationService.dailyReportsEnabled;
    });
  }

  Future<void> _loadUserInfo() async {
    final email = await _authService.getCurrentUserEmail();
    setState(() {
      _userEmail = email;
    });
  }

  Future<void> _updateHealthAdviceSettings(bool value) async {
    await _notificationService.updateSettings(healthAdviceEnabled: value);
    setState(() {
      _healthAdviceEnabled = value;
    });
  }

  Future<void> _updateExtremeValueAlertSettings(bool value) async {
    await _notificationService.updateSettings(extremeValueAlertsEnabled: value);
    setState(() {
      _extremeValueAlertsEnabled = value;
    });
  }

  Future<void> _updateDailyReportSettings(bool value) async {
    await _notificationService.updateSettings(dailyReportsEnabled: value);
    setState(() {
      _dailyReportsEnabled = value;
    });
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
          _buildSectionTitle('Notifications'),
          const SizedBox(height: 8),

          // Health Advice Toggle
          _buildToggleOption(
            title: 'Health Advice',
            subtitle: 'Receive periodic health advice based on air quality',
            value: _healthAdviceEnabled,
            onChanged: _updateHealthAdviceSettings,
          ),

          const Divider(),

          // Extreme Value Alerts Toggle
          _buildToggleOption(
            title: 'Extreme Value Alerts',
            subtitle: 'Receive alerts when sensors detect extreme values',
            value: _extremeValueAlertsEnabled,
            onChanged: _updateExtremeValueAlertSettings,
          ),

          const Divider(),

          // Daily Reports Toggle
          _buildToggleOption(
            title: 'Daily Reports',
            subtitle: 'Receive daily air quality reports at 5 PM',
            value: _dailyReportsEnabled,
            onChanged: _updateDailyReportSettings,
          ),

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
}
