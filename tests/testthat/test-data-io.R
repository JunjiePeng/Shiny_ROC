test_that("coerce_binary_group maps character levels to 0/1", {
  out <- coerce_binary_group(c("case", "control", "case", "control"))
  expect_setequal(unique(out), c(0, 1))
  expect_equal(out[1], 0)
})

test_that("coerce_binary_group maps numeric to smallest=0, largest=1", {
  expect_equal(coerce_binary_group(c(2, 5, 5, 2)), c(0, 1, 1, 0))
})

test_that("coerce_binary_group preserves NA", {
  out <- coerce_binary_group(c(1, NA, 2))
  expect_true(is.na(out[2]))
})

test_that("coerce_binary_group errors when not exactly two levels", {
  expect_error(coerce_binary_group(c(1, 2, 3)), "exactly 2")
  expect_error(coerce_binary_group(factor(c("a", "b", "c"))), "exactly 2")
})

test_that("read_data round-trips a CSV", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  utils::write.csv(data.frame(a = 1:3, b = 4:6), tmp, row.names = FALSE)
  df <- read_data(tmp, ext = "csv")
  expect_equal(nrow(df), 3)
  expect_true(all(c("a", "b") %in% names(df)))
})

test_that("read_data rejects unsupported extensions", {
  expect_error(read_data("x.foo", ext = "foo"), "Unsupported file type")
})
