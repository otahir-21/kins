import 'package:flutter/material.dart';
import 'package:kins_app/core/responsive/responsive.dart';
import 'package:kins_app/models/interest_model.dart';

/// Scrollable horizontal rows of interest pills (same layout as interests screen).
/// Use in interests screen and create post screen.
class InterestChipsScrollable extends StatelessWidget {
  const InterestChipsScrollable({
    super.key,
    required this.interests,
    required this.selectedIds,
    required this.onToggle,
  });

  final List<InterestModel> interests;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  static const int _kPillsPerRow = 6;

  @override
  Widget build(BuildContext context) {
    if (interests.isEmpty) return const SizedBox.shrink();

    final rows = <List<InterestModel>>[];
    for (var i = 0; i < interests.length; i += _kPillsPerRow) {
      rows.add(
        interests.sublist(
          i,
          i + _kPillsPerRow > interests.length ? interests.length : i + _kPillsPerRow,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: 12),
          SizedBox(
            height: 32,
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

  static const double _pillRadius = 14;

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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_pillRadius),
            border: Border.all(
              color: isSelected ? colorScheme.primary : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                interest.name,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: Responsive.fontSize(context, 12),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isSelected ? Icons.close : Icons.add,
                size: 12,
                color: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
