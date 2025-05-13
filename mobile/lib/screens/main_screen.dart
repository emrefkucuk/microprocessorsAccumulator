import 'package:flutter/material.dart';
import '../models/air_quality_data.dart';
import '../services/data_service.dart';
import '../widgets/summary_box.dart';
import '../widgets/air_quality_chart.dart';
import '../widgets/ai_prediction_box.dart';

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
      // Explicitly request historical data refresh
      await _dataService.refreshData(includeHistorical: true);

      // Log data status after refresh
      debugPrint(
          'Data refreshed - Daily data: ${_dataService.dailyAirQuality.length} items');
      debugPrint(
          'Data refreshed - Monthly data: ${_dataService.monthlyAirQuality.length} items');

      // Verify stream controllers have data
      _dataService.dailyAirQualityStream.first.then((data) {
        debugPrint('Daily stream data count: ${data.length}');
      }).catchError((e) {
        debugPrint('Error getting daily stream data: $e');
      });

      _dataService.monthlyAirQualityStream.first.then((data) {
        debugPrint('Monthly stream data count: ${data.length}');
      }).catchError((e) {
        debugPrint('Error getting monthly stream data: $e');
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                        if (snapshot.hasData && snapshot.data != null) {
                          return SummaryBox(airQualityData: snapshot.data!);
                        } else {
                          return Container(
                            height: 150, // Increased height
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: const Center(
                              child: Text(
                                'Loading air quality data...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 20), // More space

                    // AI Prediction Box
                    StreamBuilder<AirQualityData>(
                      stream: _dataService.airQualityStream,
                      initialData: _dataService.currentAirQuality,
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          return AIPredictionBox(
                              airQualityData: snapshot.data!);
                        } else {
                          return Container(
                            height: 150, // Increased height further
                            margin: const EdgeInsets.only(top: 12.0),
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: const Center(
                              child: Text(
                                'Loading AI prediction...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 32), // More space

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
                      height: 225, // Height for chart
                      child: StreamBuilder<List<AirQualityData>>(
                        stream: _dataService.dailyAirQualityStream,
                        initialData: _dataService.dailyAirQuality,
                        builder: (context, snapshot) {
                          // Debug information
                          debugPrint(
                              'Daily data snapshot: hasData=${snapshot.hasData}, isEmpty=${snapshot.data?.isEmpty}');
                          if (snapshot.data != null) {
                            debugPrint(
                                'Daily data count: ${snapshot.data!.length}');
                          }

                          if (snapshot.hasData &&
                              snapshot.data != null &&
                              snapshot.data!.isNotEmpty) {
                            return AirQualityChart(
                              data: snapshot.data!,
                              timeFormat: 'HH:mm',
                            );
                          } else {
                            // Check for initialization - force a data refresh if empty
                            if (_dataService.dailyAirQuality.isEmpty) {
                              debugPrint(
                                  'Daily air quality is empty, force refreshing...');
                              Future.microtask(() => _loadData());
                            }

                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.grey,
                                    size: 36,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Getting daily data...',
                                    style: TextStyle(color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 32), // More space

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
                      height: 225, // Height for chart
                      child: StreamBuilder<List<AirQualityData>>(
                        stream: _dataService.monthlyAirQualityStream,
                        initialData: _dataService.monthlyAirQuality,
                        builder: (context, snapshot) {
                          // Debug information
                          debugPrint(
                              'Monthly data snapshot: hasData=${snapshot.hasData}, isEmpty=${snapshot.data?.isEmpty}');
                          if (snapshot.data != null) {
                            debugPrint(
                                'Monthly data count: ${snapshot.data!.length}');
                          }

                          if (snapshot.hasData &&
                              snapshot.data != null &&
                              snapshot.data!.isNotEmpty) {
                            return AirQualityChart(
                              data: snapshot.data!,
                              timeFormat: 'dd/MM',
                            );
                          } else {
                            // Check for initialization - force a data refresh if empty
                            if (_dataService.monthlyAirQuality.isEmpty) {
                              debugPrint(
                                  'Monthly air quality is empty, force refreshing...');
                              Future.microtask(() => _loadData());
                            }

                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.grey,
                                    size: 36,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Getting monthly data...',
                                    style: TextStyle(color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 32), // More space

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

                    const SizedBox(height: 24), // Add extra space at the bottom
                  ],
                ),
              ),
            ),
    );
  }
}
