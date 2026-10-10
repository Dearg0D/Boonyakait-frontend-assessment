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
