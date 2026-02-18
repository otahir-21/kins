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
    this.pillsPerRow = 6,
  });

  final List<InterestModel> interests;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;
  /// Number of chips per horizontal row (default 6; use 25 for create post).
  final int pillsPerRow;

  @override
  Widget build(BuildContext context) {
    if (interests.isEmpty) return const SizedBox.shrink();

    final rows = <List<InterestModel>>[];
    for (var i = 0; i < interests.length; i += pillsPerRow) {
      rows.add(
        interests.sublist(
          i,
          i + pillsPerRow > interests.length ? interests.length : i + pillsPerRow,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: 6),
          SizedBox(
            height: 40,
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

/// LinkedIn-style: inactive = white bg + grey border + grey text; active = solid fill + white text.
class _InterestPill extends StatelessWidget {
  const _InterestPill({
    required this.interest,
    required this.isSelected,
    required this.onTap,
  });

  final InterestModel interest;
  final bool isSelected;
  final VoidCallback onTap;

  static const double _chipRadius = 20;
  static const Color _selectedColor = Color(0xFF7a084e);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_chipRadius),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? _selectedColor : Colors.white,
            borderRadius: BorderRadius.circular(_chipRadius),
            border: Border.all(
              color: isSelected ? _selectedColor : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  interest.name,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 12),
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                isSelected ? Icons.close : Icons.add,
                size: 14,
                color: isSelected ? Colors.white : _selectedColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
