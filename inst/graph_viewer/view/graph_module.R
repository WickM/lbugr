# Graph explorer module: g6R visualization + reactable table.
#
# Ported 1:1 from the metadata-mesh-viewer (verified behavior preserved:
# g6R re-render pattern, canvas leak guard, table click bridge, pagination).
# Differences: no HTTP backend -- schema and queries run on a local LadybugDB
# connection via lbugr internals; the pagination window is an argument.
#
# This file is loaded with sys.source() into an isolated environment whose
# parent is lbugr's namespace (see create_graph_viewer_env()), so lbugr's
# internal viewer_* functions resolve without ':::'. The Suggests packages
# are not attached, so the functions they provide are bound explicitly below.

NS <- shiny::NS
HTML <- shiny::HTML
actionButton <- shiny::actionButton
checkboxInput <- shiny::checkboxInput
debounce <- shiny::debounce
div <- shiny::div
downloadHandler <- shiny::downloadHandler
downloadLink <- shiny::downloadLink
moduleServer <- shiny::moduleServer
numericInput <- shiny::numericInput
observeEvent <- shiny::observeEvent
p <- shiny::p
reactive <- shiny::reactive
reactiveVal <- shiny::reactiveVal
renderText <- shiny::renderText
renderUI <- shiny::renderUI
selectInput <- shiny::selectInput
tags <- shiny::tags
textAreaInput <- shiny::textAreaInput
textOutput <- shiny::textOutput
uiOutput <- shiny::uiOutput
updateActionButton <- shiny::updateActionButton
updateSelectInput <- shiny::updateSelectInput
updateTextInput <- shiny::updateTextInput
card <- bslib::card
card_body <- bslib::card_body
card_header <- bslib::card_header
layout_columns <- bslib::layout_columns
layout_sidebar <- bslib::layout_sidebar
value_box <- bslib::value_box
JS <- htmlwidgets::JS
click_select <- g6R::click_select
d3_force_layout <- g6R::d3_force_layout
g6 <- g6R::g6
g6_behaviors <- g6R::g6_behaviors
g6_edge <- g6R::g6_edge
g6_edges <- g6R::g6_edges
g6_layout <- g6R::g6_layout
g6_node <- g6R::g6_node
g6_nodes <- g6R::g6_nodes
g6_options <- g6R::g6_options
g6_output <- g6R::g6_output
renderG6 <- g6R::renderG6
reactable <- reactable::reactable
reactableOutput <- reactable::reactableOutput
renderReactable <- reactable::renderReactable

