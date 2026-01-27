import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/initial_sync_service.dart';
import 'home_screen.dart';
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _isLoadingRecords = false;
  bool _isLoadingUsers = false;
  bool _recordsSynced = false;
  bool _usersSynced = false;
  String _statusMessage = '';

  Future<void> _syncRecords() async {
    setState(() {
      _isLoadingRecords = true;
      _statusMessage = 'Syncing Records...';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? ''; // Assuming token is stored
      await InitialSyncService.syncRecords(token);
      setState(() {
        _recordsSynced = true;
        _statusMessage = 'Records Synced Successfully';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error Syncing Records: $e';
      });
    } finally {
      setState(() {
        _isLoadingRecords = false;
        _checkCompletion();
      });
    }
  }

  Future<void> _syncUsers() async {
    setState(() {
      _isLoadingUsers = true;
      _statusMessage = 'Syncing Users...';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      await InitialSyncService.syncUsers(token);
      setState(() {
        _usersSynced = true;
        _statusMessage = 'Users Synced Successfully';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error Syncing Users: $e';
      });
    } finally {
      setState(() {
        _isLoadingUsers = false;
        _checkCompletion();
      });
    }
  }

  void _checkCompletion() {
    if (_recordsSynced && _usersSynced) {
      _navigateToHome();
    }
  }

  void _navigateToHome() async {
     final prefs = await SharedPreferences.getInstance();
     await prefs.setBool('is_synced', true);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Initial Sync', style: TextStyle(color:Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0A1D37),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Sync Data",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A1D37),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isLoadingRecords || _recordsSynced ? null : _syncRecords,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A1D37),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoadingRecords
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      _recordsSynced ? "Records Synced ✓" : "All Record",
                      style: TextStyle(
                        fontSize: 18,
                        color: _recordsSynced ? Colors.green : Colors.white,
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoadingUsers || _usersSynced ? null : _syncUsers,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A1D37),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoadingUsers
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      _usersSynced ? "Users Synced ✓" : "All Users",
                      style: TextStyle(
                        fontSize: 18,
                        color: _usersSynced ? Colors.green : Colors.white,
                      ),
                    ),
            ),
            const SizedBox(height: 30),
            if (_statusMessage.isNotEmpty)
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }
}
