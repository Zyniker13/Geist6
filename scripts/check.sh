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

    stripe-mock --port 12111 &
    MOCK_PID=$!
    sleep 2

    # The app is iPad-only: pick whichever iPad simulator is actually
    # installed (names differ across Xcode versions), and fail with a clear
    # message when none exists instead of xcodebuild's exit 70.
    SIM_NAME=$(xcrun simctl list devices available 2>/dev/null | awk '
        /^-- iOS/ { have=1; next }
        /^--/ { if (have) exit; next }
        have && /iPad/ {
            line=$0
            sub(/^[ ]+/, "", line)
            sub(/ \([A-F0-9-]{36}\) .*/, "", line)
            print line; exit
        }')
    if [ -z "$SIM_NAME" ]; then
        echo "xcodebuild test: FAILED — no iPad simulator installed (the app is iPad-only). Install an iPad-capable iOS runtime." >&2
        kill "$MOCK_PID" 2>/dev/null || true
        exit 1
    fi
    echo "app tests on simulator: $SIM_NAME"

    # Fresh derived data for every run: reusing a previous one can hang
    # the PruneExplicitPrecompiledModules phase.
    rm -rf /tmp/geist6-dd
    if xcodebuild -project Geist6.xcodeproj -scheme Geist6 \
        -destination "platform=iOS Simulator,name=$SIM_NAME,OS=latest" \
        -derivedDataPath /tmp/geist6-dd \
        test > /tmp/geist6-xcode-test.txt 2>&1; then
        echo "xcodebuild test: passed (full log in /tmp/geist6-xcode-test.txt)"
    else
        echo "xcodebuild test: FAILED (see /tmp/geist6-xcode-test.txt)" >&2
        tail -40 /tmp/geist6-xcode-test.txt >&2
        kill "$MOCK_PID" 2>/dev/null || true
        exit 1
    fi

    kill "$MOCK_PID" 2>/dev/null || true
    wait "$MOCK_PID" 2>/dev/null || true
else
    echo "xcodebuild not present; skipping app tests (Linux job)"
fi

echo "check.sh: all green"
