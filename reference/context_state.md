# Context (1-hop neighborhood) for a selected node of the graph model.

Given a selected node id, classifies every node as "selected" /
"neighbor" / "other" and marks the edges that must be dimmed (edges not
touching the selected node). The UI uses this for context mode: selected

- neighbors stay colored, everything else is greyed out.

## Usage

``` r
context_state(node_id, graph_model)
```

## Arguments

- node_id:

  Global node id `<type>:<pk>` (as produced by
  [`rows_to_graph()`](https://wickm.github.io/lbugr/reference/rows_to_graph.md))
  or `NULL` for no selection.

- graph_model:

  Output of
  [`rows_to_graph()`](https://wickm.github.io/lbugr/reference/rows_to_graph.md).

## Value

`list(selected = <node_id or NULL>, neighbor_ids = <chr vector of 1-hop neighbors>, node_class = <named chr vector over all node ids>, dim_edge_ids = <chr vector of edge ids to dim>)`.
