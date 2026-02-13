import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/providers/interest_provider.dart';
import 'package:kins_app/widgets/app_card.dart';
import 'package:kins_app/widgets/skeleton/skeleton_loaders.dart';
import 'package:kins_app/widgets/auth_flow_layout.dart';
import '../../models/interest_model.dart';

/// Minimum number of interests required to enable Next (0 = any, 1+ = at least that many).
const int _kMinInterestsToEnableNext = 1;

class InterestsScreen extends ConsumerStatefulWidget {
  const InterestsScreen({super.key});

  @override
  ConsumerState<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends ConsumerState<InterestsScreen> {
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(interestProvider.notifier).loadInterests(currentUserId);
    });
  }

  Future<void> _handleContinue() async {
    final uid = currentUserId;
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('User not authenticated'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final interestState = ref.read(interestProvider);
    if (interestState.selectedInterestIds.length < _kMinInterestsToEnableNext) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _kMinInterestsToEnableNext == 1
                ? 'Please select at least one interest'
                : 'Please select at least $_kMinInterestsToEnableNext interests',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await ref.read(interestProvider.notifier).saveUserInterests(uid);
      if (mounted) context.go(AppConstants.routeDiscover);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save interests: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _handleSkip() {
    context.go(AppConstants.routeDiscover);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final interestState = ref.watch(interestProvider);

    return Scaffold(
      body: AuthFlowLayout(
        children: [
          const SizedBox(height: 120),
          Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: AppCard(
                  constraints: const BoxConstraints(maxWidth: 500),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 0,
                    ),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header (fixed)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                        child: Text(
                          'Select your interests',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),

                      // Interest pills (expands to fill remaining space, scrolls inside)
                      Expanded(
                        child: interestState.isLoading
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: SkeletonInterestChips(),
                                ),
                              )
                            : interestState.error != null
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
                                          const SizedBox(height: 12),
                                          Text(
                                            interestState.error!,
                                            style: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 16),
                                          TextButton(
                                            onPressed: () => ref.read(interestProvider.notifier).loadInterests(),
                                            child: const Text('Retry'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : SingleChildScrollView(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    child: _InterestsScrollableRows(
                                      interests: interestState.interests,
                                      selectedIds: interestState.selectedInterestIds,
                                      onToggle: (id) => ref.read(interestProvider.notifier).toggleInterest(id),
                                    ),
                                  ),
                      ),

                      // Next button (fixed at bottom of card)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _NextButton(
                            enabled: interestState.selectedInterestIds.length >= _kMinInterestsToEnableNext && !_isSaving,
                            isLoading: _isSaving,
                            onPressed: _handleContinue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Target number of pills per row; each row is horizontally scrollable.
const int _kPillsPerRow = 6;

class _InterestsScrollableRows extends StatelessWidget {
  const _InterestsScrollableRows({
    required this.interests,
    required this.selectedIds,
    required this.onToggle,
  });

  final List<InterestModel> interests;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (interests.isEmpty) return const SizedBox.shrink();

    final rows = <List<InterestModel>>[];
    for (var i = 0; i < interests.length; i += _kPillsPerRow) {
      rows.add(
        interests.sublist(i, i + _kPillsPerRow > interests.length ? interests.length : i + _kPillsPerRow),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 2),
              itemCount: rows[r].length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final interest = rows[r][index];
                return _InterestPill(
                  interest: interest,
                  isSelected: selectedIds.contains(interest.id),
                  onTap: () => onToggle(interest.id),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _InterestPill extends StatelessWidget {
  const _InterestPill({
    required this.interest,
    required this.isSelected,
    required this.onTap,
  });

  final InterestModel interest;
  final bool isSelected;
  final VoidCallback onTap;

  static const double _pillRadius = 24;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_pillRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_pillRadius),
            border: Border.all(
              color: isSelected ? colorScheme.primary : Colors.grey.shade300,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                interest.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected ? Icons.close : Icons.add,
                size: 18,
                color: isSelected ? colorScheme.primary : colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Next button: icon only (→), white background, soft shadow, fully rounded, minimal iOS-style.
class _NextButton extends StatelessWidget {
  const _NextButton({
    required this.enabled,
    required this.isLoading,
    required this.onPressed,
  });

  final bool enabled;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled && !isLoading ? onPressed : null,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: enabled ? Colors.white : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: enabled ? Colors.grey.shade300 : Colors.grey.shade300,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? const SkeletonInline(size: 24)
                : Icon(
                    Icons.arrow_forward,
                    size: 24,
                    color: enabled ? colorScheme.onSurface : Colors.grey.shade500,
                  ),
          ),
        ),
      ),
    );
  }
}
