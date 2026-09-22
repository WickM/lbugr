# Write keywords blocked in viewer free queries (client-side blocklist).

The reference app enforced this in its Python backend (400 + message);
lbugr has no backend, so the check runs client-side before execution.
Word-boundary matching: `created_at` (a property name) must NOT match.

## Usage

``` r
viewer_blocked_keywords()
```
