import 'package:get/get.dart';

import '../model/cart_item_model.dart';
import '../model/deal_model.dart';
import '../util/log_service.dart';
import 'flash_sale_clock_service.dart';

/// App-wide cart. Lives for the whole session.
///
/// NOTE: the starter cart is purely local — it does not reserve stock on the
/// backend. See the "Reservations" feature task in PROBLEM.md.
class CartService extends GetxService {
  final items = <CartItemModel>[].obs;
  final itemCount = 0.obs;

  Worker? _expiryWorker;

  @override
  void onInit() {
    super.onInit();

    final clock = Get.find<FlashSaleClockService>();

    _expiryWorker = ever<DateTime>(
      clock.now,
          (_) => _removeExpiredDeals(),
    );

    _removeExpiredDeals();
  }

  bool isDealExpired(DealModel deal) {
    final endsAt = deal.flashSaleEndsAt;

    if (endsAt == null) return false;

    return !DateTime.now().isBefore(endsAt);
  }

  void add(DealModel deal) {
    // Do not allow expired flash-sale deals.
    if (isDealExpired(deal)) {
      Get.snackbar(
        'Flash sale expired',
        '${deal.name} is no longer available.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final existing = items.firstWhereOrNull(
          (i) => i.deal.id == deal.id,
    );

    if (existing != null) {
      if (existing.quantity >= deal.quantityLeft) {
        LogService.log(
          'cart: cannot add more of deal ${deal.id}',
        );
        return;
      }

      existing.quantity++;
      items.refresh();
    } else {
      items.add(CartItemModel(deal: deal));
    }

    _recount();
  }

  void _removeExpiredDeals() {
    if (items.isEmpty) return;

    final now = DateTime.now();

    final expiredItems = items.where((item) {
      final endsAt = item.deal.flashSaleEndsAt;

      return endsAt != null && !now.isBefore(endsAt);
    }).toList();

    if (expiredItems.isEmpty) return;

    final expiredIds = expiredItems
        .map((item) => item.deal.id)
        .toSet();

    items.removeWhere(
          (item) => expiredIds.contains(item.deal.id),
    );

    _recount();

    final message = expiredItems.length == 1
        ? '${expiredItems.first.deal.name} was removed from your bag.'
        : '${expiredItems.length} expired deals were removed from your bag.';

    Get.snackbar(
      'Flash sale expired',
      message,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
    );
  }

  void decrement(int dealId) {
    final existing = items.firstWhereOrNull(
          (i) => i.deal.id == dealId,
    );

    if (existing == null) return;

    existing.quantity--;

    if (existing.quantity <= 0) {
      items.removeWhere((i) => i.deal.id == dealId);
    } else {
      items.refresh();
    }

    _recount();
  }

  void remove(int dealId) {
    items.removeWhere((i) => i.deal.id == dealId);
    _recount();
  }

  void clear() {
    items.clear();
    _recount();
  }

  num get total =>
      items.fold(0, (sum, i) => sum + i.lineTotal);

  void _recount() {
    itemCount.value = items.fold(
      0,
          (sum, i) => sum + i.quantity,
    );
  }

  @override
  void onClose() {
    _expiryWorker?.dispose();
    super.onClose();
  }
}
