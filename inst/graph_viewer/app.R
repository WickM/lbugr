# Shiny app factory for the local graph viewer.
#
# This file is loaded with sys.source() into an isolated environment whose
# parent is lbugr's namespace (see create_graph_viewer_env()), together with
# view/graph_module.R, so the module and lbugr's internal viewer_* functions
# share one scope without ':::'.
#
# create_graph_viewer_app() returns a shiny.appobj without launching it.
# graph_viewer() (R/graph_viewer.R) validates the connection and the app
# dependencies, sources this environment, and runs the app.

# Page assembly: bslib layout + module UI + inlined stylesheet. Kept as its
# own function so the UI tree is constructible without a live app (smoke
# tests) and the shinyApp() ui closure stays trivial.
graph_viewer_page <- function(title, head_tags) {
  bslib::page_fluid(
    title = title,
    shiny::tags$head(head_tags),
    graph_module_ui("graph_module")
  )
}

create_graph_viewer_app <- function(conn, page_size = 300L, load_step = 300L,
                                    title = "LadybugDB Graph Viewer") {
  # Inline the (tiny) stylesheet via system.file instead of <link href>:
  # a shinyApp object has no stable document root when run through
  # shiny::runApp(app), so static file serving would depend on the user's
  # working directory.
  css_file <- system.file("graph_viewer/app.min.css", package = "lbugr")
  head_tags <- if (file.exists(css_file)) {
    shiny::tags$style(shiny::HTML(
      paste(readLines(css_file, warn = FALSE), collapse = "\n")
    ))
  } else {
    NULL
  }
  shiny::shinyApp(
    ui = function(request) {
      graph_viewer_page(title, head_tags)
    },
    server = function(input, output, session) {
      graph_module_server("graph_module", conn, page_size, load_step)
    }
  )
}
