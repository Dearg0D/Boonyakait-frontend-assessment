import 'package:get/get.dart';

import '../../repository/order_repo.dart';
import '../../service/api_exception.dart';
import '../../service/cart_service.dart';
import '../../util/log_service.dart';

class CartController extends GetxController {
  final CartService cartService;
  final OrderRepo orderRepo;

  CartController({required this.cartService, required this.orderRepo});

  final isCheckingOut = false.obs;


  Future<void> checkout() async {
    if (isCheckingOut.value) return;

    if (!cartService.beginCheckout()) {
      Get.snackbar(
        'Cannot checkout',
        'Please wait for reservations to complete or review expired items.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isCheckingOut.value = true;

    try {
      final order = await orderRepo.checkout(
        cartService.items.toList(),
      );

      // Reservations have been consumed by checkout.
      cartService.clearAfterCheckout();

      Get.snackbar(
        'Order confirmed',
        'Order #${order.id} — pick up soon!',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on ApiException catch (e) {
      LogService.error('checkout failed', e);

      if (e.statusCode == 410) {
        Get.snackbar(
          'Reservation expired',
          'Your reservation has expired. Please add the items again.',
          snackPosition: SnackPosition.BOTTOM,
        );

        cartService.finishCheckout();
        await cartService.clear();
      } else {
        Get.snackbar(
          'Checkout failed',
          e.message,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      LogService.error('checkout failed', e);

      Get.snackbar(
        'Checkout failed',
        'Something went wrong. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      cartService.finishCheckout();
      isCheckingOut.value = false;
    }
  }
}
