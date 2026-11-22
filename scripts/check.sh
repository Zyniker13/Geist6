#!/bin/sh
# What CI runs. Run this before every push (AGENTS.md).
set -eu
cd "$(dirname "$0")/.."

# xcodebuild needs an explicit developer dir on some machines; keep any
# value the environment already provides (CI runners set their own).
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

echo "== inventory check (spec vs generated docs) =="
swift run inventory check

echo "== regenerate models; fail on drift =="
# Regen must reproduce the tree exactly as it stands: generate, hash the
# Generated trees, and require the same hashes as before the run. This
# catches stale and hand-edited generated code in CI while still passing
# when the tree intentionally carries a fresh uncommitted regeneration
# (a `git status` check would false-fail there).
GEN_TREE_HASH() {
    find Sources/StripeModels/Generated Sources/StripeClient/Generated -type f -print0 \
        | sort -z | xargs -0 shasum | shasum | cut -d ' ' -f 1
}
BEFORE_GEN_HASH=$(GEN_TREE_HASH)
swift run stripe-gen > /dev/null
AFTER_GEN_HASH=$(GEN_TREE_HASH)
if [ "$BEFORE_GEN_HASH" != "$AFTER_GEN_HASH" ]; then
    echo "ERROR: generated code is stale. Run 'swift run stripe-gen' and commit the result." >&2
    exit 1
fi

if command -v swiftlint >/dev/null 2>&1; then
    echo "== swiftlint =="
    swiftlint --quiet
else
    echo "swiftlint not installed; skipping (brew install swiftlint)"
fi

if command -v swift-format >/dev/null 2>&1; then
    echo "== swift-format =="
    swift-format lint --recursive --parallel Sources Tools Tests >/dev/null
else
    echo "swift-format not installed; skipping (brew install swift-format)"
fi

if ! command -v stripe-mock >/dev/null 2>&1; then
    echo "ERROR: stripe-mock not found. Install it (brew install stripe/stripe-mock/stripe-mock)" >&2
    exit 1
fi

echo "== package tests (swift test) =="
swift test

