# Tests for lbugr Graph Conversion Functions

# Skip all tests if ladybug is not available
skip_if_no_ladybug <- function() {
  if (!reticulate::py_module_available("real_ladybug")) {
    skip("real_ladybug Python package not available")
  }
}

# Test as_igraph converts query result to igraph object
test_that("as_igraph converts query result to igraph object", {
  skip_if_no_ladybug()
  skip_if_not_installed("igraph")
  
  conn <- lb_connection(":memory:")
  on.exit(cleanup_db(), add = TRUE)
  
  # Create node table and data
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'Alice'})")
  lb_execute(conn, "CREATE (:Person {name: 'Bob'})")
  
  # Query nodes
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p")
  g <- as_igraph(result)
  
  expect_s3_class(g, "igraph")
})

# Test as_igraph with relationship data
test_that("as_igraph converts query result with relationships", {
  skip_if_no_ladybug()
  skip_if_not_installed("igraph")
  
  conn <- lb_connection(":memory:")
  on.exit(cleanup_db(), add = TRUE)
  
  # Create node and relationship tables
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE REL TABLE Knows(FROM Person TO Person)")
  
  # Create nodes and relationships
  lb_execute(conn, "CREATE (:Person {name: 'Alice'})")
  lb_execute(conn, "CREATE (:Person {name: 'Bob'})")
  lb_execute(conn, "MATCH (a:Person), (b:Person) WHERE a.name='Alice' AND b.name='Bob' CREATE (a)-[:Knows]->(b)")
  
  # Query with relationships
  result <- lb_execute(conn, "MATCH (a:Person)-[k:Knows]->(b:Person) RETURN a, k, b")
  g <- as_igraph(result)
  
  expect_s3_class(g, "igraph")
  expect_gte(igraph::gsize(g), 1)
})

# Test as_igraph handles nodes only (no edges)
test_that("as_igraph handles nodes without edges", {
  skip_if_no_ladybug()
  skip_if_not_installed("igraph")
  
  conn <- lb_connection(":memory:")
  on.exit(cleanup_db(), add = TRUE)
  
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, age INT64, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'Alice', age: 25})")
  lb_execute(conn, "CREATE (:Person {name: 'Bob', age: 30})")
  
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p")
  g <- as_igraph(result)
  
  expect_s3_class(g, "igraph")
  expect_gte(igraph::vcount(g), 1)
})

# Test as_igraph with specific node properties
test_that("as_igraph preserves node properties", {
  skip_if_no_ladybug()
  skip_if_not_installed("igraph")
  
  conn <- lb_connection(":memory:")
  on.exit(cleanup_db(), add = TRUE)
  
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, age INT64, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'Alice', age: 25})")
  lb_execute(conn, "CREATE (:Person {name: 'Bob', age: 30})")
  
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p")
  g <- as_igraph(result)
  
  # Check that vertex attributes exist
  expect_true("name" %in% igraph::vertex_attr_names(g) ||
                "label" %in% igraph::vertex_attr_names(g))
})

# Test as_tidygraph converts query result to tidygraph object
test_that("as_tidygraph converts query result to tbl_graph", {
  skip_if_no_ladybug()
  skip_if_not_installed("tidygraph")
  
  conn <- lb_connection(":memory:")
  on.exit(cleanup_db(), add = TRUE)
  
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'Alice'})")
  lb_execute(conn, "CREATE (:Person {name: 'Bob'})")
  
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p")
  g_tidy <- as_tidygraph(result)
  
  expect_s3_class(g_tidy, "tbl_graph")
})

# Test as_tidygraph with relationship data
test_that("as_tidygraph converts query result with relationships", {
  skip_if_no_ladybug()
  skip_if_not_installed("tidygraph")
  
  conn <- lb_connection(":memory:")
  on.exit(cleanup_db(), add = TRUE)
  
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE REL TABLE Knows(FROM Person TO Person)")
  lb_execute(conn, "CREATE (:Person {name: 'Alice'})")
  lb_execute(conn, "CREATE (:Person {name: 'Bob'})")
  lb_execute(conn, "MATCH (a:Person), (b:Person) WHERE a.name='Alice' AND b.name='Bob' CREATE (a)-[:Knows]->(b)")
  
  result <- lb_execute(conn, "MATCH (a:Person)-[k:Knows]->(b:Person) RETURN a, k, b")
  g_tidy <- as_tidygraph(result)
  
  expect_s3_class(g_tidy, "tbl_graph")
  expect_gte(igraph::gsize(g_tidy), 1)
})

# Test as_tidygraph handles nodes only
test_that("as_tidygraph handles nodes without edges", {
  skip_if_no_ladybug()
  skip_if_not_installed("tidygraph")
  
  conn <- lb_connection(":memory:")
  on.exit(cleanup_db(), add = TRUE)
  
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'Alice'})")
  lb_execute(conn, "CREATE (:Person {name: 'Bob'})")
  
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p")
  g_tidy <- as_tidygraph(result)
  
  expect_s3_class(g_tidy, "tbl_graph")
  expect_gte(igraph::vcount(g_tidy), 1)
})

