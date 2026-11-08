# P11-03 evidence

November 8, 2026. Fictional iPhone 15 Pro Simulator, iOS 27.0. Screenshots show the settled crowded-wallet return and newest receipt detail. They do not establish animation frame continuity.

`simulator-round-trip-metrics.csv` is the native XCTest export for three measured rounds through a 30-receipt wallet. CPU time averages 0.436 seconds; automated round-trip clock time averages 1.781 seconds, including automation and idle waits. No prior baseline is configured: CSV baseline zero is not a measured earlier result. These are not physical-phone latency or frame/hitch measurements.

Animation Hitches reported: `Hitches is not supported on this platform.` Full local bundles: `/tmp/sliplet-p1103-baseline.xcresult` and `/tmp/sliplet-p1103-verified.xcresult`. Temporary bundles may be cleared; this directory retains safe summaries and fictional screenshots.
