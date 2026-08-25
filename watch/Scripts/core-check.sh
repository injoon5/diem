#!/bin/sh
# Compile and test the Foundation-only core on any platform with a Swift
# toolchain — no Apple SDK, no Xcode.
#
# This exists because `swiftc -parse` was the only check this repo had, and
# parsing is not type-checking: `Views/Ring.swift` handed a subject id to a
# function that takes a colour index and parsed clean for two releases while
# the app target could not be built at all.
#
# It cannot cover the views. What it does cover is every file that decides a
# number: the day boundary, the formats, the crown curves, session assembly,
# the live-session summary, the widget snapshot and its day staleness, and the
# Smart Stack relevance window.
#
#   sh Scripts/core-check.sh
#
# Everything else still needs `xcodegen generate` and a real build. Run that
# before believing the app compiles.
set -eu

WATCH=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/Sources/Diem" "$WORK/Tests/DiemTests"

cat > "$WORK/Package.swift" <<'EOF'
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Diem",
    targets: [
        .target(name: "Diem", swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "DiemTests", dependencies: ["Diem"], swiftSettings: [.swiftLanguageMode(.v6)]),
    ]
)
EOF

for file in \
    Diem/Model/Day.swift \
    Diem/Model/Snapshot.swift \
    Diem/Model/SessionAssembly.swift \
    Diem/Design/Format.swift \
    Diem/Views/Scrub.swift
do
    cp "$WATCH/$file" "$WORK/Sources/Diem/"
done

# `Sync/DTO.swift` is mostly wire types, but it also extends the SwiftData
# models — which need an Apple SDK. Only the ISO8601 helper comes across, and
# the tests use it to write dates readably.
awk '/^enum ISO8601 \{/,0' "$WATCH/Diem/Sync/DTO.swift" \
    | awk 'BEGIN { print "import Foundation"; print "" } /^(extension|struct|final|class) /{ exit } { print }' \
    > "$WORK/Sources/Diem/ISO8601.swift"

cp "$WATCH/DiemTests/DiemTests.swift" "$WORK/Tests/DiemTests/"

cd "$WORK"
swift test