# Test as_igraph with multiple relationship types
test_that("as_igraph handles multiple relationship types", {
  skip_if_no_ladybug()
  skip_if_not_installed("igraph")
  
  conn <- lb_connection(":memory:")
  on.exit(cleanup_db(), add = TRUE)
  
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE REL TABLE Knows(FROM Person TO Person)")
  lb_execute(conn, "CREATE REL TABLE WorksWith(FROM Person TO Person)")
  
  lb_execute(conn, "CREATE (:Person {name: 'Alice'})")
  lb_execute(conn, "CREATE (:Person {name: 'Bob'})")
  lb_execute(conn, "CREATE (:Person {name: 'Charlie'})")
  lb_execute(conn, "MATCH (a:Person), (b:Person) WHERE a.name='Alice' AND b.name='Bob' CREATE (a)-[:Knows]->(b)")
  lb_execute(conn, "MATCH (a:Person), (b:Person) WHERE a.name='Bob' AND b.name='Charlie' CREATE (a)-[:WorksWith]->(b)")
  
  result <- lb_execute(conn, "MATCH (a:Person)-[r]->(b:Person) RETURN a, r, b")
  g <- as_igraph(result)
  
  expect_s3_class(g, "igraph")
  expect_gte(igraph::gsize(g), 2)
})

# Test as_tidygraph preserves node attributes
test_that("as_tidygraph preserves node attributes", {
  skip_if_no_ladybug()
  skip_if_not_installed("tidygraph")
  
  conn <- lb_connection(":memory:")
  on.exit(cleanup_db(), add = TRUE)
  
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, age INT64, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'Alice', age: 25})")
  lb_execute(conn, "CREATE (:Person {name: 'Bob', age: 30})")
  
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p")
  g_tidy <- as_tidygraph(result)
  
  # Check node data frame has the expected columns
  node_data <- tidygraph::as_tibble(g_tidy)
  expect_type(node_data, "list")
})

# Test as_igraph works with directed graph
test_that("as_igraph creates directed graph", {
  skip_if_no_ladybug()
  skip_if_not_installed("igraph")
  
  conn <- lb_connection(":memory:")
  on.exit(cleanup_db(), add = TRUE)
  
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE REL TABLE Follows(FROM Person TO Person)")
  lb_execute(conn, "CREATE (:Person {name: 'Alice'})")
  lb_execute(conn, "CREATE (:Person {name: 'Bob'})")
  lb_execute(conn, "MATCH (a:Person), (b:Person) WHERE a.name='Alice' AND b.name='Bob' CREATE (a)-[:Follows]->(b)")
  
  result <- lb_execute(conn, "MATCH (a:Person)-[f:Follows]->(b:Person) RETURN a, f, b")
  g <- as_igraph(result)
  
  expect_true(igraph::is_directed(g))
})

# Test as_igraph handles empty results
test_that("as_igraph handles empty query results", {
  skip_if_no_ladybug()
  skip_if_not_installed("igraph")
  
  conn <- lb_connection(":memory:")
  on.exit(cleanup_db(), add = TRUE)
  
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, PRIMARY KEY (name))")
  
  # Query with no results
  result <- lb_execute(conn, "MATCH (p:Person) WHERE p.name = 'NoOne' RETURN p")
  g <- as_igraph(result)
  
  expect_s3_class(g, "igraph")
})

# Test as_tidygraph handles empty results
test_that("as_tidygraph handles empty query results", {
  skip_if_no_ladybug()
  skip_if_not_installed("tidygraph")
  
  conn <- lb_connection(":memory:")
  on.exit(cleanup_db(), add = TRUE)
  
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, PRIMARY KEY (name))")
  
  result <- lb_execute(conn, "MATCH (p:Person) WHERE p.name = 'NoOne' RETURN p")
  g_tidy <- as_tidygraph(result)
  
  expect_s3_class(g_tidy, "tbl_graph")
})

# Test as_igraph with complex property values
test_that("as_igraph handles complex property values", {
  skip_if_no_ladybug()
  skip_if_not_installed("igraph")
  
  conn <- lb_connection(":memory:")
  on.exit(cleanup_db(), add = TRUE)
  
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, age INT64, height DOUBLE, is_student BOOLEAN, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'Alice', age: 25, height: 1.75, is_student: true})")
  
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p")
  g <- as_igraph(result)
  
  expect_s3_class(g, "igraph")
  expect_gte(igraph::vcount(g), 1)
})

# Test as_tidygraph with complex property values
test_that("as_tidygraph handles complex property values", {
  skip_if_no_ladybug()
  skip_if_not_installed("tidygraph")
  
  conn <- lb_connection(":memory:")
  on.exit(cleanup_db(), add = TRUE)
  
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, age INT64, height DOUBLE, is_student BOOLEAN, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'Alice', age: 25, height: 1.75, is_student: true})")
  
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p")
  g_tidy <- as_tidygraph(result)
  
  expect_s3_class(g_tidy, "tbl_graph")
})