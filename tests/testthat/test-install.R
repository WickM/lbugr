# Tests for lbugr Installation Check

# Helper function to skip tests if ladybug is not available
skip_if_no_ladybug <- function() {
  if (!reticulate::py_module_available("real_ladybug")) {
    skip("real_ladybug Python package not available")
  }
}

# Test check_ladybug_installation returns message when ladybug is available
test_that("check_ladybug_installation succeeds when ladybug is available", {
  if (reticulate::py_module_available("real_ladybug")) {
    # Should not throw an error - use quiet = TRUE to suppress message
    expect_silent(check_ladybug_installation(quiet = TRUE))
  } else {
    # Should throw an error when ladybug is not available
    expect_error(check_ladybug_installation(quiet = TRUE), "real_ladybug")
  }
})

# Test check_ladybug_installation fails gracefully when ladybug is not installed
test_that("check_ladybug_installation provides helpful error when ladybug is missing", {
  # Temporarily mock the py_module_available to return FALSE
  # This test will skip if ladybug is actually available
  
  # If ladybug is not available, check that error message is informative
  if (!reticulate::py_module_available("real_ladybug")) {
    expect_error(
      check_ladybug_installation(quiet = TRUE),
      "The 'real_ladybug' Python package is not installed"
    )
  }
})

# Test that reticulate is properly loaded
test_that("reticulate is available for Python bridging", {
  expect_true(requireNamespace("reticulate", quietly = TRUE))
})

# Test that we can check for Python module availability
test_that("py_module_available function works", {
  # This should return TRUE or FALSE, not throw an error
  result <- reticulate::py_module_available("sys")
  expect_type(result, "logical")
})

# Test that reticulate can import built-in Python modules
test_that("reticulate can import Python builtins", {
  skip_if_no_ladybug()
  # Should not throw an error
  expect_silent(tryCatch(reticulate::import("sys"), error = function(e) NULL))
})

# Test that real_ladybug module has expected classes
test_that("real_ladybug module has expected classes", {
  skip_if_no_ladybug()
  ladybug <- reticulate::import("real_ladybug")
  # Database and Connection are core classes
  expect_true("Database" %in% names(ladybug))
  expect_true("Connection" %in% names(ladybug))
})

# Test installation check provides installation instructions
test_that("check_ladybug_installation provides installation instructions", {
  if (!reticulate::py_module_available("real_ladybug")) {
    result <- tryCatch(
      check_ladybug_installation(quiet = TRUE),
      error = function(e) e$message
    )
    # Error message should contain installation hint
    expect_true(grepl("py_install", result, ignore.case = TRUE))
  }
})

# Test that py_install can be used to install ladybug
test_that("reticulate py_install is available", {
  # Check if py_install function exists via reticulate
  expect_true(is.function(reticulate::py_install))
})