if xcodebuild -version >/dev/null 2>&1; then
    echo "== app tests (xcodegen + xcodebuild test: unit + UI) =="
    if ! command -v xcodegen >/dev/null 2>&1; then
        echo "xcodegen not installed; skipping app tests (brew install xcodegen)" >&2
        exit 1
    fi
    xcodegen generate

    # A stripe-mock left behind by an earlier crashed run still owns the
    # port and the new one dies with "bind: address already in use",
    # silently skipping every app test. Kill only stale stripe-mock
    # processes on that port — never anything else. Two traps live here:
    # a `while read` loop whose controlling read hits EOF ends with a
    # nonzero status even after a matching line, which would abort the
    # whole script under `set -e` when nothing listens on the port; and
    # `ps -o comm=` can report a full executable path, so compare the
    # basename.
    STALE_MOCK=$(lsof -t -nP -i :12111 -sTCP:LISTEN 2>/dev/null | while read -r pid; do
        if [ "$(basename "$(ps -p "$pid" -o comm= 2>/dev/null)")" = "stripe-mock" ]; then
            echo "$pid"
        fi
    done || true)
    if [ -n "$STALE_MOCK" ]; then
        echo "killing stale stripe-mock on :12111 (pid $STALE_MOCK)" >&2
        kill $STALE_MOCK 2>/dev/null || true
        sleep 1
    fi

    # The mock serves from an overlay spec (decision 0029): stripe-mock's
    # pinned upstream spec with the schema fields our pinned Stripe spec
    # requires that the mock's older bundled spec lacks (today: product.type),
    # plus its pinned fixtures. `swift run mock-overlay` fetches and verifies
    # the upstream files once per cache dir and prints the -spec and
    # -fixtures paths.
    OVERLAY_DIR="${TMPDIR:-/tmp}/geist6-mock-overlay-cache"
    OVERLAY_LINES=$(swift run --quiet mock-overlay "$OVERLAY_DIR" 2>/dev/null)
    OVERLAY_SPEC=$(printf '%s' "$OVERLAY_LINES" | sed -n '1p')
    OVERLAY_FIXTURES=$(printf '%s' "$OVERLAY_LINES" | sed -n '2p')
    if [ ! -f "$OVERLAY_SPEC" ] || [ ! -f "$OVERLAY_FIXTURES" ]; then
        echo "xcodebuild test: FAILED — mock-overlay produced no spec/fixtures" >&2
        exit 1
    fi
    stripe-mock --http-port 12111 --spec "$OVERLAY_SPEC" --fixtures "$OVERLAY_FIXTURES" &
    MOCK_PID=$!
    sleep 2
    if ! lsof -t -nP -i :12111 -sTCP:LISTEN >/dev/null 2>&1; then
        echo "xcodebuild test: FAILED — stripe-mock did not start on :12111" >&2
        exit 1
    fi

    # The app is iPad-only: pick whichever iPad simulator is actually
    # installed (names differ across Xcode versions), and fail with a clear
    # message when none exists instead of xcodebuild's exit 70. Locally a
    # GEIST6_SIM_NAME env var can pin a specific device; CI leaves it unset.
    if [ -n "${GEIST6_SIM_NAME:-}" ]; then
        SIM_NAME="$GEIST6_SIM_NAME"
    else
        # Shared machine (2026-11-18): prefer a device created for this
        # checkout (zGeist6_bot-*) so runs never land on another bot's
        # device; fall back to any iPad for CI, which creates none.
        SIMS=$(xcrun simctl list devices available 2>/dev/null | awk '
        /^-- iOS/ { have=1; next }
        /^--/ { if (have) exit; next }
        have && /iPad/ {
            line=$0
            sub(/^[ ]+/, "", line)
            sub(/ \([A-F0-9-]{36}\) .*/, "", line)
            print line
        }')
        SIM_NAME=$(printf "%s\n" "$SIMS" | grep "zGeist6_bot" | head -n 1)
        if [ -z "$SIM_NAME" ]; then
            SIM_NAME=$(printf "%s\n" "$SIMS" | head -n 1)
        fi
    fi
    if [ -z "$SIM_NAME" ]; then
        echo "xcodebuild test: FAILED — no iPad simulator installed (the app is iPad-only). Install an iPad-capable iOS runtime." >&2
        kill "$MOCK_PID" 2>/dev/null || true
        exit 1
    fi
    echo "app tests on simulator: $SIM_NAME"

    # The sim name contains spaces ("iPad Pro 13-inch (M5)"); an unquoted
    # redirect word-splits and xcodebuild never runs. One quoted path per run.
    TEST_LOG="/tmp/geist6-xcode-test-$$.txt"

    # Fresh derived data for every run: reusing a previous one can hang
    # the PruneExplicitPrecompiledModules phase. The path is unique per
    # run so two overlapping invocations can never clobber each other's
    # build products mid-test.
    # Reusing a prewarmed path (GEIST6_DD) must not wipe it; fresh paths
    # start clean so overlapping runs never clobber each other.
    DD="${GEIST6_DD:-/tmp/geist6-dd-$$}"
    if [ -z "${GEIST6_DD:-}" ]; then
        rm -rf "$DD"
    fi
    # -clonedSourcePackagesDirPath keeps package resolution inside DD so a
    # prewarmed path (built with build-for-testing) resolves identically.
    # On the shared dev machine every simulator run goes through sim-lock
    # (xcodebuild's test service is process-wide); CI has no such wrapper,
    # so the prefix stays empty there.
    LOCK=""
    if [ -x "$HOME/.hermes/bin/sim-lock" ]; then
        LOCK="$HOME/.hermes/bin/sim-lock"
    fi
    if [ -n "${GEIST6_DD:-}" ]; then
        # A stale prewarmed path must never silently skip suites added since
        # it was built, so refresh the build first. When the path is already
        # warm this is an incremental no-op build costing little; when it is
        # stale it pulls the runner up to date with the current sources.
        if ! $LOCK xcodebuild -project Geist6.xcodeproj -scheme Geist6 \
            -destination "platform=iOS Simulator,name=$SIM_NAME,OS=latest" \
            -derivedDataPath "$DD" \
            -clonedSourcePackagesDirPath "$DD/pkgs" \
            build-for-testing > "$TEST_LOG" 2>&1; then
            echo "xcodebuild build-for-testing: FAILED (see $TEST_LOG)" >&2
            tail -40 "$TEST_LOG" >&2
            kill "$MOCK_PID" 2>/dev/null || true
            exit 1
        fi
        if $LOCK xcodebuild -project Geist6.xcodeproj -scheme Geist6 \
            -destination "platform=iOS Simulator,name=$SIM_NAME,OS=latest" \
            -derivedDataPath "$DD" \
            -clonedSourcePackagesDirPath "$DD/pkgs" \
            test-without-building >> "$TEST_LOG" 2>&1; then
            echo "xcodebuild test: passed (prewarmed, full log in $TEST_LOG)"
        else
            echo "xcodebuild test: FAILED (see $TEST_LOG)" >&2
            tail -40 "$TEST_LOG" >&2
            kill "$MOCK_PID" 2>/dev/null || true
            exit 1
        fi
    elif $LOCK xcodebuild -project Geist6.xcodeproj -scheme Geist6 \
        -destination "platform=iOS Simulator,name=$SIM_NAME,OS=latest" \
        -derivedDataPath "$DD" \
        -clonedSourcePackagesDirPath "$DD/pkgs" \
        test > "$TEST_LOG" 2>&1; then
        echo "xcodebuild test: passed (full log in $TEST_LOG)"
    else
        echo "xcodebuild test: FAILED (see $TEST_LOG)" >&2
        tail -40 "$TEST_LOG" >&2
        kill "$MOCK_PID" 2>/dev/null || true
        rm -rf "$DD"
        exit 1
    fi
    # Suite-presence guard: every *UITests class in TestsAppUI must have run
    # (and passed) in the log. A stale runner or a test-plan omission would
    # otherwise pass the gate without ever executing the new suite (gate52:
    # test-without-building on a stale DerivedData skipped
    # InvoiceWriteUITests and still reported green).
    for suite_file in TestsAppUI/*UITests.swift; do
        suite=$(basename "$suite_file" .swift)
        if ! grep -q "Test Suite '$suite' passed" "$TEST_LOG"; then
            echo "check.sh: suite '$suite' never ran or did not pass" >&2
            kill "$MOCK_PID" 2>/dev/null || true
            exit 1
        fi
    done
    if [ -z "${GEIST6_DD:-}" ]; then
        rm -rf "$DD"
    fi

    kill "$MOCK_PID" 2>/dev/null || true
    wait "$MOCK_PID" 2>/dev/null || true
else
    echo "xcodebuild not present; skipping app tests (Linux job)"
fi

echo "check.sh: all green"
