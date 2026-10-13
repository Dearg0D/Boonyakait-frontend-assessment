
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../service/flash_sale_clock_service.dart';

class FlashSaleCountdown extends StatelessWidget {
  final DateTime endsAt;
  final bool showFlashSaleLabel;
  final Color textColor;

  const FlashSaleCountdown({
    super.key,
    required this.endsAt,
    this.showFlashSaleLabel = false,
    this.textColor = Colors.red,
  });

  String _format(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final hh = hours.toString().padLeft(2, '0');
      return '$hh:$mm:$ss';
    }

    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final clock = Get.find<FlashSaleClockService>();

    return Obx(() {
      final now = clock.now.value;
      final remaining = endsAt.difference(now);
      final expired = remaining <= Duration.zero;

      return Text(
        expired
            ? 'Expired'
            : '${showFlashSaleLabel ? 'FLASH SALE ' : ''}'
            '${_format(remaining)}',
        style: TextStyle(
          color: expired ? Colors.white : textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
    });
  }
}
