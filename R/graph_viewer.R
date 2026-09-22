# Graph viewer: the exported entry point + app glue.
#
# The app itself lives in inst/graph_viewer/ (view/graph_module.R + app.R)
# and is loaded into an isolated environment whose parent is this package's
# namespace, so the module can call the internal viewer_* functions without
# ':::'. Only graph_viewer() is exported (decision D1).

# App dependency packages (Suggests), in dependency-check order.
.app_dep_packages <- c("shiny", "bslib", "g6R", "reactable",
                       "openxlsx", "jsonlite", "rlang")

#' Launch the interactive graph viewer
#'
#' Opens a local Shiny app that lets you explore the graph of a LadybugDB
#' connection: g6R force-layout graph (node/relationship type filters,
#' N-hop focus subgraph, pagination), a reactable table view, free Cypher
#' queries (graph-capable results replace the graph, anything else replaces
#' the table), and CSV/Excel/JSON/PNG exports.
#'
#' The app runs in-process on the current R session and uses the given
#' connection directly (no separate process, no HTTP backend). Write
#' operations (`CREATE`, `DROP`, `DELETE`, `ALTER`, `DETACH`, `MERGE`) are
#' blocked client-side.
#'
#' @param conn A Ladybug connection object, as returned by `lb_connection()`.
#' @param port Port for the local Shiny server (default: pick a free one).
#' @param host Host for the local Shiny server.
#' @param launch_browser Open the app in the default browser (default:
#'   `interactive()`).
#' @param page_size Initial number of nodes rendered in the graph.
#' @param load_step Increment for the "Load more" button.
#' @param ... Further arguments passed to `shiny::runApp()`.
#' @return The Shiny app object (invisible; the server blocks until stopped).
#' @export
#' @examples
#' \dontrun{
#' conn <- lb_connection(":memory:")
#' lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
#' PRIMARY KEY (name))")
#' lb_execute(conn, "CREATE (:User {name: 'Alice', age: 25})")
#' graph_viewer(conn)
#' }
graph_viewer <- function(conn, port = NULL, host = "127.0.0.1",
                         launch_browser = interactive(),
                         page_size = 300L, load_step = 300L, ...) {
  if (!inherits(conn, "python.builtin.object")) {
    stop("`conn` must be a Ladybug connection object from lb_connection().",
         call. = FALSE)
  }
  check_app_deps()
  app_env <- create_graph_viewer_env()
  app <- app_env$create_graph_viewer_app(conn,
                                         page_size = page_size,
                                         load_step = load_step)
  shiny::runApp(app, host = host, port = port,
                launch.browser = launch_browser, ...)
  invisible(app)
}

#' @rdname graph_viewer
#' @keywords internal
check_app_deps <- function() {
  missing <- .app_dep_packages[!sapply(
    .app_dep_packages, requireNamespace, quietly = TRUE
  )]
  if (length(missing)) {
    stop(
      "graph_viewer() requires the missing suggested packages: ",
      paste(missing, collapse = ", "), ".\n",
      "Install them with: install.packages(c(",
      paste(dQuote(missing), collapse = ", "), "))",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

#' @keywords internal
create_graph_viewer_env <- function() {
  env <- new.env(parent = asNamespace("lbugr"))
  app_dir <- system.file("graph_viewer", package = "lbugr")
  if (dir.exists(app_dir) == FALSE) {
    stop("The graph viewer app files are missing (inst/graph_viewer).",
         call. = FALSE)
  }
  sys.source(file.path(app_dir, "view", "graph_module.R"), envir = env)
  sys.source(file.path(app_dir, "app.R"), envir = env)
  env
}
