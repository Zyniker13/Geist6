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
swift run stripe-gen
if [ -n "$(git status --porcelain Sources/StripeModels/Generated Sources/StripeClient/Generated)" ]; then
    echo "ERROR: generated code is stale. Run 'swift run stripe-gen' and commit the result." >&2
    git status --porcelain Sources/StripeModels/Generated Sources/StripeClient/Generated >&2
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

    stripe-mock --port 12111 &
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
        SIM_NAME=$(xcrun simctl list devices available 2>/dev/null | awk '
        /^-- iOS/ { have=1; next }
        /^--/ { if (have) exit; next }
        have && /iPad/ {
            line=$0
            sub(/^[ ]+/, "", line)
            sub(/ \([A-F0-9-]{36}\) .*/, "", line)
            print line; exit
        }')
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
    DD=/tmp/geist6-dd-$$
    rm -rf "$DD"
    if xcodebuild -project Geist6.xcodeproj -scheme Geist6 \
        -destination "platform=iOS Simulator,name=$SIM_NAME,OS=latest" \
        -derivedDataPath "$DD" \
        test > "$TEST_LOG" 2>&1; then
        echo "xcodebuild test: passed (full log in $TEST_LOG)"
    else
        echo "xcodebuild test: FAILED (see $TEST_LOG)" >&2
        tail -40 "$TEST_LOG" >&2
        kill "$MOCK_PID" 2>/dev/null || true
        rm -rf "$DD"
        exit 1
    fi
    rm -rf "$DD"

    kill "$MOCK_PID" 2>/dev/null || true
    wait "$MOCK_PID" 2>/dev/null || true
else
    echo "xcodebuild not present; skipping app tests (Linux job)"
fi

echo "check.sh: all green"