graph_module_ui <- function(id) {
  ns <- NS(id)
  # Leak guard for the g6R widget: its htmlwidgets binding (g6R/htmlwidgets/g6.js)
  # creates a fresh G6 graph -- and with it a fresh <canvas> -- on every server
  # data message, without destroying the previous one. Shiny keeps the widget
  # element across renderUI re-renders (same id, same HTML), so stale canvases
  # would accumulate inside #<ns>-g6graph.
  #
  # Keep the canvas that is actually being drawn to, NOT blindly the newest:
  # g6R fires a burst of fresh canvases on every render (measured ~8 in ~40 ms)
  # and the newest is not always the one the live graph renders into -- removing
  # the live canvas leaves a blank widget (verified via tmp/probe_fixes.js: the
  # canvas with all 1100+ fills was removed while a never-drawn canvas remained).
  # The live canvas is the one with the MOST fill/stroke activity. Pruning runs
  # on a short interval (SETTLE_MS) while a burst is in flight and removes the
  # stale burst canvases the moment the live canvas has clearly drawn a real
  # graph (>= MIN_DRAWN fills) -- not after a fixed 2000 ms debounce, which left
  # the stacked stale canvases visible for ~2.4 s (the "ghost graph").
  guard_js <- sprintf(
    "(function () {
      var wrap = document.getElementById('%s');
      if (!wrap) return;
      var SETTLE_MS = 100;    // quick-check cadence while a burst is in flight
      var MIN_DRAWN = 10;     // a real graph fires many fill/stroke; bg-only fills do not
      var FALLBACK_MS = 3000; // tiny graphs may never reach MIN_DRAWN; prune by max then
      var interval = null;
      var watchStart = 0;
      var stopWatch = function () {
        if (interval !== null) { clearInterval(interval); interval = null; }
      };
      // Robust live-canvas selection: the canvas with the MOST draw activity
      // (fill/stroke/fillText/...), tie -> newest. g6R fires a burst of fresh
      // canvases per render (measured ~8 in ~40 ms) and the real-data canvas is
      // not always the newest. The old 'last drawn + 100ms' heuristic pruned the
      // still-laying-out real-data canvas and kept a blank one -> blank widget
      // (verified: guard disabled => the 50-node canvas paints 4092 px on the
      // 2nd canvas; guard active => that canvas is removed, blank remains).
      var prune = function () {
        var box = wrap.querySelector('.g6');
        if (!box) { stopWatch(); return; }
        var cs = box.querySelectorAll('canvas');
        if (cs.length < 2) { stopWatch(); return; }
        var best = cs[0], bestC = cs[0]._gc || 0;
        for (var j = 1; j < cs.length; j++) {
          var c = cs[j]._gc || 0;
          if (c >= bestC) { bestC = c; best = cs[j]; }
        }
        // Wait until the live canvas has drawn a real graph; pruning earlier risks
        // removing the still-laying-out live canvas. After FALLBACK_MS (tiny
        // graphs may never reach MIN_DRAWN) prune on the current max anyway.
        if (bestC < MIN_DRAWN && Date.now() - watchStart < FALLBACK_MS) return;
        for (var k = 0; k < cs.length; k++) { if (cs[k] !== best) cs[k].remove(); }
        stopWatch();
      };
      var startWatch = function () {
        if (interval === null) {
          watchStart = Date.now();
          interval = setInterval(prune, SETTLE_MS);
        }
      };
      var markDrawn = function (ctx) {
        try {
          if (ctx && ctx.canvas) {
            ctx.canvas._gc = (ctx.canvas._gc || 0) + 1;
            startWatch();
          }
        } catch (e) {}
      };
      var proto = CanvasRenderingContext2D.prototype;
      var ms = ['fill', 'stroke', 'fillRect', 'fillText', 'strokeText'];
      for (var i = 0; i < ms.length; i++) {
        (function (m) {
          var orig = proto[m];
          if (typeof orig !== 'function') return;
          proto[m] = function () { markDrawn(this); return orig.apply(this, arguments); };
        })(ms[i]);
      }
      var mo = new MutationObserver(startWatch);
      mo.observe(wrap, { childList: true, subtree: true });
    })();",
    ns("graphwrap")
  )
  # Client-side PNG export (Phase 4): serialize the live g6 canvas (the leak
  # guard keeps exactly one canvas inside .g6) to a blob and trigger a browser
  # download. No R involvement. Plain click listener -- shiny 1.12.1's shiny.js
  # exposes no global Shiny.onInputChange (only the instance method), and this
  # handler needs no server round-trip anyway.
  png_js <- sprintf(
    paste0(
      "(function () {\n",
      "  var btn = document.getElementById('%s');\n",
      "  if (!btn) return;\n",
      "  btn.addEventListener('click', function () {\n",
      "    var wrap = document.getElementById('%s');\n",
      "    var box = wrap && wrap.querySelector('.g6');\n",
      "    var c = box && box.querySelector('canvas');\n",
      "    if (!c) return;\n",
      "    fetch(c.toDataURL('image/png')).then(function (r) { return r.blob(); })\n",
      "      .then(function (b) {\n",
      "        var a = document.createElement('a');\n",
      "        a.href = URL.createObjectURL(b);\n",
      "        a.download = 'graph.png';\n",
      "        document.body.appendChild(a);\n",
      "        a.click();\n",
      "        a.remove();\n",
      "      });\n",
      "  });\n",
      "})();\n"
    ),
    ns("export_png"),
    ns("graphwrap")
  )
  div(
    uiOutput(ns("error")),
    uiOutput(ns("status")),
    layout_sidebar(
      layout_columns(
        widths = c(6, 4),
        #height = "calc(75vh - 195px)",
        #max_height = "calc(75vh - 195px)",
        row_heights = "1fr",
        # Column 1: graph only (large, viewport-based height).
        # page_fluid has no fill context, so the graph card uses a viewport
        # height instead of a fill item; the canvas (100%) resolves against it.
        # If the split looks off, tune the calc() below.
        card(
          id = ns("graph_card"),
          full_screen = TRUE,
          height = "calc(75vh - 100px)",
          card_header(
            "Graph",
            div(
              class = "d-flex align-items-center gap-2",
              actionButton(
                ns("load_more"), "Load more",
                class = "btn btn-sm btn-outline-primary"
              ),
              textOutput(ns("load_info"),
                         container = function(...) div(class = "text-body-secondary small", ...))
            )
          ),
          card_body(
            uiOutput(ns("graphwrap"),
                     class = "d-flex flex-column flex-grow-1 w-100",
                     style = "min-height: 0"),
            class = "d-flex flex-column"
          )
        ),
        # Column 2: asset details on top (capped + internal scroll), table below.
        # Only node clicks fill the details card; edge clicks leave it untouched.
        div(
          style = paste0(
            "display: flex; flex-direction: column; gap: 16px; ",
            "height: calc(75vh - 195px); overflow: hidden;"
          ),
          card(
            style = "flex-shrink: 0;",
            max_height = "300px",
            card_header("Asset Details"),
            card_body(uiOutput(ns("asset_detail")), class = "overflow-auto")
          ),
          # Table card: grows to fill col-2 height, body scrolls internally.
          card(
            style = "flex-grow: 1; min-height: 0; display: flex; flex-direction: column;",
            card_header(
              "Table",
              div(
                class = "d-flex align-items-center gap-1 flex-wrap",
                tags$small(class = "text-body-secondary me-1", "Export:"),
                downloadLink(
                  ns("export_csv"), "CSV",
                  class = "btn btn-sm btn-outline-secondary", title = "Table as CSV"
                ),
                downloadLink(
                  ns("export_xlsx"), "Excel",
                  class = "btn btn-sm btn-outline-secondary", title = "Table as Excel"
                ),
                downloadLink(
                  ns("export_json"), "JSON",
                  class = "btn btn-sm btn-outline-secondary", title = "Raw data as JSON"
                ),
                actionButton(
                  ns("export_png"), "PNG",
                  class = "btn btn-sm btn-outline-secondary", title = "Graph as PNG"
                )
              )
            ),
            card_body(
              reactableOutput(ns("table")),
              class = "d-flex flex-column overflow-auto",
              min_height = 0
            )
          )
        )
      ),
      sidebar = div(
        tags$h4("Filters"),
        selectInput(ns("node_types"), "Node types", multiple = TRUE,
                    choices = character(0)),
        selectInput(ns("rel_types"), "Relationship types", multiple = TRUE,
                    choices = character(0)),
        numericInput(ns("hops"), "Hops (focus depth)", value = 2,
                     min = 1, max = 10, step = 1, width = "140px"),
        checkboxInput(ns("show_labels"), "Relationship labels", value = FALSE),
        actionButton(ns("reset"), "Reset selection",
                     class = "btn btn-sm btn-outline-secondary"),
        actionButton(ns("reset_initial"), "Back to initial graph",
                     class = "btn btn-sm btn-outline-primary"),
        textOutput(ns("ctx_info"),
                   container = function(...) div(class = "text-body-secondary", ...)),
        # Free Cypher query: input block lives in the sidebar. Graph-faehige
        # Results ersetzen Graph + Haupttabelle; nicht-graph-faehige ersetzen
        # die Tabelle und blenden den Graph aus.
        div(
          class = "mt-3",
          tags$h4("Free Cypher query"),
          p(
            class = "text-body-secondary",
            paste(
              "A graph-capable query (shape {type,id,label,source,target})",
              "replaces graph + table; the sidebar filters adapt.",
              "Otherwise: the result replaces the table and the graph is cleared.",
              "Write operations are blocked."
            )
          ),
          div(
            class = "row g-2",
            div(
              class = "col",
              textAreaInput(
                ns("query"), "Cypher",
                placeholder = "MATCH (n) RETURN count(n) AS total", height = "80px"
              )
            ),
            div(
              class = "col-auto d-flex align-items-end",
              actionButton(ns("query_run"), "Run", class = "btn btn-primary btn-sm")
            )
          ),
          uiOutput(ns("query_error"))
        )
      )
    ),
    tags$script(HTML(guard_js)),
    tags$script(HTML(png_js)),
    uiOutput(ns("conn_footer"))
  )
}

