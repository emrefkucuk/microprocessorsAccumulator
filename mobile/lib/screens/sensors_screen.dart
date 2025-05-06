import 'package:flutter/material.dart';
import '../models/sensor_data.dart';
import '../services/data_service.dart';
import '../widgets/sensor_card.dart';

class SensorsScreen extends StatefulWidget {
  const SensorsScreen({Key? key}) : super(key: key);

  @override
  State<SensorsScreen> createState() => _SensorsScreenState();
}

class _SensorsScreenState extends State<SensorsScreen> {
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

    await _dataService.refreshData();

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensors'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: StreamBuilder<List<SensorData>>(
                stream: _dataService.sensorsStream,
                initialData: _dataService.sensorReadings,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('No sensor data available'),
                    );
                  }

                  final sensors = snapshot.data!;

                  return ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: sensors.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: SensorCard(sensorData: sensors[index]),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }
}
