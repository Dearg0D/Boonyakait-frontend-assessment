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