import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kins_app/core/responsive/responsive.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:kins_app/repositories/location_repository.dart';
import 'package:kins_app/widgets/skeleton/skeleton_loaders.dart';

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
    final uid = currentUserId;
    if (uid.isNotEmpty) {
      final repository = LocationRepository();
      final isVisible = await repository.getUserLocationVisibility(uid);
      if (mounted) setState(() { _isLocationVisible = isVisible; _isLoading = false; });
    } else if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _toggleLocationVisibility(bool value) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;
    setState(() => _isLocationVisible = value);
    try {
      await LocationRepository().updateLocationVisibility(userId: uid, isVisible: value);
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
          icon: Icon(Icons.arrow_back, color: Colors.black, size: Responsive.fontSize(context, 24)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Account Settings', style: TextStyle(color: Colors.black, fontSize: Responsive.fontSize(context, 18))),
      ),
      body: _isLoading
          ? const SkeletonSettings()
          : ListView(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.screenPaddingH(context),
                vertical: Responsive.spacing(context, 16),
              ),
              children: [
                Card(
                  child: ListTile(
                    leading: Icon(Icons.location_on, color: const Color(0xFF6B4C93), size: Responsive.fontSize(context, 24)),
                    title: Text('Show my location to other kins', style: TextStyle(fontSize: Responsive.fontSize(context, 16))),
                    subtitle: Text(
                      _isLocationVisible ? 'Other users can see you on the map' : 'You are hidden from other users',
                      style: TextStyle(fontSize: Responsive.fontSize(context, 14)),
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
