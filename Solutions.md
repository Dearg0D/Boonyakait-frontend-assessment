# Rescu — Flutter Developer Assessment Solutions
## Part A — Bug Fixes
### RES-101 — Search Results Race Condition

**Root Cause**

The `SearchDealsController` triggers an asynchronous search request every time the user changes the search text.
Since multiple requests can execute concurrently, their responses may arrive out of order. An older request can finish after a newer request and overwrite the latest search results.

**Solution**

Implemented request versioning using `_searchVersion` to track the latest search request.
Each new search increments the version. Before updating the results, the controller checks whether the response belongs to the latest request.
Also added a controller lifecycle check using `isClosed` to prevent updates after disposal and used `finally` to manage the loading state correctly.

**Alternative Considered**

Debouncing was considered to reduce unnecessary API requests.
However, debouncing alone does not guarantee that older requests will not overwrite newer results. Request versioning was selected to prevent this race condition.

**Edge Cases**

- Rapid typing with multiple concurrent search requests
- Clearing the search input during an active request
- Older requests returning after newer requests
- Search request failures
- Controller disposal during an active request

**Testing**

Testing to be documented after verification, including out-of-order responses and clearing the input during an active request.

**AI Usage**

Used ChatGPT to analyze the asynchronous search behavior, understand the race condition, review request versioning, and identify potential edge cases.
The suggested solution was reviewed before implementation.

**Time Spent**

Approximately 20 minutes (including investigation, implementation, and documentation).

### RES-102 — Crash After Leaving My Orders

**Root Cause**

The `PickupCountdown` widget creates a periodic timer in `initState()` to update the countdown every second using `setState()`.

However, the timer was not cancelled when the widget was disposed. After navigating away from the My Orders screen, the timer continued running and attempted to call `setState()` on a disposed widget, causing the `setState() called after dispose()` error.

**Solution**

- Added a `Timer? _timer` variable to store the timer reference.
- Updated `initState()` to assign the periodic timer to `_timer`.
- Added a `dispose()` method to cancel the timer using `_timer?.cancel()`.
- Added a `mounted` check before calling `setState()` as an additional safety measure.

This ensures the timer stops when the widget is removed from the widget tree, preventing unnecessary background execution and lifecycle-related errors.

**Alternative Considered**

I considered using only `if (mounted)` before calling `setState()`.

However, this would only prevent the exception without stopping the timer. The timer would continue running unnecessarily and retaining resources.

Cancelling the timer in `dispose()` is a better solution because it fixes the root cause.

**Edge Cases**

- Navigating away while the countdown is active.
- Reopening the My Orders screen multiple times.
- Multiple active orders with independent countdown timers.
- Countdown reaching the pickup start time.

**Testing**

- Open My Orders with an upcoming pickup.
- Verify that the countdown updates every second.
- Navigate back and wait several seconds.
- Verify that no `setState() called after dispose()` error occurs.
- Reopen and close My Orders multiple times.

**AI Usage**

Used ChatGPT to analyze the widget lifecycle issue, identify the uncancelled periodic timer, and review the correct approach for managing timer resources in Flutter.

**Time Spent**

Approximately 25 minutes (including investigation, implementation, and documentation).

### RES-103 — Requests Pile Up the Longer You Browse

**Root Cause**

The `DealDetailsController` registered a GetX worker using `ever()` inside `onInit()` to monitor changes in `cartService.itemCount`.

Whenever the cart changed, the worker called `_recheckAvailability()`, which triggered a `GET /deals/:id` request.

However, the worker was not disposed of when the controller was closed. As users opened more deal detail pages, the old listeners continued responding to cart changes, causing multiple unnecessary API requests for previously viewed deals.

**Solution**

- Added a `Worker? _cartWorker` variable to store the GetX worker reference.
- Updated `onInit()` to assign the worker returned by `ever()` to `_cartWorker`.
- Implemented `onClose()` to dispose of the worker using `_cartWorker?.dispose()`.
- Added an `isClosed` check after the asynchronous API request to prevent updating a closed controller.

This ensures that the worker is cleaned up when the controller is disposed of, preventing old listeners from continuing to trigger API requests.

**Alternative Considered**

