# Cap a graph model to its first `n` nodes in the model's node order.

Keeps the first `n` rows of `model$nodes` (the caller is responsible for
putting them in display order, e.g. BFS distance from a focus center)
plus only the edges whose two endpoints are both kept, so the result is
a valid drop-in model for `renderG6` (which reads `$nodes` and
`$edges`). The `table` is passed through untouched – the view renders
the full filtered table, not the capped one.

## Usage

``` r
cap_graph(model, n)
```

## Arguments

- model:

  A model with `$nodes` (id,...) and `$edges` (id,source,target)
  data.frames, as returned by
  [`rows_to_graph()`](https://wickm.github.io/lbugr/reference/rows_to_graph.md)
  /
  [`ego_subgraph()`](https://wickm.github.io/lbugr/reference/ego_subgraph.md).

- n:

  Number of nodes to keep. If `n >= nrow(model$nodes)` the model is
  returned unchanged.

## Value

`list(nodes =, edges =, table =)` with at most `n` nodes.
