import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kins_app/repositories/location_repository.dart';

/// Account settings: location visibility toggle (and more later).
class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  bool _isLocationVisible = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocationVisibility();
  }

  Future<void> _loadLocationVisibility() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final repository = LocationRepository();
      final isVisible = await repository.getUserLocationVisibility(user.uid);
      if (mounted) setState(() { _isLocationVisible = isVisible; _isLoading = false; });
    } else if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _toggleLocationVisibility(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isLocationVisible = value);
    try {
      await LocationRepository().updateLocationVisibility(userId: user.uid, isVisible: value);
    } catch (e) {
      setState(() => _isLocationVisible = !value);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Account Settings', style: TextStyle(color: Colors.black)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on, color: Color(0xFF6B4C93)),
                    title: const Text('Show my location to other kins'),
                    subtitle: Text(
                      _isLocationVisible ? 'Other users can see you on the map' : 'You are hidden from other users',
                    ),
                    trailing: Switch(
                      value: _isLocationVisible,
                      onChanged: _toggleLocationVisibility,
                      activeColor: const Color(0xFF6B4C93),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