I considered removing the `ever()` listener entirely.

However, the listener is needed to refresh deal availability when the cart changes.

Instead, I kept the listener and managed its lifecycle properly by disposing of it in `onClose()`.

**Edge Cases**

- Opening and closing multiple deal detail pages.
- Adding items to the cart after visiting several deals.
- Navigating away while an API request is still running.
- Reopening the same deal multiple times.
- Preventing updates after the controller is closed.

**Testing**

- Open multiple deal detail pages and navigate back.
- Add a deal to the cart.
- Verify that closed deal pages no longer trigger `GET /deals/:id` requests.
- Verify that the currently active deal still refreshes its availability.
- Repeat the process to confirm that API requests do not accumulate.

**AI Usage**

Used ChatGPT to analyze the GetX worker lifecycle, identify the missing listener cleanup, and review the use of `Worker.dispose()` and `isClosed`.

**Time Spent**

Approximately 35 minutes (including investigation, implementation, and documentation).

### RES-104 — Duplicate Deals in the Home Feed

**Root Cause**

The `HomeController` had a race condition between pagination (`loadMore()`) and pull-to-refresh (`refreshDeals()`).

When the user scrolled to the bottom of the home feed, `loadMore()` started fetching the next page. If the user triggered a refresh before that request completed, `refreshDeals()` reset the page number and loaded the first page again.

However, the previous pagination request was still running and could append its results to the refreshed list using `deals.addAll()`.

This caused duplicate deals, inconsistent pagination, and sometimes more items than the catalog contained.

**Solution**

- Implemented request generation tracking using `_generation` to distinguish between old and current requests.
- Incremented `_generation` whenever a new refresh started, invalidating responses from previous requests.
- Added a generation check before updating the deal list to prevent outdated responses from modifying the current feed.
- Used a local `nextPage` variable instead of incrementing `_page` before the API request completed.
- Added a guard to prevent pagination from starting while a refresh was in progress.
- Added an `isClosed` check to prevent state updates after the controller was disposed.
- Used `finally` to manage loading states and refresh controller completion.

This ensures that only responses belonging to the current feed generation can update the displayed deals.

**Alternative Considered**

I considered removing duplicate deals by filtering items with the same deal ID before adding them to the list.

However, this would only hide the duplicated items without solving the underlying race condition. It could also leave the pagination state inconsistent.

I chose request generation tracking because it prevents outdated API responses from modifying the feed.

**Edge Cases**

- Pull-to-refresh while the next page is loading.
- Multiple refresh requests occurring close together.
- Old pagination requests completing after a refresh.
- API failures during pagination or refresh.
- Reaching the final page of the catalog.
- Controller disposal while an API request is still running.

**Testing**

- Scroll to the bottom of the home feed to trigger pagination.
- Pull to refresh while the next page is still loading.
- Verify that old pagination responses do not modify the refreshed list.
- Verify that no duplicate deal cards appear.
- Verify that pagination continues correctly after refreshing.
- Repeat the process multiple times to check for race conditions.

**AI Usage**

Used ChatGPT to analyze the asynchronous pagination flow, identify the race condition between `loadMore()` and `refreshDeals()`, and review request generation tracking as a solution.

**Time Spent**

Approximately 45 minutes (including investigation, implementation, and documentation).

### RES-105 — Home Feed Performance and Memory Optimization

**Root Cause**

The Home Feed had several performance issues affecting scrolling smoothness and memory usage.

1. **Excessive Widget Rebuilds:** The entire `Scaffold` was wrapped in an `Obx()` that observed `scrollOffset`, causing unnecessary widget rebuilds during scrolling.

2. **Eager Widget Creation:** The Home Feed used `ListView` with predefined children, creating all deal cards upfront instead of building them lazily.

3. **Image Memory Usage:** `CachedNetworkImage` did not specify image decode dimensions, potentially retaining images at unnecessarily large resolutions.

**Solution**

- Refactored the Home Screen to separate reactive components and reduce unnecessary widget rebuilds.
- Replaced continuous reactive scroll offset updates with threshold-based state changes for AppBar elevation and the Scroll-to-Top button.
- Replaced `ListView` with `ListView.builder()` to lazily create deal cards.
- Added `memCacheWidth` and `memCacheHeight` to optimize decoded image dimensions based on available layout constraints and device pixel ratio.

