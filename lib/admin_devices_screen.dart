import 'package:flutter/material.dart';
import 'data/db_helper.dart';
import 'data/initial_sync_service.dart';

class AdminDevicesScreen extends StatefulWidget {
  const AdminDevicesScreen({super.key});

  @override
  State<AdminDevicesScreen> createState() => _AdminDevicesScreenState();
}

class _AdminDevicesScreenState extends State<AdminDevicesScreen> {
  List<Map<String, dynamic>> devices = [];
  bool loading = true;
  static const Color navyBlue = Color(0xFF0A1D37);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // 1. Load Local Data Instantly
    await _loadDevices(isInitial: true);
    // 2. Fetch from Cloud Silently
    _refreshFromCloud();
  }

  Future<void> _refreshFromCloud() async {
    await InitialSyncService.fetchDevices("token_placeholder");
    if (!mounted) return;
    _loadDevices(); // Refresh with new data
  }

  Future<void> _loadDevices({bool isInitial = false}) async {
    final db = await DBHelper.db;
    final results = await db.query('devices', orderBy: 'last_seen DESC');
    if (mounted) {
      setState(() {
        devices = results;
        if (isInitial) loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: navyBlue,
        elevation: 0,
        title: const Text(
          'Tracked Devices',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _refreshFromCloud(),
            tooltip: 'Refresh from Cloud',
          ),
        ],
      ),
      body: loading && devices.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : devices.isEmpty
              ? const Center(child: Text("No devices tracked yet"))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final d = devices[index];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: navyBlue,
                          child: Icon(Icons.important_devices, color: Colors.white),
                        ),
                        title: Text(
                          d['device_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("IP: ${d['ip_address']}"),
                            Text("User: ${d['email']}", style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: Text(
                          d['last_seen'].toString().split('.').first,
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
