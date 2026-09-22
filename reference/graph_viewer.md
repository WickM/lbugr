# Launch the interactive graph viewer

Opens a local Shiny app that lets you explore the graph of a LadybugDB
connection: g6R force-layout graph (node/relationship type filters,
N-hop focus subgraph, pagination), a reactable table view, free Cypher
queries (graph-capable results replace the graph, anything else replaces
the table), and CSV/Excel/JSON/PNG exports.

## Usage

``` r
graph_viewer(
  conn,
  port = NULL,
  host = "127.0.0.1",
  launch_browser = interactive(),
  page_size = 300L,
  load_step = 300L,
  ...
)

check_app_deps()
```

## Arguments

- conn:

  A Ladybug connection object, as returned by
  [`lb_connection()`](https://wickm.github.io/lbugr/reference/lb_connection.md).

- port:

  Port for the local Shiny server (default: pick a free one).

- host:

  Host for the local Shiny server.

- launch_browser:

  Open the app in the default browser (default:
  [`interactive()`](https://rdrr.io/r/base/interactive.html)).

- page_size:

  Initial number of nodes rendered in the graph.

- load_step:

  Increment for the "Load more" button.

- ...:

  Further arguments passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

## Value

The Shiny app object (invisible; the server blocks until stopped).

## Details

The app runs in-process on the current R session and uses the given
connection directly (no separate process, no HTTP backend). Write
operations (`CREATE`, `DROP`, `DELETE`, `ALTER`, `DETACH`, `MERGE`) are
blocked client-side.

## Examples

``` r
if (FALSE) { # \dontrun{
conn <- lb_connection(":memory:")
lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
PRIMARY KEY (name))")
lb_execute(conn, "CREATE (:User {name: 'Alice', age: 25})")
graph_viewer(conn)
} # }
```
