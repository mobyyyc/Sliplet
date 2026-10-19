# P7-01A reproduction and boundaries

All commands are local. Do not print private requests, OCR, parser JSON or reference files. Use a new private run directory and a newly created dedicated Simulator. Never reset the user's normal Simulator or phone. These instructions reproduce the tested configuration; they do not authorize further work.

## Public build setup

Paddle source: `dab3fe35379033fdcb2d0e9572fac0b36c9a9ebf` in `/tmp/sliplet-p701-paddle`. OpenCV tag 4.3.0 resolves to `01b2c5a77ca6dbef3baef24ebc0a5984579231d9` in `/tmp/sliplet-p701a-opencv`. CocoaPods 1.17.0 resolves the locked ONNX Runtime 1.24.3, OpenCV 4.3.0 and Yams 5.0.6 dependencies; only the lockfile tool-version metadata differs from upstream. Fetch preset **PP-OCRv5_mobile**, verify complete archives before extraction, and compare resulting model hashes with `docs/evidence/p7-01a/public-dependencies.json`. Both bundled model README files declare Apache-2.0. Retain repository, Clipper and dependency license notices.

Configure OpenCV with CMake/Ninja using:

```
-DCMAKE_POLICY_VERSION_MINIMUM=3.5
-DCMAKE_SYSTEM_NAME=iOS
-DCMAKE_OSX_SYSROOT=iphonesimulator
-DCMAKE_OSX_ARCHITECTURES=arm64
-DCMAKE_OSX_DEPLOYMENT_TARGET=16.0
-DCMAKE_BUILD_TYPE=Release
-DBUILD_LIST=core,imgproc
-DBUILD_opencv_world=OFF
-DBUILD_SHARED_LIBS=OFF
-DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_EXAMPLES=OFF
-DBUILD_opencv_apps=OFF -DBUILD_JAVA=OFF
-DBUILD_opencv_python2=OFF -DBUILD_opencv_python3=OFF
-DWITH_IPP=OFF -DWITH_OPENCL=OFF -DWITH_ITT=OFF
-DBUILD_ZLIB=OFF -DBUILD_JPEG=OFF -DBUILD_PNG=OFF
-DBUILD_TIFF=OFF -DBUILD_WEBP=OFF -DBUILD_OPENEXR=OFF
-DWITH_JPEG=OFF -DWITH_PNG=OFF -DWITH_TIFF=OFF
-DWITH_WEBP=OFF -DWITH_OPENEXR=OFF
```

Set ZLIB_LIBRARY to the installed iPhoneSimulator27.1 SDK's `usr/lib/libz.tbd` and ZLIB_INCLUDE_DIR to its `usr/include`. Build with six jobs and install under `/tmp/sliplet-p701a-opencv-install`. Combine installed `libopencv_core.a` and `libopencv_imgproc.a` using `xcrun libtool -static`. Preserve the old sample framework binary separately, then replace only `Pods/OpenCV/opencv2.framework/Versions/A/opencv2` with the combined archive. Generated CocoaPods xcconfig files must remove `EXCLUDED_ARCHS[sdk=iphonesimulator*] = arm64`; source code remains untouched.

Append the checked-in `evaluation/receipt-independent-ocr/ProbeTests.swift` to the sample's existing `ORTSessionManagerTests.swift` (after its original contents) so the upstream test target compiles it. Use the sample workspace/scheme, Release configuration, and these build overrides:

```
CODE_SIGNING_ALLOWED=NO IPHONEOS_DEPLOYMENT_TARGET=17.0
ARCHS=arm64 EXCLUDED_ARCHS= ONLY_ACTIVE_ARCH=YES
OTHER_LDFLAGS=$(inherited) -lz
```

Pass the final line as a single quoted build-setting argument. Set DEVELOPER_DIR to `/Applications/Xcode.app/Contents/Developer`. The tested derived-data directory is `/tmp/sliplet-p701a-build`.

Run only `SlipletIndependentOCRTests/testFictionalOfflineRecognitionAndMapping` and `testEXIFOrientationNormalization` first, with parallel testing disabled. Confirm actual executed test counts in xcresult, not merely successful compilation. The private method skips unless its explicit environment flag is present.

## Unchanged parser and private evaluation

Compile `ParseWorker.swift` with current production `Receipt.swift`, `ReceiptReview.swift`, `ReceiptSplit.swift`, `Parsing.swift` and `ReceiptMerchantDirectory.swift` using the Xcode Swift compiler, macOS SDK, `-parse-as-library -target arm64-apple-macos27.0`, output `/tmp/sliplet-p701a-parse`. The evaluation-only OCRResult container satisfies an unused extraction function; actual parsing code is unchanged. The worker accepts retained observations on stdin and returns private JSON. Redirect/capture it; never invoke on real receipt data with terminal-visible output.

1. Create a dedicated iPhone 15 Pro / iOS 27.0 Simulator named `Sliplet P7-01A OCR Lab`. Install/test the fictional host, then ensure that device is booted before staging.
2. Run `evaluation/receipt-independent-ocr/run.py prepare --run PRIVATE_NEW_RUN --device ID` from the Sliplet checkout. It validates the device name, stages the original files locally, freezes source/model/reference hashes and generates `SlipletP701Private.xctestrun` inside the build-products directory. Keep it there so `__TESTROOT__` resolves correctly. Expected amounts and checked references are not staged into the app.
3. Run `xcodebuild test-without-building` against that xctestrun, the dedicated device and only `SlipletIndependentOCRTests/testPrivateComparison`, parallel testing disabled. Put logs and xcresult inside the private run directory.
4. Run `collect --run RUN`, then `verify --run RUN`. The collector preserves raw observations and separately applies the existing production boundary-normalization rule to parser input. Numeric text is never changed. Inspect only selected aggregate counts publicly.
5. The completed run is `private-receipts/evaluation/p7-01a-final-v2`. Its collector amendment, earlier manifest and pre-amendment script are retained there; verification uses the explicit amended hash. The earlier incomplete staging directory contains no evaluated comparison.
6. Retain private evidence, then delete only the task-created Simulator after checking its exact name/ID. Do not modify installed production data. Public build sources may remain in temporary storage; they are not guaranteed permanent.

## Interpretation

This is a full-image engine comparison plus independent strip diagnostics, not fused production recovery. CPU/runtime/model settings remain fixed. Two repeated runs are correlated; five exposed purchases cannot establish general accuracy. Sampled RSS includes both engines and image processing. A successful test means the harness executed, not that recognition improved. The failed promotion gate is the relevant outcome.
