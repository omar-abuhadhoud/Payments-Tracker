import 'package:flutter/material.dart';

import '../global_variables/app_colors.dart';

class SwipePeriodNavigation extends StatelessWidget {
  final Widget child;
  final String label;
  final bool isLoading;
  final bool canGoOlder;
  final bool canGoNewer;
  final bool isCurrent;
  final VoidCallback? onGoOlder;
  final VoidCallback? onGoNewer;
  final VoidCallback? onGoCurrent;
  final VoidCallback? onPickPeriod;
  final String currentTooltip;

  const SwipePeriodNavigation({
    super.key,
    required this.child,
    required this.label,
    required this.isLoading,
    required this.canGoOlder,
    required this.canGoNewer,
    required this.isCurrent,
    this.onGoOlder,
    this.onGoNewer,
    this.onGoCurrent,
    this.onPickPeriod,
    this.currentTooltip = 'Current',
  });

  void _handleHorizontalSwipe(DragEndDetails details) {
    if (isLoading) return;

    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 280) return;

    if (velocity < 0 && canGoOlder) {
      onGoOlder?.call();
    } else if (velocity > 0 && canGoNewer) {
      onGoNewer?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: _handleHorizontalSwipe,
          child: child,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _PeriodBottomControls(
            label: label,
            isLoading: isLoading,
            canGoOlder: canGoOlder,
            canGoNewer: canGoNewer,
            isCurrent: isCurrent,
            onGoCurrent: onGoCurrent,
            onPickPeriod: onPickPeriod,
            currentTooltip: currentTooltip,
          ),
        ),
      ],
    );
  }
}

class _PeriodBottomControls extends StatelessWidget {
  final String label;
  final bool isLoading;
  final bool canGoOlder;
  final bool canGoNewer;
  final bool isCurrent;
  final VoidCallback? onGoCurrent;
  final VoidCallback? onPickPeriod;
  final String currentTooltip;

  const _PeriodBottomControls({
    required this.label,
    required this.isLoading,
    required this.canGoOlder,
    required this.canGoNewer,
    required this.isCurrent,
    required this.onGoCurrent,
    required this.onPickPeriod,
    required this.currentTooltip,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Material(
          color: Colors.white,
          elevation: 10,
          shadowColor: AppColors.purple.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.purple.withValues(alpha: .10),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.chevron_left,
                  color: canGoNewer && !isLoading
                      ? AppColors.purple.withValues(alpha: .42)
                      : AppColors.purple.withValues(alpha: .14),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: isLoading ? null : onPickPeriod,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.purple,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: canGoOlder && !isLoading
                      ? AppColors.purple.withValues(alpha: .42)
                      : AppColors.purple.withValues(alpha: .14),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: currentTooltip,
                  child: IconButton.filledTonal(
                    onPressed: isLoading || isCurrent ? null : onGoCurrent,
                    icon: const Icon(Icons.today_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
