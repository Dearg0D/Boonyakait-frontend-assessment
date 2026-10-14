
import 'dart:async';

import 'package:get/get.dart';

import '../model/cart_item_model.dart';
import '../model/deal_model.dart';
import '../repository/order_repo.dart';
import '../util/log_service.dart';
import 'flash_sale_clock_service.dart';

/// App-wide cart. Lives for the whole session.
///
/// NOTE: the starter cart is purely local — it does not reserve stock on the
/// backend. See the "Reservations" feature task in PROBLEM.md.
class CartService extends GetxService {
  final items = <CartItemModel>[].obs;
  final itemCount = 0.obs;

  final Set<int> _reservingDealIds = {};
  final isCheckingOut = false.obs;

  Worker? _expiryWorker;

  OrderRepo get _repo => Get.find<OrderRepo>();

  bool isReserving(int dealId) =>
      _reservingDealIds.contains(dealId);

  bool isDealExpired(DealModel deal) {
    final endsAt = deal.flashSaleEndsAt;
    return endsAt != null &&
        !DateTime.now().isBefore(endsAt);
  }

  bool isReservationExpired(CartItemModel item) {
    final reservation = item.reservation;
    return reservation != null &&
        !DateTime.now().isBefore(reservation.expiresAt);
  }

  bool get canCheckout {
    if (isCheckingOut.value ||
        items.isEmpty ||
        _reservingDealIds.isNotEmpty) {
      return false;
    }

    return items.every(
          (item) =>
      item.reservation != null &&
          !isReservationExpired(item) &&
          !isDealExpired(item.deal),
    );
  }

  @override
  void onInit() {
    super.onInit();

    final clock = Get.find<FlashSaleClockService>();

    _expiryWorker = ever<DateTime>(
      clock.now,
          (_) => removeExpiredItems(),
    );

    removeExpiredItems();
  }

  Future<void> _release(String reservationId) async {
    try {
      await _repo.releaseReservation(reservationId);
    } catch (e) {
      LogService.error('release reservation failed', e);
    }
  }

  void _recount() {
    itemCount.value = items.fold(
      0,
          (sum, item) => sum + item.quantity,
    );
  }