These changes reduce unnecessary widget construction, limit reactive updates, and improve image memory management.

**Alternative Considered**

I considered throttling scroll events and manually clearing the image cache.

However, throttling alone would not address the excessive widget rebuild scope, while manually clearing the image cache could cause unnecessary image reloading.

I chose targeted reactive state updates, lazy list rendering, and image decode optimization to address the underlying performance issues.

**Edge Cases**

- Scrolling through large paginated lists.
- Pull-to-refresh during pagination.
- Switching the Pickup Today filter.
- Rendering images with different dimensions.
- Maintaining Scroll-to-Top functionality.
- Preserving navigation and existing Home Feed behavior.

**Performance Evidence — Flutter Web**

Performance and memory were evaluated using Chrome DevTools.

| Metric                | Before Fix | Measured After Fix |
|-----------------------|-----------:|-------------------:|
| Scripting Time        | 4,547 ms   | 4,207 ms           |
| Recording Duration    | 5.21 s     | 5.11 s             |
| Rendering Time        | 50 ms      | 55 ms              |
| Initial Heap Snapshot | 187 MB     | 186 MB             |
| Heap After Scrolling  | 196 MB     | 194 MB             |

The selected performance recordings showed approximately a 7.5% reduction in scripting time.

In a separate memory measurement, the heap size after scrolling was 194 MB, compared with 196 MB in the initial baseline.

These results provide preliminary evidence of improvement, but the scripting recordings included compilation and loading activity, and the memory measurements were collected in separate sessions. Further controlled measurements are needed to confirm the performance improvement.

**Testing Limitations**

Testing was performed using Flutter Web because the Android Emulator was unstable on the development machine.

Android-specific frame performance and image cache behavior have not yet been validated on a physical device.

**AI Usage**

Used ChatGPT to analyze GetX reactive widget rebuilds, identify performance issues in the Home Feed, evaluate lazy list rendering, and review image decoding optimizations.

AI was also used to assist with interpreting Chrome DevTools performance and memory measurements.

**Time Spent**

Approximately 2 Hours (including investigation, implementation, and documentation).

### RES-106 — Wrong Pickup Times and Incorrect "Pickup Today" Filter

**Root Cause**

The `PickupWindowModel` had two issues related to date and time handling.

1. **Incorrect Timezone Conversion:** The backend sends pickup times as ISO-8601 UTC strings. The original implementation used `DateTime.parse()` without converting the parsed values to local time before displaying them.

   This caused pickup windows to display UTC times instead of local times. For example, a pickup window of 23:00–02:30 UTC was displayed incorrectly instead of 06:00–09:30 in Thailand (UTC+7).

2. **Incorrect Date Comparison:** The `isToday` getter compared only `start.day` with `DateTime.now().day`, without checking the month, year, or timezone.

   This caused some deals to be incorrectly included or excluded from the "Pickup today" filter.

**Solution**

- Updated `PickupWindowModel.fromJson()` to convert UTC timestamps to local time using `.toLocal()`.
- Updated the `label` getter to display pickup times in the device's local timezone.
- Fixed the `isToday` getter to compare the year, month, and day using local dates.
- Adjusted `isOpenNow` to include the exact pickup start time while excluding the end time.
- Kept time comparisons consistent by using Dart's `DateTime` comparison methods.

These changes ensure that pickup times are displayed correctly and that the "Pickup today" filter uses consistent local dates.

**Alternative Considered**

I considered adding seven hours directly to the UTC timestamps to convert them to Thailand time.

However, hardcoding a UTC+7 offset would not work correctly for users in other timezones and could introduce additional problems if the application's regional requirements changed.

I chose `.toLocal()` because it uses the device's configured timezone and avoids hardcoded offsets.

**Edge Cases**

- Pickup windows crossing midnight.
- UTC dates differing from local dates.
- The same day number occurring in different months or years.
- Pickup times exactly at the start or end of a window.
- Users operating in different device timezones.

**Testing**

