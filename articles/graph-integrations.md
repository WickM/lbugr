# Graph Library Integrations

## Introduction

This vignette demonstrates how to convert Ladybug query results into
various R graph library objects, including `igraph`, `tidygraph`, and
`g6R`. It showcases the seamless integration of `lbugr` with popular R
packages for graph analysis and visualization.

## Converting to `igraph`

The `igraph` package is a powerful tool for graph manipulation and
analysis in R. `lbugr` provides a direct conversion function
[`as_igraph()`](https://wickm.github.io/lbugr/reference/as_igraph.md) to
transform Ladybug query results into `igraph` objects.

### Example: Loading and Converting Graph Data

First, let’s set up a Ladybug database and load some sample graph data.

``` r

library(lbugr)
library(igraph)

# Create a connection
db_path <- tempfile()
con <- lb_connection(db_path)

# Create schema for nodes and relationships
lb_execute(con, paste("CREATE NODE TABLE Person(name STRING, age INT64,",
                        "PRIMARY KEY (name))"))
lb_execute(con, "CREATE REL TABLE Knows(FROM Person TO Person, since INT64)")

# Prepare data frames
persons_data <- data.frame(
  name = c("Alice", "Bob", "Carol"),
  age = c(35, 45, 25)
)

knows_data <- data.frame(
  from_person = c("Alice", "Bob"),
  to_person = c("Bob", "Carol"),
  since = c(2010, 2015)
)

# Load data into Ladybug
lb_copy_from_df(con, persons_data, "Person")
lb_copy_from_df(con, knows_data, "Knows")
```

Now, let’s execute a query that returns graph data and convert it to an
`igraph` object.

``` r

# Query to get all persons and their relationships
graph_query_result <- lb_execute(con, paste("MATCH (p1:Person)-[k:Knows]->",
                                              "(p2:Person) RETURN p1, p2, k"))

# Convert the Ladybug result to an igraph object
igraph_graph <- as_igraph(graph_query_result)

# Print the igraph object summary
print(igraph_graph)

V(igraph_graph)$label <- igraph::V(igraph_graph)$name
E(igraph_graph)$label <- "knows"
plot(igraph_graph,
     vertex.color = "#dc2626",
     vertex.label.color = "#f3f4f6",
     vertex.label.font = 2,
     edge.color = "#9ca3af",
     edge.arrow.size = 0.8,
     edge.arrow.width = 0.5,
     bg = "#030712",
     main = "igraph Graph")
```

You can now perform standard `igraph` operations on `igraph_graph`.

## Converting to `tidygraph`

The `tidygraph` package offers a tidy data approach to graph
manipulation, integrating seamlessly with the tidyverse. `lbugr`
supports conversion to `tidygraph` objects via
[`as_tidygraph()`](https://wickm.github.io/lbugr/reference/as_tidygraph.md).

### Example: Converting to `tidygraph`

Using the same Ladybug query result, we can convert it to a `tidygraph`
object.

``` r

# Convert the Ladybug result to a tidygraph object
tidygraph_graph <- as_tidygraph(graph_query_result)

# Print the tidygraph object summary
print(tidygraph_graph)
ggraph::ggraph(tidygraph_graph, layout = "kk") +
  ggraph::geom_edge_arrow(color = "#9ca3af", arrow.fill = "#9ca3af", end_cap = ggraph::arrow(angle = 30, length = grid::unit(3, "mm"))) +
  ggraph::geom_node_point(color = "#dc2626", size = 8) +
  ggraph::geom_node_text(ggplot2::aes(label = name), color = "#f3f4f6", size = 4, vjust = -1) +
  ggplot2::theme_void() +
  ggplot2::theme(plot.background = ggplot2::element_rect(fill = "#030712", color = NA))
```

## Interactive Visualization with `g6R`

The `g6R` package provides an R interface to the G6 JavaScript graph
visualization library, enabling rich, interactive visualizations
directly within R environments. Since `g6R` has built-in support for
`igraph` objects, you can easily create interactive visualizations by
first converting your Ladybug query result to an `igraph` object.

### Example: Creating an Interactive `g6R` Graph

Building on the previous examples, we can convert the Ladybug query
result into a `g6R` object. We can then customize the appearance of the
nodes and edges for a more informative visualization.

``` r

library(g6R)
graph_query_result <- lb_execute(con, paste("MATCH (p1:Person)-[k:Knows]->",
                                              "(p2:Person) RETURN p1, p2, k"))
# Convert the Ladybug result to a g6R-compatible list
igraph_graph <- as_igraph(graph_query_result)

g6 <- g6_igraph(igraph_graph) |>
  g6_layout(d3_force_layout()) |>
  g6_options(
    animation = FALSE,
    node = list(
      style = list(
        labelText = JS("(d) => d.name")
      )
    ),
    edge = list(
      style = list(
        endArrow = TRUE,
        labelText = JS("(d) => d.data.label")
      )
    )
  ) |>
  g6_behaviors(
    zoom_canvas(),
    collapse_expand(),
    drag_canvas(),
    drag_element()
  ) |>
  g6_plugins("toolbar")


# Display the graph
g6
```