# Short label for a graph-load failure. Local app: there is only one failure
# class (the in-process LadybugDB connection or a query error), so no
# conn/http distinction as in the reference app.
load_error_label <- function(err) {
  if (is.null(err)) return("Not connected")
  "Load error"
}

graph_module_server <- function(id, conn, page_size = 300L, load_step = 300L) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Synchronous load on session start: schema -> graph query -> model.
    # Local connection (in-process, no HTTP): the lbugr internals resolve via
    # the parent namespace of the environment this file was sourced into.
    load_result <- tryCatch({
      schema_map <- parse_schema(viewer_fetch_schema(conn))
      qres <- viewer_run_query(conn, generate_graph_query(schema_map))
      list(
        model = rows_to_graph(qres$results, schema_map),
        rows = qres$results,
        schema_map = schema_map
      )
    }, error = function(e) list(error = e))

    loaded <- reactiveVal(FALSE)
    model <- reactiveVal(load_result$model)
    # Static initial graph (for "Back to initial graph"): the schema-driven model
    # + its raw rows, captured once at session start.
    initial_model <- load_result$model
    initial_rows <- load_result$rows
    schema_map <- load_result$schema_map
    # Mode: NULL = initial graph, string = the free query driving the graph.
    mode_flag <- reactiveVal(NULL)
    # Raw rows of the CURRENT model (drives the JSON export).
    raw_rows <- reactiveVal(load_result$rows)
    # Free-query state (declared here, before the outputs that read it, so
    # their reactive dependencies register correctly):
    #   query_df  = non-graph result rows shown in the main table (NULL when
    #               the graph view is active)
    #   query_err = backend/error message for the free query
    query_df <- reactiveVal(NULL)
    query_err <- reactiveVal(NULL)

    # Re-derive the sidebar filter choices from a graph model and select all
    # of them. Called on initial load, after a graph-driving free query, and
    # on "Back to initial graph" -- the filters always mirror the active model.
    apply_all_filters <- function(m) {
      if (is.null(m)) return(invisible(NULL))
      node_choices <- sort(unique(m$nodes$type))
      rel_choices <- sort(unique(m$edges$rel_type))
      updateSelectInput(session, "node_types",
                        choices = node_choices, selected = node_choices)
      updateSelectInput(session, "rel_types",
                        choices = rel_choices, selected = rel_choices)
    }

    if (is.null(load_result$error)) {
      apply_all_filters(load_result$model)
      loaded(TRUE)
      # Reactive status box: mirrors the active model + mode (initial vs.
      # custom query), not just the one-shot session-start load.
      output$status <- renderUI({
        if (!is.null(query_df())) {
          return(value_box(
            "Custom Query",
            paste0(nrow(query_df()), " rows | not graph-capable"),
            subtitle = "LadybugDB",
            type = "info"
          ))
        }
        m <- model()
        if (is.null(m)) {
          return(value_box(
            "Not connected", "-", subtitle = "LadybugDB", type = "danger"
          ))
        }
        value_box(
          if (is.null(mode_flag())) "Connected" else "Custom Query",
          paste0(nrow(m$nodes), " nodes | ", nrow(m$edges), " relationships"),
          subtitle = "LadybugDB",
          type = "success"
        )
      })
    } else {
      output$status <- renderUI(div(
        class = "alert alert-danger",
        load_error_label(load_result$error), ": ", load_result$error$message
      ))
    }

    # Connection footer: a persistent "connected to <where>" line at the
    # bottom of the module. Green when the session-start load succeeded,
    # muted when it failed (the red status alert above carries the error
    # detail). Session-static: the load is a one-shot, so no reactivity
    # beyond the initial render.
    output$conn_footer <- renderUI({
      if (is.null(load_result$error)) {
        div(
          class = "mt-3 pt-2 border-top small text-success",
          "Connected to ", tags$strong("local LadybugDB")
        )
      } else {
        div(
          class = "mt-3 pt-2 border-top small text-body-secondary",
          "Not connected to ", tags$strong("local LadybugDB")
        )
      }
    })

    # Node selection drives the N-hop context and the asset details card.
    # g6R nulls <widget>-selected_node on edge AND background clicks, so with
    # the default ignoreNULL = TRUE the handler fires ONLY on a real node
    # click (a non-null value) and is skipped on edge/background clicks -> the
    # selection is then PRESERVED. Only the sidebar buttons (reset /
    # reset_initial) clear the selection -- the intended, deliberate way back
    # to the full/initial graph.
    selection <- reactiveVal(NULL)
    observeEvent(input[["g6graph-selected_node"]], {
      v <- input[["g6graph-selected_node"]]
      if (!is.null(v) && length(v) > 0) {
        selection(as.character(v[[1]]))
      }
    })
    # Tabelle: ein Node-Zeilen-Click setzt dieselbe Auswahl wie ein Graph-Click
    # (Edge-Zeilen senden kein table_node_click, s. onRowClick in output$table).
    observeEvent(input$table_node_click, {
      selection(as.character(input$table_node_click))
    })
    observeEvent(input$reset, {
      selection(NULL)
      apply_all_filters(model())
      limit(page_size)
    })
    # "Back to initial graph": restore the schema-driven model captured at session
    # start (model + raw rows + filters + selection + limit + query text).
    observeEvent(input$reset_initial, {
      query_df(NULL)
      query_err(NULL)
      if (is.null(initial_model)) return(invisible(NULL))
      model(initial_model)
      raw_rows(initial_rows)
      apply_all_filters(initial_model)
      selection(NULL)
      limit(page_size)
      mode_flag(NULL)
      updateTextInput(session, "query", value = "")
    })

    # Filtered result set (nodes by type, edges by type AND endpoint
    # visibility). Table rows keep the node/edge row order of the model.
    visible_model <- reactive({
      if (!loaded()) return(NULL)
      m <- model()
      nt <- input$node_types
      rt <- input$rel_types
      keep_nodes <- m$nodes$type %in% nt
      nodes <- m$nodes[keep_nodes, , drop = FALSE]
      node_ids <- nodes$id
      keep_edges <- m$edges$rel_type %in% rt &
        m$edges$source %in% node_ids & m$edges$target %in% node_ids
      list(
        nodes = nodes,
        edges = m$edges[keep_edges, , drop = FALSE],
        # Nodes-only: Edge-Zeilen weg (Darstellung; Modell rows_to_graph bleibt voll).
        # kind-Anker, NICHT m$table[keep_nodes, ]: c(keep_nodes,keep_edges) ist der
        # vollstaendige log. Vektor -- nur keep_nodes wuerde recyclen + Edge-Zeilen fangen.
        table = m$table[m$table$kind == "node" & m$table$type %in% nt, , drop = FALSE]
      )
    })

    # Fokus-Tiefe (Sidebar-Input, >= 1). Treibt den N-Hop-Ego-Subgraph.
    hops_value <- reactive(max(1L, as.integer(input$hops)))

    # N-Hop-Ego-Subgraph um die Auswahl (NULL wenn keine Auswahl oder die
    # Auswahl durch den Typ-Filter ausgeschlossen). Rechnet auf dem VISIBLE
    # (gefilterten) Modell, daher respektiert der Fokus die aktiven Filter.
    focus_subgraph <- reactive({
      sel <- selection()
      vm <- visible_model()
      if (is.null(sel) || is.null(vm) || !sel %in% vm$nodes$id) return(NULL)
      ego_subgraph(sel, vm, hops = hops_value())
    })

    # ---- Pagination: Graph-Kappe (page_size Knoten) + "Load more" (+load_step) ----
    # Der volle ~21k-Graph blockiert antv-dagre im Main-Thread (leeres
    # Canvas). Deshalb rendert der Graph nur die ersten limit() Knoten der
    # aktiven Graph-Ansicht (Gesamt- ODER Fokus-Subgraph) + die Kanten, die
    # komplett darin liegen. Die Tabelle bleibt voll (visible_model),
    # "Mehr laden" waechst die Kappe um load_step. page_size + load_step
    # sind Argumente von create_graph_viewer_app().
    page_size <- as.integer(page_size)
    load_step <- as.integer(load_step)
    limit <- reactiveVal(page_size)

    # Neue Filter / neue Auswahl -> frischer Start bei page_size.
    observeEvent(input$node_types, limit(page_size), ignoreNULL = TRUE)
    observeEvent(input$rel_types, limit(page_size), ignoreNULL = TRUE)
    observeEvent(selection(), limit(page_size), ignoreNULL = FALSE)

    observeEvent(input$load_more, {
      fs <- focus_subgraph()
      if (!is.null(fs)) {
        n_total <- nrow(fs$nodes)
      } else {
        vm <- visible_model()
        n_total <- if (is.null(vm)) 0L else nrow(vm$nodes)
      }
      limit(min(limit() + load_step, max(n_total, page_size)))
    })

    # Komponentenumgebung (grosste zuerst) als Cache: haengt nur von
    # visible_model() ab, nicht von limit() -- "Mehr laden" muss den BFS
    # nicht neu rechnen. Pre-allocated queue statt c(q, nb) Growth.
    comp_order <- reactive({
      vm <- visible_model()
      if (is.null(vm) || nrow(vm$nodes) == 0L) return(NULL)
      n_all <- nrow(vm$nodes)
      if (nrow(vm$edges) == 0L) return(seq_len(n_all))
      e_src <- match(vm$edges$source, vm$nodes$id)
      e_tgt <- match(vm$edges$target, vm$nodes$id)
      nbr <- split(c(e_src, e_tgt), c(e_tgt, e_src))
      comp <- integer(n_all)
      lab <- 0L
      queue <- integer(n_all)
      for (s in seq_len(n_all)) {
        if (comp[s] != 0L) next
        lab <- lab + 1L
        head_idx <- 1L
        tail_idx <- 1L
        queue[1L] <- s
        comp[s] <- lab
        while (head_idx <= tail_idx) {
          u <- queue[head_idx]
          head_idx <- head_idx + 1L
          nb <- nbr[[as.character(u)]]
          if (!is.null(nb)) {
            nb <- nb[comp[nb] == 0L]
            if (length(nb) > 0L) {
              comp[nb] <- lab
              tail_idx <- tail_idx + length(nb)
              queue[(tail_idx - length(nb) + 1L):tail_idx] <- nb
            }
          }
        }
      }
      comp_rank <- order(order(-tabulate(comp)))
      order(comp_rank[comp], seq_len(n_all))
    })

    # Graph-Kappe: ganze Komponenten (grosste zuerst) einbeziehen, bis ~n
    # Knoten erreicht, Kanten nur wenn beide Endpunkte drin.
    # "Mehr laden" fuegt die naechst-groessten Komponenten hinzu.
    display_model <- reactive({
      vm <- visible_model()
      if (is.null(vm)) return(NULL)
      n_all <- nrow(vm$nodes)
      n <- min(limit(), n_all)
      nodes <- vm$nodes
      if (n < n_all) {
        ord <- comp_order()
        if (!is.null(ord) && length(ord) == n_all) {
          nodes <- vm$nodes[ord[seq_len(n)], , drop = FALSE]
        } else {
          nodes <- nodes[seq_len(n), , drop = FALSE]
        }
      }
      ids <- nodes$id
      edges <- vm$edges[vm$edges$source %in% ids & vm$edges$target %in% ids, , drop = FALSE]
      list(nodes = nodes, edges = edges, table = vm$table)
    })

    # Fokus-Kappe: der Ego-Subgraph liegt in BFS-Distanz-Ordnung (Zentrum
    # zuerst), also schneidet cap_graph() die naechsten Knoten ein -- das
    # gewaehlte Zentrum ist immer sichtbar. Limit-Reset via selection().
    display_focus_model <- reactive({
      fs <- focus_subgraph()
      if (is.null(fs)) return(NULL)
      cap_graph(fs, min(limit(), nrow(fs$nodes)))
    })

    # Graph-Ansicht: fokussierter (paginierter) N-Hop-Subgraph, sonst die
    # (paginierte) Gesamtansicht. graphwrap + renderG6 haengen BEIDE an den
    # DEBOUNCED graph_view_d() -> Lockstep bei jedem Daten-Change
    # (Canvas-Stacking-Fix bleibt gewahrt), aber schnelles Filter-Toggling
    # koalesziert zu EINEM g6R-Rebuild statt einem pro Toggle.
    graph_view <- reactive({
      fs <- focus_subgraph()
      if (!is.null(fs)) return(display_focus_model())
      display_model()
    })
    # Debounced graph data: shiny::debounce() gibt den Initialwert SOFORT aus
    # (Primer, kein Blank-Flash beim Laden) und debounced nur Folge-Changes
    # um graph_debounce_ms. Gedrosselt wird nur die teure g6R-Regeneration
    # (graphwrap + renderG6); load_info liest graph_view() unverzoegert.
    graph_debounce_ms <- 300L
    graph_view_d <- debounce(graph_view, graph_debounce_ms)

    # Button-Label/Status: "All loaded" + deaktiviert, wenn Kappe = alle.
    observeEvent(list(limit(), input$node_types, input$rel_types, query_df(), focus_subgraph()), {
      if (!is.null(query_df())) {
        updateActionButton(session, "load_more",
                           label = "Load more", disabled = TRUE)
        return(invisible(NULL))
      }
      fs <- focus_subgraph()
      if (!is.null(fs)) {
        done <- limit() >= nrow(fs$nodes)
        updateActionButton(session, "load_more",
                           label = if (done) "All loaded" else "Load more",
                           disabled = done)
        return(invisible(NULL))
      }
      vm <- visible_model()
      if (is.null(vm)) return(invisible(NULL))
      done <- limit() >= nrow(vm$nodes)
      updateActionButton(session, "load_more",
                         label = if (done) "All loaded" else "Load more",
                         disabled = done)
    })

    output$load_info <- renderText({
      if (!is.null(query_df())) return("")
      vm <- visible_model()
      gv <- graph_view()
      if (is.null(vm) || is.null(gv)) return("")
      rendered <- nrow(gv$nodes)
      # "verfuegbar" = nodes available in the current graph view. Focused ego
      # subgraph (BFS-ordered, capped) -> available = full ego size; non-focused
      # -> full visible set. In both cases rendered may be capped by the
      # pagination window.
      fs <- focus_subgraph()
      available <- if (!is.null(fs)) nrow(fs$nodes) else nrow(vm$nodes)
      fmt <- function(x) formatC(x, format = "d", big.mark = ".")
      sprintf("%s / %s nodes", fmt(rendered), fmt(available))
    })

    # graphwrap MUSS graph_view_d() abhaengen (nicht nur visible_model):
    # "Mehr laden" aendert nur limit() -> graph_view_d() aendert sich ->
    # renderG6 feuert neu, graphwrap wuerde NICHT neu rendern -> g6.js stackt
    # einen neuen Graph + 4 Canvas im selben Container. Mit graph_view_d()
    # als Dep ersetzt Shiny bei JEDEM (debounced) Daten-Change das Widget-DOM
    # (wie bei Filter) -> Canvas-Zahl konstant, deterministisch
    # (guard_js praegt Pixel).
    output$graphwrap <- renderUI({
      invisible(graph_view_d())
      invisible(input$show_labels)
      if (!is.null(query_df())) {
        return(div(
          class = "alert alert-info",
          "Not graph-capable query: graph hidden. The result is in the table."
        ))
      }
      vm <- visible_model()
      if (is.null(vm)) return(NULL)
      if (nrow(vm$nodes) == 0L) {
        msg <- if (nrow(model()$nodes) == 0L) {
          "Connected - but the graph is empty (0 nodes)."
        } else {
          "No nodes for the current filter selection."
        }
        return(div(class = "alert alert-info", msg))
      }
      # Canvas height 100%: the card body is a flex column (see card_body in the
      # UI) and the uiOutput container is flex-grow-1 + min-height:0, so the
      # percentage resolves to the card's available height. Fallback if this
      # env renders it 0px: revert to height = "560px".
      g6_output(ns("g6graph"), width = "100%", height = "100%")
    })

    output$g6graph <- renderG6({
      vm <- graph_view_d()
      if (is.null(vm) || nrow(vm$nodes) == 0L) {
        # g6R needs >=1 node (validate_elements: length(x) > 0) - ein
        # wirklich leerer Graph ist nicht konstruierbar. graphwrap blendet
        # das Canvas in diesem Zustand bereits aus + zeigt den Alert; dieser
        # Placeholder deckt nur den transienten Reactive-Flush ab, in dem
        # renderG6 laeuft, bevor graphwrap den Container entfernt.
        return(g6(nodes = g6_nodes(g6_node(id = "__empty__")), edges = list()))
      }
      g <- g6(
        nodes = to_g6_nodes(vm$nodes),
        edges = to_g6_edges(vm$edges, input$show_labels)
      )
      #g <- g6_layout(g, antv_dagre_layout(rankdir = "LR"))
      g <- g6_layout(g, d3_force_layout())
      g <- g6_options(g,
        #autoFit = auto_fit_config(type = "view", when = "always", direction = "both"),
        zoomRange = c(0.0001, 10),
        animation = FALSE,
        autoFit = "view",
        padding = 20,
        node = list(
          style = list(size = 4),
          palette = list(
            type = "group",
            field = "cluster"
          )
      ))
      g <- g6_behaviors(
        g,
        click_select(degree = 0, state = "selected"),
        "zoom-canvas",
        "drag-canvas",
        "drag-element",
        #"hover-activate",
        #fix_element_size()
        "optimize-viewport-transform"
      )
      g
    })

    output$table <- renderReactable({
      if (!is.null(query_df())) {
        return(reactable(query_df(), defaultPageSize = 10))
      }
      vm <- visible_model()
      if (is.null(vm)) {
        return(reactable(data.frame(
          Hinweis = paste0(load_error_label(load_result$error), ".")
        )))
      }
      # Highlight the selected node's row in yellow. `selection()` is set by
      # either a graph-node click or a table-node-row click, so either
      # highlights the matching row. reactable 0.4.5 applies an R rowStyle
      # function per 1-based row index at render time: return a named style
      # list to color that row, NULL to leave it default. Depends on
      # selection() so the highlight follows the focus (tradeoff: the table
      # re-renders on each focus click, resetting filter/pagination).
      sel_id <- selection()
      reactable(
        vm$table,
        defaultPageSize = 10,
        filterable = TRUE,
        rowStyle = function(index) {
          if (!is.null(sel_id) && identical(vm$table$id[[index]], sel_id)) {
            list(backgroundColor = "yellow")
          } else {
            NULL
          }
        },
        onClick = JS(sprintf(
          paste0(
            "function (a, b, c) {\n",
            "  var row = (a && a.row && a.row.kind !== undefined)",
            " ? a.row : (a && a.kind !== undefined) ? a : null;\n",
            "  if (row && row.kind === 'node' && row.id) {\n",
            "    var S = window.Shiny;\n",
            "    if (S && typeof S.setInputValue === 'function') S.setInputValue('%s', row.id);\n",
            "  }\n",
            "}"
          ), ns("table_node_click")
        ))
      )
    })

    # Free Cypher query: graph-capable results (uniform {type,id,label,source,
    # target}) replace the active graph + table and drive the sidebar filters;
    # anything else replaces the main table and clears the graph (query_df).
    # Blocked write keywords are rejected client-side by viewer_check_query()
    # (no backend here); viewer_run_query() surfaces its message. (query_df /
    # query_err are declared above with the other reactiveVals so the outputs
    # that read them register dependencies.)
    observeEvent(input$query_run, {
      q <- trimws(input$query)
      if (!nzchar(q)) {
        query_err("Query is empty.")
        return(invisible(NULL))
      }
      res <- tryCatch(viewer_run_query(conn, q), error = function(e) e)
      if (inherits(res, "error")) {
        query_df(NULL)
        query_err(res$message)
        return(invisible(NULL))
      }
      query_err(NULL)
      # Graph-faehig? -> ersetzt den aktiven Graph + Tabelle; die Sidebar-
      # Filter spiegeln das neue Modell. Sonst: nur die Ergebnistabelle.
      out <- try_rows_to_graph(res$results, schema_map)
      if (isTRUE(out$ok)) {
        query_df(NULL)
        model(out$model)
        raw_rows(res$results)
        apply_all_filters(out$model)
        selection(NULL)
        limit(page_size)
        mode_flag(q)
      } else {
        query_df(rows_to_df(res$results))
        raw_rows(res$results)
      }
    })
    output$query_error <- renderUI({
      msg <- query_err()
      if (is.null(msg)) {
        return(NULL)
      }
      div(class = "alert alert-danger", msg)
    })

    # Exports (Phase 4): CSV/Excel = current filtered table, JSON = raw rows
    # of the current model (schema-driven or free query), PNG = graph canvas.
    current_table_df <- reactive({
      if (!is.null(query_df())) {
        return(query_df())
      }
      vm <- visible_model()
      if (is.null(vm)) {
        return(data.frame(Hinweis = paste0(load_error_label(load_result$error), ".")))
      }
      vm$table
    })
    output$export_csv <- downloadHandler(
      filename = "tabelle.csv",
      # writeLines() opens the target in text mode, so on Windows every "\n"
      # becomes "\r\n" and breaks the LF contract of table_to_csv
      # (test-exports.R). Write the bytes explicitly in binary mode.
      content = function(path) {
        csv <- paste0(table_to_csv(current_table_df()), "\n", collapse = "")
        con <- file(path, open = "wb")
        on.exit(close(con))
        writeBin(charToRaw(csv), con)
      },
      contentType = "text/csv"
    )
    output$export_xlsx <- downloadHandler(
      filename = "tabelle.xlsx",
      content = function(file) df_to_xlsx(current_table_df(), file),
      contentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
    output$export_json <- downloadHandler(
      filename = "daten.json",
      content = function(file) {
        rows <- raw_rows()
        writeLines(rows_to_json(if (is.null(rows)) list() else rows), file)
      },
      contentType = "application/json"
    )

    output$ctx_info <- renderText({
      fs <- focus_subgraph()
      if (is.null(fs)) {
        return("No selection. Click a node for N-hop focus.")
      }
      sprintf("Focus: %s (%d nodes, %d hops)",
              selection(), nrow(fs$nodes), hops_value())
    })

    # Asset details (Phase 6): the selected node, resolved against the
    # visible table. A filtered-out node (or no selection) shows the
    # placeholder instead of stale data.
    output$asset_detail <- renderUI({
      vm <- visible_model()
      nid <- selection()
      row <- if (is.null(vm) || is.null(nid)) {
        NULL
      } else {
        vm$nodes[vm$nodes$id == nid, , drop = FALSE]
      }
      # nrow(NULL) is NULL (not 0): the placeholder branch must check is.null
      # first, or `if` fails with "argument is of length zero".
      if (is.null(row) || nrow(row) == 0L) {
        return(p(
          class = "text-body-secondary",
          "No asset selected. Click a node in the graph."
        ))
      }
      div(
        tags$p(class = "fw-semibold mb-1", "Name: ", row$label),
        tags$p("Type: ", row$type),
        tags$small(class = "text-body-secondary d-block mt-2", row$id)
      )
    })
  })
}

