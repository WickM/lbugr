# This file is part of the standard setup for testthat.
# It is recommended that you do not modify it.
#
# Where should you do additional test configuration?
# Learn more about the roles of various files in:
# * https://r-pkgs.org/testing-design.html#sec-tests-files-overview
# * https://testthat.r-lib.org/articles/special-files.html

library(testthat)
library(lbugr)

# Skip tests if RETICULATE_PYTHON is not set (e.g., on CRAN)
if (Sys.getenv("RETICULATE_PYTHON") == "") {
  skip("RETICULATE_PYTHON is not set. Skipping tests.")
}

test_check("lbugr")