  Future<void> add(DealModel deal) async {
    if (isCheckingOut.value) return;

    if (isDealExpired(deal)) {
      Get.snackbar(
        'Flash sale expired',
        '${deal.name} is no longer available.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (!_reservingDealIds.add(deal.id)) return;

    try {
      final existing = items.firstWhereOrNull(
            (item) => item.deal.id == deal.id,
      );

      if (existing != null &&
          existing.quantity >= deal.quantityLeft) {
        Get.snackbar(
          'Stock limit reached',
          'Only ${deal.quantityLeft} items are available.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final previousQuantity = existing?.quantity ?? 0;
      final oldReservation = existing?.reservation;
      final newQuantity = previousQuantity + 1;

      final cartItem = existing ??
          CartItemModel(
            deal: deal,
            quantity: 0,
          );

      if (existing == null) {
        items.add(cartItem);
      }

      // Optimistic update.
      cartItem.quantity = newQuantity;
      items.refresh();
      _recount();

      try {
        final reservation = await _repo.reserve(
          deal.id,
          quantity: newQuantity,
        );

        // Item was removed or expired during the request.
        if (!items.contains(cartItem) ||
            isDealExpired(deal) ||
            isCheckingOut.value) {
          if (items.contains(cartItem)) {
            items.remove(cartItem);
            _recount();
          }

          await _release(reservation.id);

          if (oldReservation != null) {
            await _release(oldReservation.id);
          }
          return;
        }

        cartItem.reservation = reservation;
        items.refresh();

        if (oldReservation != null) {
          await _release(oldReservation.id);
        }
      } catch (e) {
        LogService.error('reservation failed', e);

        if (items.contains(cartItem)) {
          if (previousQuantity == 0) {
            items.remove(cartItem);
          } else {
            cartItem.quantity = previousQuantity;
            cartItem.reservation = oldReservation;
            items.refresh();
          }
          _recount();
        }

        Get.snackbar(
          'Unable to reserve',
          'The requested quantity is unavailable. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } finally {
      _reservingDealIds.remove(deal.id);
      items.refresh();
    }
  }

  Future<void> decrement(int dealId) async {
    if (isCheckingOut.value ||
        !_reservingDealIds.add(dealId)) {
      return;
    }

    try {
      final item = items.firstWhereOrNull(
            (i) => i.deal.id == dealId,
      );
      if (item == null) return;

      if (item.quantity <= 1) {
        await _removeItem(item);
        return;
      }

      final previousQuantity = item.quantity;
      final oldReservation = item.reservation;
      final newQuantity = previousQuantity - 1;

      // Optimistically decrease quantity.
      item.quantity = newQuantity;
      items.refresh();
      _recount();

      try {
        final reservation = await _repo.reserve(
          dealId,
          quantity: newQuantity,
        );

        if (!items.contains(item) ||
            isDealExpired(item.deal)) {
          items.remove(item);
          _recount();
          await _release(reservation.id);

          if (oldReservation != null) {
            await _release(oldReservation.id);
          }
          return;
        }

        item.reservation = reservation;
        items.refresh();

        if (oldReservation != null) {
          await _release(oldReservation.id);
        }
      } catch (e) {
        LogService.error('decrement reservation failed', e);

        if (items.contains(item)) {
          item.quantity = previousQuantity;
          item.reservation = oldReservation;
          items.refresh();
          _recount();
        }

        Get.snackbar(
          'Unable to update bag',
          'Could not update the reservation. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } finally {
      _reservingDealIds.remove(dealId);
      items.refresh();
    }
  }

  Future<void> _removeItem(CartItemModel item) async {
    items.remove(item);
    _recount();

    final reservation = item.reservation;

    if (reservation != null) {
      await _release(reservation.id);
    }
  }

  Future<void> remove(int dealId) async {
    if (isCheckingOut.value) return;

    final item = items.firstWhereOrNull(
          (i) => i.deal.id == dealId,
    );

    if (item == null) return;

    // Remove immediately. An in-flight reserve is cleaned
    // up when its response arrives.
    await _removeItem(item);
  }

  void removeExpiredItems() {
    if (isCheckingOut.value || items.isEmpty) return;

    final now = DateTime.now();

    final expired = items.where((item) {
      final flashEnd = item.deal.flashSaleEndsAt;
      final reservationEnd = item.reservation?.expiresAt;

      final flashExpired = flashEnd != null &&
          !now.isBefore(flashEnd);

      final reservationExpired = reservationEnd != null &&
          !now.isBefore(reservationEnd);

      return flashExpired || reservationExpired;
    }).toList();

    if (expired.isEmpty) return;

    for (final item in expired) {
      // Release without blocking the shared clock.
      unawaited(_removeItem(item));
    }

    Get.snackbar(
      'Reservation expired',
      expired.length == 1
          ? '${expired.first.deal.name} was removed from your bag.'
          : '${expired.length} expired deals were removed from your bag.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> clear() async {
    if (isCheckingOut.value) return;

    final currentItems = items.toList();
    items.clear();
    _recount();

    for (final item in currentItems) {
      final id = item.reservation?.id;
      if (id != null) {
        await _release(id);
      }
    }
  }

  // Checkout consumes reservations, so do not release them.
  void clearAfterCheckout() {
    items.clear();
    _recount();
  }

  bool beginCheckout() {
    removeExpiredItems();

    if (!canCheckout) return false;

    isCheckingOut.value = true;
    return true;
  }

  void finishCheckout() {
    isCheckingOut.value = false;
  }

  num get total =>
      items.fold(0, (sum, item) => sum + item.lineTotal);

  @override
  void onClose() {
    _expiryWorker?.dispose();
    super.onClose();
  }
}