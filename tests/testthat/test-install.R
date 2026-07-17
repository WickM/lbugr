# Tests for lbugr Installation Check

# Test check_ladybug_installation emits deprecation warning
test_that("check_ladybug_installation emits deprecation warning", {
  expect_warning(
    check_ladybug_installation(quiet = TRUE),
    "deprecated"
  )
})

# Test check_ladybug_installation still works (backward compatibility)
test_that("check_ladybug_installation succeeds with deprecation warning", {
  expect_warning(
    check_ladybug_installation(quiet = FALSE),
    "deprecated"
  )
})

# Test that the Rust library is available
test_that("lbug_is_available returns TRUE", {
  expect_true(lbug_is_available())
})

# Test that Rust library can be loaded
test_that("Rust library is properly loaded", {
  expect_true(is.function(lbug_connect))
  expect_true(is.function(lbug_execute))
  expect_true(is.function(lbug_shutdown))
})
