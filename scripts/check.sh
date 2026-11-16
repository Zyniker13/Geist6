#!/bin/sh
# What CI runs. Run this before every push (AGENTS.md).
set -eu
cd "$(dirname "$0")/.."

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
    swift-format lint --recursive --parallel Sources Tools Tests \
        --exclude Sources/StripeModels/Generated --exclude Sources/StripeClient/Generated \
        >/dev/null
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
    echo "== app build (xcodegen + xcodebuild) =="
    if command -v xcodegen >/dev/null 2>&1; then
        xcodegen generate
    else
        echo "xcodegen not installed; skipping app build (brew install xcodegen)" >&2
        exit 1
    fi
    xcodebuild -project Geist6.xcodeproj -scheme Geist6 \
        -destination 'platform=iOS Simulator,name=iPad (A16),OS=latest' \
        -quiet build
else
    echo "xcodebuild not present; skipping app build (Linux job)"
fi

echo "check.sh: all green"
