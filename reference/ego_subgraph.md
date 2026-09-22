# Extract the N-hop ego subgraph around a node.

Undirected breadth-first search over `graph_model$edges`, starting at
`node_id` and expanding up to `hops` levels. Returns a model-shaped list
(`nodes`/`edges`/`table`) containing only the reachable nodes and the
edges whose endpoints are all inside the neighborhood, so the result is
a drop-in model for `renderG6` (which reads `$nodes` and `$edges`).

## Usage

``` r
ego_subgraph(node_id, graph_model, hops = 2L)
```

## Arguments

- node_id:

  A global node id (`"<type>:<pk>"`) present in the model.

- graph_model:

  A model with `$nodes` (id,label,type,color) and `$edges`
  (id,source,target,rel_type) data.frames, as returned by
  [`rows_to_graph()`](https://wickm.github.io/lbugr/reference/rows_to_graph.md).

- hops:

  Number of hops (\>= 1). Default 2.

## Value

`list(nodes=, edges=, table=)` shaped like
[`rows_to_graph()`](https://wickm.github.io/lbugr/reference/rows_to_graph.md).

## Details

The input `graph_model` is the full filtered model (the module's
`visible_model()`), so the ego respects the active node/rel type
filters.
