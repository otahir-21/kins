import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/responsive/responsive.dart';
import 'package:kins_app/providers/auth_provider.dart';
import 'package:kins_app/widgets/confirm_dialog.dart';
import 'package:kins_app/widgets/kins_logo.dart';

/// Standard app drawer used on Discover, Chats, and other main screens.
/// Provides logo, Saved Posts, Account Settings, links, and Log out.
class AppDrawer extends ConsumerWidget {
  /// Called after returning from Account Settings (e.g. to refresh profile/interests).
  final VoidCallback? onAfterSettings;

  const AppDrawer({super.key, this.onAfterSettings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authRepository = ref.read(authRepositoryProvider);
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  KinsLogo(
                    width: Responsive.scale(context, 96),
                    height: Responsive.scale(context, 70),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _DrawerItem(title: 'Saved Posts', icon: Icons.bookmark_border, onTap: () => Navigator.pop(context)),
                    _DrawerItem(
                      title: 'Account Settings',
                      icon: Icons.person_outline,
                      onTap: () async {
                        Navigator.pop(context);
                        await context.push(AppConstants.routeSettings);
                        if (context.mounted && onAfterSettings != null) onAfterSettings!();
                      },
                    ),
                    _DrawerItem(title: 'Request Verification', icon: Icons.verified_outlined, onTap: () => Navigator.pop(context)),
                    _DrawerItem(title: 'Terms of Service', icon: Icons.description_outlined, onTap: () => Navigator.pop(context)),
                    _DrawerItem(title: 'Community Guidelines', icon: Icons.rule_outlined, onTap: () => Navigator.pop(context)),
                    _DrawerItem(title: 'Privacy Policy', icon: Icons.privacy_tip_outlined, onTap: () => Navigator.pop(context)),
                    _DrawerItem(title: 'About Us', icon: Icons.info_outline, onTap: () => Navigator.pop(context)),
                    _DrawerItem(title: 'Contact Us', icon: Icons.contact_support_outlined, onTap: () => Navigator.pop(context)),
                    const Divider(height: 1),
                    _DrawerItem(
                      title: 'Log out',
                      icon: Icons.exit_to_app,
                      isLogout: true,
                      onTap: () async {
                        final shouldLogout = await showConfirmDialog<bool>(
                          context: context,
                          title: 'Log out',
                          message: 'Are you sure you want to log out?',
                          confirmLabel: 'Log out',
                          destructive: true,
                          icon: Icons.logout,
                        );
                        if (shouldLogout == true && context.mounted) {
                          Navigator.pop(context);
                          try {
                            await authRepository.signOut();
                            if (context.mounted) context.go(AppConstants.routeSplash);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to logout: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isLogout;

  const _DrawerItem({
    required this.title,
    required this.icon,
    required this.onTap,
    this.isLogout = false,
  });

  @override
  Widget build(BuildContext context) {
    final useRed = isLogout;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          dense: true,
          leading: Icon(icon, color: useRed ? Colors.red : Colors.black87, size: 24),
          title: Text(
            title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: Responsive.fontSize(context, 14),
              color: useRed ? Colors.red : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: useRed ? Colors.red : Colors.grey,
          ),
          onTap: onTap,
          contentPadding: EdgeInsets.symmetric(
            horizontal: Responsive.screenPaddingH(context),
            vertical: 0,
          ),
        ),
      ],
    );
  }
}
