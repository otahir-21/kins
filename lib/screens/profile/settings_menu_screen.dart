import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/repositories/auth_repository.dart';

/// Settings menu: Account Settings, Favourite, FAQ's, Terms, Privacy, About us, Log out.
class SettingsMenuScreen extends StatelessWidget {
  const SettingsMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text('Settings', style: TextStyle(color: Colors.black)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          _buildItem(context, 'Account Settings', Icons.person_outline, () => context.push(AppConstants.routeAccountSettings)),
          _buildItem(context, 'Edit tags', Icons.label_outline, () => context.push(AppConstants.routeEditTags)),
          _buildItem(context, 'Favourite', Icons.favorite_border, () => _showComingSoon(context)),
          _buildItem(context, 'FAQ\'s', Icons.help_outline, () => _showComingSoon(context)),
          _buildItem(context, 'Terms of Service', Icons.description_outlined, () => _showComingSoon(context)),
          _buildItem(context, 'Privacy Policy', Icons.privacy_tip_outlined, () => _showComingSoon(context)),
          _buildItem(context, 'About us', Icons.info_outline, () => _showComingSoon(context)),
          const Divider(height: 24),
          _buildItem(context, 'Log out', Icons.logout, () => _onLogout(context), isLogout: true),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, String title, IconData icon, VoidCallback onTap, {bool isLogout = false}) {
    final color = isLogout ? Colors.red : Colors.black87;
    return ListTile(
      leading: Icon(icon, color: color, size: 24),
      title: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: color)),
      trailing: isLogout ? null : Icon(Icons.chevron_right, color: Colors.grey.shade400),
      onTap: onTap,
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon')));
  }

  void _onLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Log out')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await AuthRepository().signOut();
      if (context.mounted) context.go(AppConstants.routeSplash);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
