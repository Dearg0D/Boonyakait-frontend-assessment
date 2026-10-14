
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../service/analytics_service.dart';

/// Tracks a deal impression after 50% visibility for 1 continuous second.
class DealImpressionTracker extends StatefulWidget {
  final int dealId;
  final String source;
  final int position;
  final Widget child;

  const DealImpressionTracker({
    super.key,
    required this.dealId,
    required this.source,
    required this.position,
    required this.child,
  });

  @override
  State<DealImpressionTracker> createState() =>
      _DealImpressionTrackerState();
}

class _DealImpressionTrackerState extends State<DealImpressionTracker> {
  Timer? _visibilityTimer;
  bool _tracked = false;
  bool _isVisible = false;

  late final AnalyticsService _analytics;

  @override
  void initState() {
    super.initState();
    _analytics = Get.find<AnalyticsService>();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (_tracked) return;

    final visible = info.visibleFraction >= 0.5;

    if (visible == _isVisible) return;

    _isVisible = visible;

    if (visible) {
      _visibilityTimer = Timer(
        const Duration(seconds: 1),
            () {
          if (!mounted || !_isVisible || _tracked) return;

          _tracked = true;

          _analytics.trackDealImpression(
            dealId: widget.dealId,
            source: widget.source,
            position: widget.position,
          );
        },
      );
    } else {
      _visibilityTimer?.cancel();
      _visibilityTimer = null;
    }
  }

  @override
  void didUpdateWidget(covariant DealImpressionTracker oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.dealId != widget.dealId ||
        oldWidget.source != widget.source ||
        oldWidget.position != widget.position) {
      _visibilityTimer?.cancel();
      _visibilityTimer = null;
      _tracked = false;
      _isVisible = false;
    }
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey(
        'impression-${widget.source}-${widget.dealId}',
      ),
      onVisibilityChanged: _onVisibilityChanged,
      child: widget.child,
    );
  }
}
