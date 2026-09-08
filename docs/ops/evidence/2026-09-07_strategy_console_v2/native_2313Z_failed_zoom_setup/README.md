# Retained failed QA initialization

QA binary db0044f6192c0b0256a328c26b575cf08d67fe3dd7292e229297fab8caded03a,
init token 41774365623703_1788829958_2096177421, local 2026-09-08 01:12:38.
Native geometry and property-roundtrip suites passed. Zoom suite failed with
`zoom_fixture_changed_raster_unstable`; no cleanup-incomplete suffix was recorded.
Compare suites were not run because initialization correctly stopped at this failure.

This is not a PASS bundle. qa_701 in the terminal directory belonged to the prior
init token and cannot be used as proof of this build. Its stale existence was
detected through init-bound receipt checks. The production EURUSD EA stayed on
the previously installed b91f81a2 build; the 4ff02978 candidate was not installed.

Investigation focuses on synchronizing the disposable chart's native zoom test
setup before making assertions. Production restoration thresholds must not be
weakened to make the fixture pass. Preserve these failed receipts alongside the
subsequent corrected-test results.
