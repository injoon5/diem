#!/bin/sh
# Draw the session ring, at every case that is awkward to reach on a wrist, to
# PNGs you can look at — without a watch, a simulator, or a running session.
#
# `core-check.sh` proves the numbers behind the ring. This proves the picture:
# a subject changed two seconds ago, a dozen of them in an hour, a session past
# the turn, free time between two subjects, the wrist dropped. Each is a frame
# in a contact sheet, drawn by the real `SubjectRing` with the real palette.
#
#   sh Scripts/ring-gallery.sh [out-dir]
#
# It also writes `lapping.png`: the same lapped sessions drawn at every
# candidate setting of `SubjectRing.Lapping`, one row per variant, for choosing
# how hard a spent turn is knocked back and what ground the current one gets.
# `shadow.png` does the same for the shadow the current turn casts on it.
#
# Needs a Mac with Xcode's toolchain. Set DEVELOPER_DIR if `xcode-select` does
# not already point at one.
set -eu

WATCH=$(cd "$(dirname "$0")/.." && pwd)
OUT=${1:-$WATCH/.ring-gallery}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"

cat > "$WORK/main.swift" <<'EOF'
import SwiftUI
import AppKit

/// One frame of the sheet: what it is called, and the session behind it.
struct Case {
    let name: String
    let runs: [SubjectRing.Run]
    /// What one revolution is worth. A planned session hands in its goal.
    var perTurn: TimeInterval = SubjectBar.secondsPerTurn
    var dimmed = false
    var lineWidth: CGFloat = 8
    var lapping: SubjectRing.Lapping = .standard
}

func m(_ minutes: Double) -> TimeInterval { minutes * 60 }
func run(_ index: Int?, _ minutes: Double) -> SubjectRing.Run {
    SubjectRing.Run(colorIndex: index, seconds: m(minutes))
}
func seconds(_ index: Int?, _ s: Double) -> SubjectRing.Run {
    SubjectRing.Run(colorIndex: index, seconds: s)
}

let cases: [Case] = [
    Case(name: "Nothing yet", runs: []),
    Case(name: "One subject, 12m", runs: [run(0, 12)]),
    Case(name: "Switched 2s ago", runs: [run(0, 20), seconds(4, 2)]),
    Case(name: "Switched 30s ago", runs: [run(0, 20), seconds(4, 30)]),
    Case(name: "Switched 3m ago", runs: [run(0, 20), run(4, 3)]),
    Case(name: "Two halves", runs: [run(1, 30), run(8, 30)]),
    Case(name: "Free time between", runs: [run(2, 15), run(nil, 10), run(6, 15)]),
    Case(name: "Same subject twice", runs: [run(3, 10), run(3, 10)]),
    Case(name: "Six subjects", runs: (0..<6).map { run($0 * 2, 6) }),
    Case(name: "Twelve subjects", runs: (0..<12).map { run($0, 4) }),
    Case(name: "Twenty, a minute each", runs: (0..<20).map { run($0, 1) }),
    Case(name: "Rapid, 20s each", runs: (0..<24).map { seconds($0, 20) }),
    Case(name: "Nearly a turn", runs: [run(5, 40), run(9, 19)]),
    Case(name: "Just past the turn", runs: [run(5, 40), run(9, 25)]),
    Case(name: "Lapped, switched 2s ago", runs: [run(5, 60), seconds(9, 2)]),
    Case(name: "Two and a half hours", runs: [run(7, 150)]),
    Case(name: "Long day, many subjects", runs: (0..<14).map { run($0, 9) }),
    Case(name: "Switched 2s ago, dimmed", runs: [run(0, 20), seconds(4, 2)], dimmed: true),
    Case(name: "25m goal, 12m in", runs: [run(2, 8), run(5, 4)], perTurn: m(25)),
    Case(name: "25m goal, nearly there", runs: [run(2, 14), run(5, 9)], perTurn: m(25)),
    Case(name: "25m goal, 4m over", runs: [run(2, 14), run(5, 15)], perTurn: m(25)),
]

struct Frame: View {
    let item: Case
    var body: some View {
        VStack(spacing: 6) {
            SubjectRing(
                runs: item.runs,
                secondsPerTurn: item.perTurn,
                lineWidth: item.lineWidth,
                lapping: item.lapping
            )
                .frame(width: 168, height: 168)
                .environment(\.isLuminanceReduced, item.dimmed)
            Text(item.name)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 180)
                .multilineTextAlignment(.center)
        }
        .padding(10)
    }
}

struct Sheet: View {
    let cases: [Case]
    let columns: Int
    var rows: [[Case]] {
        stride(from: 0, to: cases.count, by: columns).map {
            Array(cases[$0..<min($0 + columns, cases.count)])
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, item in
                        Frame(item: item)
                    }
                }
            }
        }
        .padding(16)
        .background(.black)
    }
}