- Verify that 23:00–02:30 UTC displays as 06:00–09:30 when the device timezone is Asia/Bangkok.
- Verify that "Pickup today" includes deals starting today in local time.
- Verify that deals from different months or years are excluded.
- Verify pickup windows crossing midnight.
- Run automated tests for UTC parsing and date comparison.

**AI Usage**

Used ChatGPT to analyze the UTC-to-local timezone issue, identify the incorrect date comparison in `isToday`, review the use of `DateTime.toLocal()`, and explore automated testing strategies.

**Time Spent**

Approximately 30 minutes (including investigation, implementation, and documentation).

### RES-107 — Deep Link Opens to a Crash

**Root Cause**

The `DealDetailsController` originally expected a `DealModel` to be passed through `Get.arguments` when opening the deal details screen.

This worked when navigating from the Home Feed because the selected deal was passed as an argument.

However, when opening a deal through a deep link such as `rescu://open/deal?id=42&source=push`, the navigation only provided the deal ID through URL parameters, without a `DealModel` object.

The controller attempted to cast `Get.arguments` to `DealModel`, resulting in the error `type 'Null' is not a subtype of type 'DealModel'`.

Additionally, the `DealDetailsScreen` assumed that the deal data was immediately available, which did not support asynchronous loading.

**Solution**

- Changed the deal state from `late final DealModel` to `Rxn<DealModel>` to support asynchronous loading.
- Added `isLoading` and `errorMessage` states to manage the loading process.
- Updated the controller to support both navigation methods:
  - Normal navigation: retrieve the `DealModel` from `Get.arguments`.
  - Deep link navigation: retrieve the deal ID from `Get.parameters` and fetch the deal using `dealRepo.fetchById(id)`.
- Updated `DealDetailsScreen` to display a loading indicator while fetching deal information.
- Used `Obx()` to rebuild the screen when the deal data becomes available.
- Added `isClosed` checks to prevent asynchronous operations from updating a disposed controller.
- Preserved the GetX worker cleanup implemented in RES-103.

This allows users to open a fully functional deal details screen from both the Home Feed and deep links.

**Alternative Considered**

I considered checking whether `Get.arguments` was null and displaying a fallback screen.

However, this would only prevent the crash without fulfilling the requirement to display the requested deal.

Instead, I implemented asynchronous deal loading using the deal ID from the deep link.

**Edge Cases**

- Opening a deal from the Home Feed with an existing `DealModel`.
- Opening a deal directly using a deep link.
- Handling asynchronous data loading.
- Invalid or missing deal IDs.
- API failures during deal loading.
- Navigating away before the request completes.
- Preventing GetX workers from remaining active after leaving the screen.

**Testing**

- Open the deal details screen using the simulated deep link.
- Verify that deal ID 42 displays the correct information.
- Verify that the deal can be added to the bag successfully.
- Verify that normal navigation from the Home Feed still works.
- Verify that no errors occur when navigating away during loading.
- Test the deep link on Android using ADB.

**AI Usage**

Used ChatGPT to identify the null argument issue, analyze GetX navigation parameters, implement asynchronous deal loading, and update the reactive UI to support loading and error states.

AI was also used to review controller lifecycle handling and maintain compatibility with the worker cleanup implemented in RES-103.

**Time Spent**

Approximately 1 Hours (including investigation, implementation, and documentation).

## Part B — Features

### F-1 — Live Flash-Sale Countdowns

**Implementation**

Implemented a real-time flash-sale countdown system using the `flashSaleEndsAt` field from `DealModel`.

The countdown displays the remaining time in `mm:ss` format, or `hh:mm:ss` when one hour or more remains.

The countdown is integrated into:
- Flash Sale Rail
- Home Feed Deal Cards
- Deal Details Screen
- Cart Screen

**Architecture and Solution**

1. **Shared Clock Service**

   Created `FlashSaleClockService` using GetX to manage a single shared `Timer.periodic()`.

   The service updates the current time every second, allowing multiple countdown widgets to observe the same clock without creating individual timers.

2. **Reusable Countdown Widget**

   Created `FlashSaleCountdown` to calculate and display the remaining time.

   The widget uses `Obx()` to update the countdown text every second and automatically displays `Expired` when the remaining time reaches zero.

   Added support for custom text colors and a `FLASH SALE` label to maintain consistent styling across different screens.

