
import 'package:intl/intl.dart';

class PickupWindowModel {
  final DateTime start;
  final DateTime end;

  const PickupWindowModel({
    required this.start,
    required this.end,
  });

  factory PickupWindowModel.fromJson(Map<String, dynamic> json) {
    return PickupWindowModel(
      start: DateTime.parse(json['start'] as String).toLocal(),
      end: DateTime.parse(json['end'] as String).toLocal(),
    );
  }

  /// Human readable label, e.g. "06:00 – 09:30".
  String get label =>
      '${DateFormat('HH:mm').format(start.toLocal())} – '
          '${DateFormat('HH:mm').format(end.toLocal())}';

  bool get isToday {
    final now = DateTime.now();
    final localStart = start.toLocal();

    return localStart.year == now.year &&
        localStart.month == now.month &&
        localStart.day == now.day;
  }

  bool get isOpenNow {
    final now = DateTime.now();
    return !now.isBefore(start) && now.isBefore(end);
  }

  Duration get untilStart => start.difference(DateTime.now());
}
