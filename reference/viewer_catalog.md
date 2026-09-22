# Call a private ladybug catalog helper with a clear failure message.

Call a private ladybug catalog helper with a clear failure message.

## Usage

``` r
viewer_catalog(conn, fn, ...)
```

## Arguments

- conn:

  A Ladybug connection object, as returned by
  [`lb_connection()`](https://wickm.github.io/lbugr/reference/lb_connection.md).

- fn:

  The name of a private catalog method on the connection.

- ...:

  Arguments passed to the catalog method.

## Value

The R-converted return value of the catalog method.
