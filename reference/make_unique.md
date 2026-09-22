# First occurrence keeps the bare id, later duplicates get `:2`, `:3`, ...

First occurrence keeps the bare id, later duplicates get `:2`, `:3`, ...

## Usage

``` r
make_unique(ids)
```

## Arguments

- ids:

  A character vector of ids.

## Value

A character vector of the same length, with duplicates suffixed.