3. **Expiration Handling**

   Updated `CartService.add()` to reject expired flash-sale deals.

   Updated the Deal Details Screen to disable the Add to bag button when the countdown expires.

   Expired deals display an `Expired` state instead of the active countdown.

4. **Automatic Cart Cleanup**

   Added expiration monitoring to `CartService` using the shared clock.

   When a flash-sale deal expires, it is removed from the cart, the item count and total are recalculated, and a Snackbar notifies the user.

5. **Performance Optimization**

   Used a shared clock instead of creating separate timers for each countdown.

   Scoped reactive countdown updates to small widgets using `Obx()` to avoid rebuilding the entire Home Feed every second.

   This approach reduces unnecessary timer management and limits reactive UI updates.

**Alternative Considered**

I considered creating a separate `Timer.periodic()` for each deal card.

However, this would introduce unnecessary timers, increase lifecycle management complexity, and potentially affect performance when displaying many flash-sale deals.

I chose a shared clock service because it centralizes time updates and allows each countdown widget to calculate its remaining duration independently.

**Edge Cases**

- Flash-sale deals that have already expired.
- Countdown reaching exactly zero.
- Multiple deals expiring at the same time.
- Deals expiring while the user is viewing the details screen.
- Expired deals already present in the cart.
- Preventing expired deals from being added again.
- Navigating between screens while countdowns remain active.
- Handling deals with no flash-sale expiration.

**Testing**

**Widget Rebuild Verification**

Used temporary `debugPrint()` instrumentation in `HomeScreen`, `DealCard`, and `FlashSaleCountdown` to inspect widget rebuild behavior.

During testing on Flutter Web, countdown widgets continued rebuilding to update their displayed time, while `HomeScreen` and `DealCard` did not repeatedly invoke their build methods every second.

This provides evidence that periodic countdown updates are scoped to smaller reactive widgets rather than rebuilding the entire Home Feed under the tested conditions.

**Functional Testing Checklist**

- Verify countdown formatting (`mm:ss` and `hh:mm:ss`).
- Verify countdowns update every second across the required screens.
- Verify expired deals display the `Expired` state.
- Verify Add to bag is disabled after expiration.
- Verify expired items are automatically removed from the cart.
- Verify cart totals and quantities update correctly.
- Verify the expiration Snackbar appears.
- Verify HomeScreen and DealCard build methods are not repeatedly called by countdown updates during the observed Flutter Web test.

**Testing Limitations**

Testing was performed using Flutter Web because the Android Emulator was unstable on the development machine.

Widget rebuild behavior was inspected through Console logging. However, Android-specific frame performance with 100+ visible countdowns has not yet been validated using Flutter DevTools.

**AI Usage**

Used ChatGPT to design the shared clock architecture, implement the reusable countdown widget, and manage flash-sale expiration behavior.

AI was also used to investigate GetX dependency registration, optimize reactive widget rebuilds, and review the integration with `CartService`.

Temporary debug logging was used to verify the suggested rebuild approach.

**Time Spent**

Approximately 2 Hours (including investigation, implementation, and documentation).

### F-2 — Deal Impression Tracking

**Implementation**

Implemented a deal impression tracking system using `VisibilityDetector` and `AnalyticsService`.

The system records a `deal_impression` event when a deal card is at least 50% visible on the screen for 1 continuous second.

Impression tracking is integrated into:
- Home Feed (`home_feed`)
- Flash Sale Rail (`flash_rail`)
- Search Results (`search`)

Each event includes the following properties:
- `deal_id`: Unique ID of the deal.
- `source`: The screen or section where the impression occurred.
- `position`: The deal's index within its list.

**Architecture and Solution**

1. **Reusable Impression Tracker**

   Created `DealImpressionTracker` as a reusable StatefulWidget using the existing `visibility_detector` package.

   When a deal card becomes at least 50% visible, a 1-second timer starts. If visibility drops below 50% before the timer completes, the timer is cancelled.

   The widget also handles timer cleanup in `dispose()` and resets its tracking state when the associated deal changes.

