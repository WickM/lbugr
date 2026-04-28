# Check for Ladybug Python Dependencies

This function checks if the required Python package (`ladybug`) is
available in the user's `reticulate` environment. If the package is
missing, it provides a clear, actionable message guiding the user on how
to install it manually.

## Usage

``` r
check_ladybug_installation(quiet = FALSE)
```

## Arguments

- quiet:

  If TRUE, suppress the success message. Default is FALSE.

## Value

`NULL` invisibly. The function is called for its side effect of checking
dependencies and printing messages.

## Examples

``` r
# \donttest{
check_ladybug_installation()
#> Error: The 'ladybug' Python package is not installed.
#> To install it, please run the following command in your R console:
#> reticulate::py_install('ladybug', pip = TRUE)
# }
```
