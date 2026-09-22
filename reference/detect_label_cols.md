# Ordered label candidates: `label`, first `bezeichnung_*`, then primary key.

Ordered label candidates: `label`, first `bezeichnung_*`, then primary
key.

## Usage

``` r
detect_label_cols(cols, pk)
```

## Arguments

- cols:

  A list of column descriptors (each a list with at least a `name`
  entry) for one table.

- pk:

  The primary-key column name.

## Value

A character vector of candidate label column names (no duplicates).
