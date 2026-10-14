
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../service/flash_sale_clock_service.dart';

class ReservationCountdown extends StatelessWidget {
  final DateTime expiresAt;

  const ReservationCountdown({
    super.key,
    required this.expiresAt,
  });

  @override
  Widget build(BuildContext context) {
    final clock = Get.find<FlashSaleClockService>();

    return Obx(() {
      final remaining = expiresAt.difference(clock.now.value);

      if (remaining <= Duration.zero) {
        return const Text(
          'Reservation expired',
          style: TextStyle(color: Colors.red, fontSize: 12),
        );
      }

      final minutes = remaining.inMinutes;
      final seconds = remaining.inSeconds % 60;

      return Text(
        'Reserved ${minutes.toString().padLeft(2, '0')}:'
            '${seconds.toString().padLeft(2, '0')}',
        style: const TextStyle(
          fontSize: 12,
          color: Colors.orange,
          fontWeight: FontWeight.w600,
        ),
      );
    });
  }
}