2. **Session-Level Deduplication**

   Added a `Set<int>` named `_trackedDealIds` in `AnalyticsService` to store deal IDs already recorded during the current app session.

   Each deal can generate a `deal_impression` event only once per session, even when it appears in multiple screens.

3. **Analytics Batching**

   Implemented an in-memory event queue using `_pendingEvents`.

   Instead of sending events individually, the system calls `FakeApiService.sendAnalyticsBatch()` when either:
   - 10 impression events have accumulated.
   - 15 seconds have passed since the first pending event.

   The first condition reached triggers the batch delivery.

4. **Batch Delivery and Error Handling**

   Added `_isSending` to prevent concurrent batch requests.

   Pending events are converted to JSON using `AnalyticsEvent.toJson()` before being sent to the simulated backend.

   If a batch request fails, the events are restored to the pending queue for a later retry.

5. **Performance Considerations**

   Visibility tracking is handled within individual deal card wrappers rather than the entire list.

   Timers are cancelled when no longer needed, and events are batched to reduce unnecessary backend requests.

   The existing `AnalyticsService.logEvent()` behavior was preserved for other events such as `screen_view` and `deal_details_view`.

**Alternative Considered**

I considered recording impressions immediately when deal cards were built or when they first appeared on screen.

However, a widget being built does not guarantee that the user actually viewed it. This approach could also record impressions for cards that users scroll past quickly.

I chose visibility-based tracking with a continuous 1-second threshold because it more accurately represents meaningful user exposure.

I also considered sending each event immediately, but batching was selected to reduce the number of requests and meet the API delivery requirements.

**Edge Cases**

- A deal card is visible for less than 1 second.
- Visibility falls below 50% before the timer completes.
- A card becomes visible again after being scrolled away.
- The same deal appears in multiple screens.
- Multiple impressions are detected close together.
- The widget is disposed while its visibility timer is active.
- A batch request fails or new events arrive while a batch is being sent.
- The app closes before pending events are delivered.

**Testing**

- Verified impression events are recorded after meeting the visibility threshold.
- Verified cards scrolled past too quickly do not generate impressions.
- Verified each deal is recorded only once per app session.
- Verified impression events include `deal_id`, `source`, and `position`.
- Verified tracking works across Home Feed, Flash Rail, and Search Results.
- Verified batch delivery when 10 events accumulate.
- Verified batch delivery after 15 seconds when fewer than 10 events are pending.
- Verified analytics events using the Analytics Debug screen and console logs.

**Testing Limitations**

Functional testing was performed using Flutter Web because the Android Emulator was unstable on the development machine.

Android-specific scrolling performance has not yet been profiled. Further testing on a physical Android device is recommended to verify that visibility tracking does not introduce frame drops.

The event queue is stored in memory, so pending events may be lost if the application terminates before batch delivery.

**AI Usage**

Used ChatGPT to analyze the existing `AnalyticsService`, design session-level impression deduplication, implement reusable visibility tracking, and develop the event batching mechanism.

AI was also used to review timer lifecycle management, batch delivery conditions, error handling, and integration with the Home Feed, Flash Rail, and Search Results.

**Time Spent**

Approximately 1 Hours 30 minutes (including investigation, implementation, and documentation).

### F-3 — Stock Reservations with Optimistic UI

**Implementation**

Implemented a stock reservation system that connects the shopping cart with the simulated backend using `OrderRepo.reserve()` and `OrderRepo.releaseReservation()`.

Each reservation holds stock for 5 minutes. The system supports optimistic cart updates, reservation management, expiration handling, and checkout validation.

**Architecture and Solution**

1. **Optimistic UI Updates**

   Updated `CartService.add()` to immediately add items to the cart before receiving the API response.

   When the reservation succeeds, the returned `ReservationModel` is stored in the corresponding `CartItemModel`.

   If the reservation fails with HTTP 409, the optimistic update is rolled back to the previous quantity, and a user-friendly Snackbar is displayed.

2. **Reservation Quantity Management**

   Implemented reservation updates when users increase or decrease item quantities.

   When the quantity changes, the application requests a new reservation for the updated quantity.

   After the new reservation succeeds, the previous reservation is released to prevent unnecessary stock holds.

   If the new reservation fails, the cart quantity and reservation are restored to their previous valid state.

