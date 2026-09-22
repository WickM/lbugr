# Turn arbitrary query rows into a data frame (free query results).

Unlike
[`rows_to_graph()`](https://wickm.github.io/lbugr/reference/rows_to_graph.md),
no graph shape is required: the union of all field names becomes the
columns (first-seen order); a row missing a field gets NA. Values keep
their original type (numbers stay numeric).

## Usage

``` r
rows_to_df(rows)
```

## Arguments

- rows:

  List of row lists (`viewer_run_query()$results`).

## Value

Data frame (0 rows for empty input).
