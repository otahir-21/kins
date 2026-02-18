import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/responsive/responsive.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:kins_app/providers/auth_provider.dart';
import 'package:kins_app/services/account_deletion_service.dart';
import 'package:kins_app/widgets/confirm_dialog.dart';

/// Settings menu: Account Settings, Favourite, FAQ's, Terms, Privacy, About us, Log out.
class SettingsMenuScreen extends ConsumerWidget {
  const SettingsMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black, size: Responsive.fontSize(context, 24)),
          onPressed: () => context.pop(),
        ),
        title: Text('Settings', style: TextStyle(color: Colors.black, fontSize: Responsive.fontSize(context, 18))),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.screenPaddingH(context),
          vertical: Responsive.spacing(context, 8),
        ),
        children: [
          _buildItem(context, 'Edit Profile', Icons.edit_outlined, () => context.push(AppConstants.routeEditProfile)),
          _buildItem(context, 'Favourite', Icons.favorite_border, () => _showComingSoon(context)),
          _buildItem(context, 'FAQ\'s', Icons.help_outline, () => _showComingSoon(context)),
          _buildItem(context, 'Terms of Service', Icons.description_outlined, () => _showComingSoon(context)),
          _buildItem(context, 'Privacy Policy', Icons.privacy_tip_outlined, () => _showComingSoon(context)),
          _buildItem(context, 'About us', Icons.info_outline, () => _showComingSoon(context)),
          Divider(height: Responsive.spacing(context, 24)),
          _buildItem(context, 'Delete account', Icons.delete_outline, () => _onDeleteAccount(context, ref), isDestructive: true),
          _buildItem(context, 'Log out', Icons.exit_to_app, () => _onLogout(context, ref), isLogout: true),
          SizedBox(height: Responsive.spacing(context, 24)),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, String title, IconData icon, VoidCallback onTap, {bool isLogout = false, bool isDestructive = false}) {
    final color = (isLogout || isDestructive) ? Colors.red : Colors.black87;
    return ListTile(
      leading: Icon(icon, color: color, size: Responsive.fontSize(context, 22)),
      title: Text(title, style: TextStyle(fontSize: Responsive.fontSize(context, 14), fontWeight: FontWeight.w500, color: color)),
      trailing: (isLogout || isDestructive) ? null : Icon(Icons.chevron_right, color: Colors.grey.shade400, size: Responsive.fontSize(context, 22)),
      onTap: onTap,
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon')));
  }

  void _onDeleteAccount(BuildContext context, WidgetRef ref) async {
    final confirm = await showConfirmDialog<bool>(
      context: context,
      title: 'Delete account',
      message: 'This will permanently delete your account and all your data from our servers. This action cannot be undone.\n\nAre you sure you want to continue?',
      confirmLabel: 'Delete account',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (confirm != true || !context.mounted) return;
    try {
      final service = AccountDeletionService();
      await service.deleteAccount(
        userId: currentUserId,
        authRepository: ref.read(authRepositoryProvider),
      );
      if (context.mounted) context.go(AppConstants.routeSplash);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showConfirmDialog<bool>(
      context: context,
      title: 'Log out',
      message: 'Are you sure you want to log out?',
      confirmLabel: 'Log out',
      destructive: true,
      icon: Icons.logout,
    );
    if (confirm != true) return;
    try {
      await ref.read(authRepositoryProvider).signOut();
      if (context.mounted) context.go(AppConstants.routeSplash);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