3. **Reservation Release**

   Updated the cart removal logic to call `releaseReservation()` when an item is removed.

   When the quantity reaches zero, the item is removed from the cart and its reservation is released.

   This prevents unused reservations from remaining active unnecessarily.

4. **Reservation Countdown**

   Created a reusable `ReservationCountdown` widget to display the remaining reservation time in `mm:ss` format.

   The countdown uses the existing `FlashSaleClockService` to share a single timer rather than creating additional timers for each cart item.

   The cart displays a `Reserving...` state while waiting for the backend response and a live reservation countdown after successful reservation.

5. **Expiration Handling**

   Implemented automatic expiration checking for cart items.

   When a reservation expires, the item is removed from the cart, the item count and total are recalculated, and the user receives a Snackbar notification.

   Flash-sale expiration is also checked to maintain compatibility with F-1.

6. **Checkout Validation**

   Added validation to prevent checkout while reservations are pending, missing, or expired.

   The existing `OrderRepo.checkout()` passes each item's `reservationId` to the simulated backend.

   After successful checkout, the cart is cleared without unnecessarily releasing reservations already consumed by the order.

   Added handling for HTTP 410 responses to inform users when a reservation has expired.

7. **Concurrent Request Handling**

   Added reservation-in-progress tracking to prevent overlapping reservation requests for the same deal.

   Quantity controls and checkout availability are restricted during relevant pending operations.

   The implementation also checks whether cart items still exist when asynchronous reservation requests complete.

**Product Decision — Reservation Expiration**

I chose to automatically remove expired reservations from the cart rather than renew them without user confirmation.

This avoids misleading users into believing stock is still reserved after the backend hold has expired.

If a reservation expires during checkout, the application informs the user and requires them to add the items again.

This behavior prioritizes stock consistency and makes reservation expiration clear to the user.

**Alternative Considered**

I considered automatically renewing reservations before expiration.

However, automatic renewal could create unexpected stock holds and does not guarantee that the backend will successfully extend the reservation.

I also considered releasing the existing reservation before requesting a new quantity.

However, this could cause users to lose their existing valid reservation if the new request fails.

Instead, I chose to reserve the updated quantity first and release the previous reservation only after the new reservation succeeds.

**Edge Cases**

- Reservation failure with HTTP 409.
- Insufficient stock when increasing quantity.
- Reducing item quantity while maintaining a valid reservation.
- Removing the final item from the cart.
- Multiple reservation requests for the same deal.
- Reservation expiration while the user is viewing the cart.
- Flash-sale expiration while a reservation is active.
- Reservation expiration during checkout.
- HTTP 410 responses from the backend.
- Navigating between screens while reservation requests are running.
- Releasing reservations when items are removed.

**Testing**

- Verified optimistic cart updates when adding items.
- Verified successful reservations and reservation ID assignment.
- Verified HTTP 409 handling and quantity rollback.
- Verified reservation updates when increasing quantities.
- Verified reservation updates when decreasing quantities.
- Verified previous reservations are released after successful updates.
- Verified reservations are released when items are removed.
- Verified the 5-minute reservation countdown in the cart.
- Verified expired reservations are removed from the cart.
- Verified cart totals and item counts update after expiration.
- Verified successful checkout using reservation IDs.
- Verified HTTP 410 expiration handling during checkout.

**Testing Limitations**

Functional testing was performed using Flutter Web because the Android Emulator was unstable on the development machine.

The simulated backend was used to verify reservation requests, release operations, HTTP 409 responses, and checkout behavior.

Additional automated testing would be beneficial for concurrent cart modifications, asynchronous request ordering, and reservation release failures.

The implementation does not currently persist failed release requests for later retries. In these cases, server-side reservation expiration provides a final cleanup mechanism.

**AI Usage**

Used ChatGPT to analyze the existing reservation API contract, design optimistic cart updates, and implement reservation lifecycle management.

AI assistance was also used to review quantity adjustments, rollback behavior, reservation countdowns, HTTP 409 and 410 handling, and integration with the existing Flash Sale functionality.

The implementation was reviewed and functionally tested using the simulated backend and console logs.

**Time Spent**

Approximately 3 hours (including investigation, implementation, testing, and documentation).