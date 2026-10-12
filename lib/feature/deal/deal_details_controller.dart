
import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../service/analytics_service.dart';
import '../../service/cart_service.dart';
import '../../util/log_service.dart';

class DealDetailsController extends GetxController {
  final DealRepo dealRepo;
  final CartService cartService;
  final AnalyticsService analytics;

  DealDetailsController({
    required this.dealRepo,
    required this.cartService,
    required this.analytics,
  });

  final deal = Rxn<DealModel>();
  final isLoading = true.obs;
  final errorMessage = RxnString();

  final _quantityLeft = RxnInt();
  int? get quantityLeft => _quantityLeft.value;

  Worker? _cartWorker;

  @override
  void onInit() {
    super.onInit();

    _cartWorker = ever(
      cartService.itemCount,
          (_) => _recheckAvailability(),
    );

    _loadDeal();
  }

  Future<void> _loadDeal() async {
    isLoading.value = true;
    errorMessage.value = null;

    try {
      DealModel selectedDeal;

      final arguments = Get.arguments;

      if (arguments is DealModel) {
        selectedDeal = arguments;
      } else {
        final id = int.tryParse(
          Get.parameters['id'] ?? '',
        );

        if (id == null) {
          throw Exception('Invalid deal ID');
        }

        selectedDeal = await dealRepo.fetchById(id);
      }

      if (isClosed) return;

      deal.value = selectedDeal;
      _quantityLeft.value = selectedDeal.quantityLeft;

      analytics.logEvent('deal_details_view', {
        'deal_id': selectedDeal.id,
        'source': Get.parameters['source'] ?? 'unknown',
      });
    } catch (e) {
      if (isClosed) return;

      LogService.error('load deal failed', e);
      errorMessage.value = 'Unable to load deal';
    } finally {
      if (!isClosed) {
        isLoading.value = false;
      }
    }
  }

  Future<void> _recheckAvailability() async {
    final currentDeal = deal.value;
    if (currentDeal == null || isClosed) return;

    try {
      final fresh = await dealRepo.fetchById(currentDeal.id);

      if (isClosed || deal.value?.id != currentDeal.id) {
        return;
      }

      _quantityLeft.value = fresh.quantityLeft;
    } catch (e) {
      if (!isClosed) {
        LogService.error('recheck availability failed', e);
      }
    }
  }

  void addToCart() {
    final currentDeal = deal.value;

    if (currentDeal == null || isClosed) return;

    cartService.add(currentDeal);

    Get.snackbar(
      'Added to bag',
      '${currentDeal.name} — pick up ${currentDeal.pickupWindow.label}',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void onClose() {
    _cartWorker?.dispose();
    super.onClose();
  }
}
