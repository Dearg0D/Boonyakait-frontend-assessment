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