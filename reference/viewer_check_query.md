# Check a free query against the write-keyword blocklist.

Check a free query against the write-keyword blocklist.

## Usage

``` r
viewer_check_query(query)
```

## Arguments

- query:

  A single Cypher query string.

## Value

Invisible NULL on success; aborts with a "blocked keyword" error
otherwise.
