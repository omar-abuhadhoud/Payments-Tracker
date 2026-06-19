import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../global_variables/app_colors.dart';

enum ExpandableDrawerDirection { up, down }

class Utility {
  static String customNumberFormat(double number) {
    String f = '#,##0.00';
    return NumberFormat(f).format(number);
  }

  /// Places [hideable] above [scrollable], hiding it after a deliberate
  /// downward scroll and revealing it when scrolling up or reaching the top.
  static Widget hideOnScroll({
    required Widget hideable,
    required Widget scrollable,
    bool floating = false,
    bool hideEnabled = true,
    Object? visibilityResetKey,
    double hideThreshold = 48,
    double showThreshold = 32,
    double topTolerance = 8,
    Duration showDuration = const Duration(milliseconds: 420),
    Duration hideDuration = const Duration(milliseconds: 360),
  }) {
    return _HideOnScrollRegion(
      hideable: hideable,
      scrollable: scrollable,
      floating: floating,
      hideEnabled: hideEnabled,
      visibilityResetKey: visibilityResetKey,
      hideThreshold: hideThreshold,
      showThreshold: showThreshold,
      topTolerance: topTolerance,
      showDuration: showDuration,
      hideDuration: hideDuration,
    );
  }

  /// A floating, expandable drawer that can reveal any [content].
  ///
  /// Place it above the screen's main content, typically inside a [Stack].
  static Widget expandableFloatingDrawer({
    required String title,
    required Widget content,
    required bool isOpen,
    required VoidCallback onToggle,
    ExpandableDrawerDirection direction = ExpandableDrawerDirection.up,
    bool showShadow = true,
    double maxContentHeightFactor = .42,
    EdgeInsetsGeometry margin = const EdgeInsets.fromLTRB(16, 0, 16, 10),
  }) {
    return _ExpandableFloatingDrawer(
      title: title,
      content: content,
      isOpen: isOpen,
      onToggle: onToggle,
      direction: direction,
      showShadow: showShadow,
      maxContentHeightFactor: maxContentHeightFactor,
      margin: margin,
    );
  }

  static Widget handleNumberAppearanceForOverflow({
    required double number,
    required Color color,
    required double fontSize,
    String preText = '',
    TextAlign textAlign = TextAlign.left,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    return Tooltip(
      preferBelow: false,
      message: customNumberFormat(number),
      child: Text(
        "$preText ${customNumberFormat(number)}",
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        ),
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        maxLines: 1,
        textAlign: textAlign,
      ),
    );
  }
}

class _ExpandableFloatingDrawer extends StatelessWidget {
  const _ExpandableFloatingDrawer({
    required this.title,
    required this.content,
    required this.isOpen,
    required this.onToggle,
    required this.direction,
    required this.showShadow,
    required this.maxContentHeightFactor,
    required this.margin,
  });

  final String title;
  final Widget content;
  final bool isOpen;
  final VoidCallback onToggle;
  final ExpandableDrawerDirection direction;
  final bool showShadow;
  final double maxContentHeightFactor;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final maxContentHeight =
        MediaQuery.sizeOf(context).height * maxContentHeightFactor;

    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: direction == ExpandableDrawerDirection.up
          ? Alignment.bottomCenter
          : Alignment.topCenter,
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.purple.withValues(alpha: .14)),
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: AppColors.purple.withValues(alpha: .16),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: isOpen
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHandle(),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxContentHeight),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: content,
                    ),
                  ),
                ],
              )
            : _buildHandle(),
      ),
    );
  }

  Widget _buildHandle() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                direction == ExpandableDrawerDirection.up
                    ? (isOpen
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up)
                    : (isOpen
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down),
                color: AppColors.purple,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.purple,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HideOnScrollRegion extends StatefulWidget {
  const _HideOnScrollRegion({
    required this.hideable,
    required this.scrollable,
    required this.floating,
    required this.hideEnabled,
    required this.visibilityResetKey,
    required this.hideThreshold,
    required this.showThreshold,
    required this.topTolerance,
    required this.showDuration,
    required this.hideDuration,
  });

  final Widget hideable;
  final Widget scrollable;
  final bool floating;
  final bool hideEnabled;
  final Object? visibilityResetKey;
  final double hideThreshold;
  final double showThreshold;
  final double topTolerance;
  final Duration showDuration;
  final Duration hideDuration;

  @override
  State<_HideOnScrollRegion> createState() => _HideOnScrollRegionState();
}

class _HideOnScrollRegionState extends State<_HideOnScrollRegion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _sizeAnimation;
  late final Animation<double> _opacityAnimation;

  bool _isVisible = true;
  double _downwardScrollDistance = 0;
  double _upwardScrollDistance = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      value: 1,
      duration: widget.showDuration,
      reverseDuration: widget.hideDuration,
    );
    _sizeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    _opacityAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.15, 1, curve: Curves.easeOut),
      reverseCurve: const Interval(0, 0.75, curve: Curves.easeIn),
    );
  }

  @override
  void didUpdateWidget(covariant _HideOnScrollRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visibilityResetKey != oldWidget.visibilityResetKey ||
        (!widget.hideEnabled && oldWidget.hideEnabled)) {
      _downwardScrollDistance = 0;
      _upwardScrollDistance = 0;
      _setVisible(true);
    }
    if (oldWidget.showDuration != widget.showDuration) {
      _animationController.duration = widget.showDuration;
    }
    if (oldWidget.hideDuration != widget.hideDuration) {
      _animationController.reverseDuration = widget.hideDuration;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setVisible(bool visible) {
    if (_isVisible == visible) return;

    _isVisible = visible;
    if (visible) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (!widget.hideEnabled) {
      _setVisible(true);
      return false;
    }

    final isAtTop =
        notification.metrics.pixels <=
        notification.metrics.minScrollExtent + widget.topTolerance;

    if (isAtTop) {
      _downwardScrollDistance = 0;
      _upwardScrollDistance = 0;
      _setVisible(true);
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;

      if (delta > 0) {
        _downwardScrollDistance += delta;
        _upwardScrollDistance = 0;
        if (_isVisible && _downwardScrollDistance >= widget.hideThreshold) {
          _downwardScrollDistance = 0;
          _setVisible(false);
        }
      } else if (delta < 0) {
        // A fast fling can rebound when it reaches the bottom of the list.
        // That correction also has a negative delta, but it is not an upward
        // gesture from the user and should not reveal the header.
        if (notification.dragDetails == null) return false;

        _upwardScrollDistance += -delta;
        _downwardScrollDistance = 0;
        if (!_isVisible && _upwardScrollDistance >= widget.showThreshold) {
          _upwardScrollDistance = 0;
          _setVisible(true);
        }
      }
    } else if (notification is ScrollEndNotification) {
      _downwardScrollDistance = 0;
      _upwardScrollDistance = 0;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final animatedHideable = ClipRect(
      child: SizeTransition(
        sizeFactor: _sizeAnimation,
        axisAlignment: -1,
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: widget.hideable,
        ),
      ),
    );

    final listenedScrollable = NotificationListener<ScrollNotification>(
      onNotification: _handleScroll,
      child: widget.scrollable,
    );

    if (widget.floating) {
      return Stack(
        fit: StackFit.expand,
        children: [
          listenedScrollable,
          Positioned(top: 0, left: 0, right: 0, child: animatedHideable),
        ],
      );
    }

    return Column(
      children: [
        animatedHideable,
        Expanded(child: listenedScrollable),
      ],
    );
  }
}
