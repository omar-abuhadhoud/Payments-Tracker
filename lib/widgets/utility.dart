import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    double hideThreshold = 48,
    double showThreshold = 32,
    double topTolerance = 8,
    Duration showDuration = const Duration(milliseconds: 420),
    Duration hideDuration = const Duration(milliseconds: 360),
  }) {
    return _HideOnScrollRegion(
      hideable: hideable,
      scrollable: scrollable,
      hideThreshold: hideThreshold,
      showThreshold: showThreshold,
      topTolerance: topTolerance,
      showDuration: showDuration,
      hideDuration: hideDuration,
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

class _HideOnScrollRegion extends StatefulWidget {
  const _HideOnScrollRegion({
    required this.hideable,
    required this.scrollable,
    required this.hideThreshold,
    required this.showThreshold,
    required this.topTolerance,
    required this.showDuration,
    required this.hideDuration,
  });

  final Widget hideable;
  final Widget scrollable;
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
    return Column(
      children: [
        ClipRect(
          child: SizeTransition(
            sizeFactor: _sizeAnimation,
            axisAlignment: -1,
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: widget.hideable,
            ),
          ),
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScroll,
            child: widget.scrollable,
          ),
        ),
      ],
    );
  }
}
