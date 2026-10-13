import 'dart:async';

import 'package:get/get.dart';

class FlashSaleClockService extends GetxService {
  final now = DateTime.now().obs;

  Timer? _timer;

  @override
  void onInit() {
    super.onInit();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (_) => now.value = DateTime.now(),
    );
  }

  bool isExpired(DateTime? endsAt) {
    if (endsAt == null) return false;
    return !DateTime.now().isBefore(endsAt);
  }

  Duration remaining(DateTime endsAt) {
    final duration = endsAt.difference(DateTime.now());

    return duration.isNegative ? Duration.zero : duration;
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