/// The lapped cases, drawn at every candidate lapping.
///
/// Rows are settings, columns are sessions. Read down a column to see what a
/// change costs, across a row to see whether it survives every shape of lap.
let shadows: [(String, SubjectRing.Lapping.Shadow)] = [
    ("none", .none),
    ("goal ring   .60 / r2 / 1", .init(opacity: 0.60, radius: 2, offset: 1)),
    ("harder      .85 / r1.5 / 1.5", .init(opacity: 0.85, radius: 1.5, offset: 1.5)),
    ("hardest     1.0 / r1 / 2", .init(opacity: 1.0, radius: 1, offset: 2)),
    ("deep        .85 / r3 / 2", .init(opacity: 0.85, radius: 3, offset: 2)),
    ("no offset   .90 / r2 / 0", .init(opacity: 0.90, radius: 2, offset: 0)),
]

/// The shadow held still while the three ground numbers move.
let shape = SubjectRing.Lapping.standard.shadow

let variants: [(String, SubjectRing.Lapping)] = [
    ("as it was  0.42 / — / —", .init(lapped: 0.42, scrim: 0, track: 0, shadow: shape)),
    ("dimmer     0.30 / — / —", .init(lapped: 0.30, scrim: 0, track: 0, shadow: shape)),
    ("track only 0.42 / — / .10", .init(lapped: 0.42, scrim: 0, track: 0.10, shadow: shape)),
    ("ground     0.42 / .45 / .10", .init(lapped: 0.42, scrim: 0.45, track: 0.10, shadow: shape)),
    ("standard   0.34 / .45 / .10", .standard),
    ("harder     0.30 / .55 / .14", .init(lapped: 0.30, scrim: 0.55, track: 0.14, shadow: shape)),
    ("faintest   0.24 / .60 / .10", .init(lapped: 0.24, scrim: 0.60, track: 0.10, shadow: shape)),
]

let lapped: [Case] = [
    Case(name: "5m past the hour", runs: [run(5, 40), run(9, 25)]),
    Case(name: "Lapped, switched 2s ago", runs: [run(5, 60), seconds(9, 2)]),
    Case(name: "25m goal, 4m over", runs: [run(2, 14), run(5, 15)], perTurn: m(25)),
    Case(name: "Half a turn over", runs: [run(7, 90)]),
    Case(name: "Two and a half hours", runs: [run(7, 150)]),
]

/// The same lapped sessions at every candidate shadow, with the lapping held
/// at `.standard`.
struct ShadowSheet: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(shadows.enumerated()), id: \.offset) { _, shadow in
                HStack(spacing: 0) {
                    Text(shadow.0)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 200, alignment: .leading)
                    ForEach(Array(lapped.enumerated()), id: \.offset) { _, item in
                        var lapping = SubjectRing.Lapping.standard
                        let _ = lapping.shadow = shadow.1
                        SubjectRing(
                            runs: item.runs,
                            secondsPerTurn: item.perTurn,
                            lineWidth: item.lineWidth,
                            lapping: lapping
                        )
                        .frame(width: 132, height: 132)
                        .padding(8)
                    }
                }
            }
            HStack(spacing: 0) {
                Color.clear.frame(width: 200, height: 1)
                ForEach(Array(lapped.enumerated()), id: \.offset) { _, item in
                    Text(item.name)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .frame(width: 148)
                }
            }
        }
        .padding(16)
        .background(.black)
    }
}

struct VariantSheet: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(variants.enumerated()), id: \.offset) { _, variant in
                HStack(spacing: 0) {
                    Text(variant.0)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 190, alignment: .leading)
                    ForEach(Array(lapped.enumerated()), id: \.offset) { _, item in
                        SubjectRing(
                            runs: item.runs,
                            secondsPerTurn: item.perTurn,
                            lineWidth: item.lineWidth,
                            lapping: variant.1
                        )
                        .frame(width: 132, height: 132)
                        .padding(8)
                    }
                }
            }
            HStack(spacing: 0) {
                Color.clear.frame(width: 190, height: 1)
                ForEach(Array(lapped.enumerated()), id: \.offset) { _, item in
                    Text(item.name)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .frame(width: 148)
                }
            }
        }
        .padding(16)
        .background(.black)
    }
}

@MainActor
func write(_ view: some View, to path: String) {
    let renderer = ImageRenderer(content: view)
    renderer.scale = 2
    guard let image = renderer.nsImage,
          let data = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: data),
          let png = bitmap.representation(using: .png, properties: [:])
    else {
        FileHandle.standardError.write(Data("could not render \(path)\n".utf8))
        exit(1)
    }
    try! png.write(to: URL(fileURLWithPath: path))
    print(path)
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
MainActor.assumeIsolated {
    write(Sheet(cases: cases, columns: 5), to: "\(out)/sheet.png")
    write(VariantSheet(), to: "\(out)/lapping.png")
    write(ShadowSheet(), to: "\(out)/shadow.png")
    for item in cases {
        let name = item.name.replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: ",", with: "")
            .lowercased()
        write(Frame(item: item).background(.black), to: "\(out)/\(name).png")
    }
}
EOF

swiftc -O \
    -target arm64-apple-macos14.0 \
    -o "$WORK/gallery" \
    "$WATCH/Diem/Design/Palette.swift" \
    "$WATCH/Diem/Views/SubjectBar.swift" \
    "$WATCH/Diem/Views/SubjectRing.swift" \
    "$WORK/main.swift"

"$WORK/gallery" "$OUT"
