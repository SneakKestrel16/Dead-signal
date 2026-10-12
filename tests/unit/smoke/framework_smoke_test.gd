# Proves the gdUnit4 runner finds and runs suites under res://tests.
# Delete once the first real system test exists.
extends GdUnitTestSuite


func test_framework_runs_assertion_passes() -> void:
	assert_int(1 + 1).is_equal(2)
