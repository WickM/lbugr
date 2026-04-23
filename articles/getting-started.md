# Getting Started with lbugr

## Introduction

Welcome to `lbugr`! This guide will walk you through the basic steps to
get started with `lbugr`, from installation to running your first query.
`lbugr` is the R interface to the Ladybug Graph Database, a fork of the
Kuzu graph database.

## Installation

First, ensure you have the `lbugr` package installed. You will also need
`reticulate` to manage the Python environment.

\#ToDo Wrong pytho paket real ladybug is the one we use

``` r
# Install lbugr from GitHub
remotes::install_github("your-github-repo/lbugr")


# Install the ladybug Python package
reticulate::py_install("ladybug", pip = TRUE)
```

## Basic Usage

### 1. Create a Connection

The first step is to create a connection to a Ladybug database. You can
create an in-memory database or connect to a database on disk.

``` r
library(lbugr)

# Create an in-memory database connection
con <- lb_connection(":memory:")
```

### 2. Create a Schema

Next, define your graph schema using Cypher queries. Let’s create a
simple schema with `Person` nodes and `Knows` relationships.

``` r
lb_execute(con, paste("CREATE NODE TABLE Person(name STRING, age INT64,",
                        "PRIMARY KEY (name))"))
lb_execute(con, "CREATE REL TABLE Knows(FROM Person TO Person, since INT64)")
```

### 3. Load Data

You can load data from R data frames directly into your Ladybug
database.

``` r
# Create a data frame of persons
persons_df <- data.frame(
  name = c("Alice", "Bob", "Carol"),
  age = c(35, 45, 25)
)

# Create a data frame of relationships
knows_df <- data.frame(
  from_person = c("Alice", "Bob"),
  to_person = c("Bob", "Carol"),
  since = c(2010, 2015)
)

# Load data into Ladybug
lb_copy_from_df(con, persons_df, "Person")
lb_copy_from_df(con, knows_df, "Knows")
```

### 4. Query Data

Finally, you can query your graph using Cypher and retrieve the results
as an R data frame.

``` r
# Execute a query
result <- lb_execute(con, paste("MATCH (a:Person)-[k:Knows]->(b:Person)",
                                  "RETURN a.name, b.name, k.since"))

# Convert the result to a data frame
df <- as.data.frame(result)
print(df)
```

This concludes the “Getting Started” guide. For more advanced topics,
please see the other articles and the function reference.
