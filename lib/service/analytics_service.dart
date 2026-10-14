
import 'dart:async';

import 'package:get/get.dart';

import '../util/log_service.dart';
import 'fake_api_service.dart';

class AnalyticsEvent {
  final String name;
  final Map<String, dynamic> properties;
  final DateTime at;

  AnalyticsEvent(this.name, this.properties)
      : at = DateTime.now();

  Map<String, dynamic> toJson() => {
    'name': name,
    'properties': properties,
    'at': at.toIso8601String(),
  };
}

/// In-memory analytics sink. Events are visible on the debug screen
/// (overflow menu on Home -> "Analytics debug") and in the console.
///
/// The "Impression tracking" feature task builds on top of this service.
class AnalyticsService extends GetxService {
  final events = <AnalyticsEvent>[].obs;

  static const int batchSize = 10;
  static const Duration batchDelay = Duration(seconds: 15);

  final Set<int> _trackedDealIds = {};
  final List<AnalyticsEvent> _pendingEvents = [];

  Timer? _batchTimer;
  bool _isSending = false;

  // Existing analytics logging.
  void logEvent( String name, [Map<String, dynamic> properties = const {},]) {
    final event = AnalyticsEvent(name, properties);

    events.add(event);
    LogService.log('analytics: $name $properties');
  }

  // F-2: Track each deal only once per session.
  void trackDealImpression({
    required int dealId,
    required String source,
    required int position,
  }) {
    if (!_trackedDealIds.add(dealId)) {
      return;
    }

    final properties = {
      'deal_id': dealId,
      'source': source,
      'position': position,
    };

    final event = AnalyticsEvent(
      'deal_impression',
      properties,
    );

    // Keep the event visible in Analytics debug.
    events.add(event);

    LogService.log(
      'analytics: deal_impression $properties',
    );

    _pendingEvents.add(event);

    if (_pendingEvents.length >= batchSize) {
      _batchTimer?.cancel();
      _batchTimer = null;
      _flushBatch();
    } else {
      _startBatchTimer();
    }
  }

  void _startBatchTimer() {
    if (_batchTimer != null || _pendingEvents.isEmpty || _isSending) {
      return;
    }

    _batchTimer = Timer(batchDelay, () {
      _batchTimer = null;
      _flushBatch();
    });
  }

  Future<void> _flushBatch() async {
    if (_isSending || _pendingEvents.isEmpty) {
      return;
    }

    _isSending = true;

    _batchTimer?.cancel();
    _batchTimer = null;

    final batch = List<AnalyticsEvent>.from(_pendingEvents);
    _pendingEvents.clear();

    try {
      final api = Get.find<FakeApiService>();

      await api.sendAnalyticsBatch(
        batch.map((event) => event.toJson()).toList(),
      );

      LogService.log(
        'analytics batch sent: ${batch.length} events',
      );
    } catch (e) {
      LogService.error('analytics batch failed', e);

      // Restore failed events for a later retry.
      _pendingEvents.insertAll(0, batch);
    } finally {
      _isSending = false;

      if (_pendingEvents.isNotEmpty) {
        // Retry later after failure, avoiding a tight loop.
        _startBatchTimer();
      }
    }
  }

  @override
  void onClose() {
    _batchTimer?.cancel();
    super.onClose();
  }
}