# ---- g6R builders -----------------------------------------------------------

node_label_font_size <- function(node_size = 56L) {
  as.numeric(pmax(9, pmin(12, 0.18 * node_size)))
}

to_g6_nodes <- function(nodes_df) {
  # g6R needs >=1 node (validate_elements: length(x) > 0) - ein leerer
  # Graph ist nicht konstruierbar; g6_nodes() (leer) wuerde hier crashen.
  if (nrow(nodes_df) == 0L) return(g6_nodes(g6_node(id = "__empty__")))
  node_size <- 56
  do.call(g6_nodes, lapply(seq_len(nrow(nodes_df)), function(i) {
    g6_node(
      id = nodes_df$id[i],
      data = list(label = nodes_df$label[i]),
      style = list(
        size = node_size,
        fill = nodes_df$color[i],
        labelText = nodes_df$label[i],
        labelFontSize = node_label_font_size(node_size),
        labelMaxWidth = node_size + 16,
        labelWordWrap = TRUE
      )
    )
  }))
}

# Edges data frame -> g6R `g6_edges`; `show_labels` toggles the `rel_type` edge label.
to_g6_edges <- function(edges_df, show_labels = FALSE) {
  if (nrow(edges_df) == 0L) return(list())
  do.call(g6_edges, lapply(seq_len(nrow(edges_df)), function(i) {
    g6_edge(
      source = edges_df$source[i],
      target = edges_df$target[i],
      id = edges_df$id[i],
      style = if (show_labels) list(
        labelText = edges_df$rel_type[i],
        labelFontSize = 9
      ) else list()
    )
  }))
}
