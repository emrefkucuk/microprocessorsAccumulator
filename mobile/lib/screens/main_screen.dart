import 'package:flutter/material.dart';
import '../models/air_quality_data.dart';
import '../services/data_service.dart';
import '../widgets/summary_box.dart';
import '../widgets/air_quality_chart.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late final DataService _dataService;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _dataService = DataService();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _dataService.refreshData();
    } catch (e) {
      debugPrint('Error loading data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error refreshing data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Air Quality Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Air Quality Summary Box
                    StreamBuilder<AirQualityData>(
                      stream: _dataService.airQualityStream,
                      initialData: _dataService.currentAirQuality,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return SummaryBox(airQualityData: snapshot.data!);
                        } else {
                          return const SizedBox(
                            height: 100,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 24),

                    // Daily Chart
                    const Text(
                      'Daily Air Quality',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 225, // Increased height to accommodate labels
                      child: AirQualityChart(
                        data: _dataService.dailyAirQuality,
                        timeFormat: 'HH:mm',
                      ),
                    ),

                    const SizedBox(height: 24),

// Monthly Chart
                    const Text(
                      'Monthly Air Quality',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 225, // Increased height to accommodate labels
                      child: AirQualityChart(
                        data: _dataService.monthlyAirQuality,
                        timeFormat: 'MM/dd',
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Sensors Button
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/sensors');
                        },
                        icon: const Icon(Icons.sensors),
                        label: const Text('Sensors'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
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
