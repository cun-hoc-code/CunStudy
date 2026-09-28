import SwiftUI
import UIKit

extension AppAppearance {
  var colorScheme: ColorScheme? {
    switch self {
    case .system: return nil
    case .light: return .light
    case .dark: return .dark
    }
  }
}

extension InkColor {
  var wash: Color {
    switch self {
    case .sage: return .adaptive(0xCCE0BF, 0x304431)
    case .peach: return .adaptive(0xFAD1A8, 0x503B2E)
    case .lavender: return .adaptive(0xDBD1F0, 0x41394F)
    case .sky: return .adaptive(0xC4DEF0, 0x2E424F)
    case .butter: return .adaptive(0xFAEDAD, 0x49432B)
    case .rose: return .adaptive(0xF5CCCC, 0x503437)
    }
  }
}

enum Pencil {
  static let ink = Color.adaptive(0x354033, 0xE4ECDE)
  static let paper = Color.adaptive(0xFBF8F1, 0x141C18)
  static let surface = Color.adaptive(0xFFFFFF, 0x202A23)
  static let green = Color.adaptive(0x42643D, 0xA7CF8D)
  static let weekdays = [2, 3, 4, 5, 6, 7, 1]
  static func weekday(_ value: Int) -> String { value == 1 ? "CN" : "T\(value)" }
  static func time(_ minute: Int) -> String {
    String(format: "%02d:%02d", (minute / 60) % 24, minute % 60)
  }
  static func duration(_ minutes: Double) -> String {
    let n = max(0, Int(minutes))
    return n >= 60 ? "\(n / 60) giờ \(n % 60) phút" : "\(n) phút"
  }
}

struct PencilOutline: Shape {
  func path(in r: CGRect) -> Path {
    Path { p in
      p.move(to: CGPoint(x: 17, y: 2))
      p.addQuadCurve(to: CGPoint(x: r.width - 18, y: 3), control: CGPoint(x: r.midX, y: -1))
      p.addQuadCurve(to: CGPoint(x: r.width - 2, y: 19), control: CGPoint(x: r.width, y: 2))
      p.addLine(to: CGPoint(x: r.width - 3, y: r.height - 19))
      p.addQuadCurve(
        to: CGPoint(x: r.width - 19, y: r.height - 3), control: CGPoint(x: r.width, y: r.height))
      p.addQuadCurve(
        to: CGPoint(x: 19, y: r.height - 2), control: CGPoint(x: r.midX, y: r.height + 1))
      p.addQuadCurve(to: CGPoint(x: 3, y: r.height - 18), control: CGPoint(x: 0, y: r.height))
      p.addLine(to: CGPoint(x: 2, y: 19))
      p.addQuadCurve(to: CGPoint(x: 17, y: 2), control: .zero)
      p.closeSubpath()
    }
  }
}

struct PaperBackground: View {
  var body: some View {
    Pencil.paper.overlay {
      Canvas { context, size in
        for y in stride(from: 16.0, to: size.height, by: 24) {
          for x in stride(from: 16.0, to: size.width, by: 24) {
            context.fill(
              Path(ellipseIn: CGRect(x: x, y: y, width: 1.3, height: 1.3)),
              with: .color(Pencil.ink.opacity(0.08)))
          }
        }
      }.accessibilityHidden(true)
    }.ignoresSafeArea()
  }
}

struct PaperCard<Content: View>: View {
  var color: InkColor? = nil
  @ViewBuilder var content: () -> Content
  var body: some View {
    content().frame(maxWidth: .infinity, alignment: .leading).padding(17)
      .background(PencilOutline().fill(color?.wash ?? Pencil.surface.opacity(0.94)))
      .overlay(
        PencilOutline().stroke(
          Pencil.ink.opacity(0.28),
          style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
      )
  }
}

struct PaperPage<Content: View>: View {
  @ViewBuilder var content: () -> Content
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18, content: content)
        .frame(maxWidth: 720).padding(20).frame(maxWidth: .infinity)
    }.background(PaperBackground())
  }
}

struct PencilButtonStyle: PrimitiveButtonStyle {
  var color: InkColor = .sage
  func makeBody(configuration: Configuration) -> some View {
    Button {
      InteractionFeedback.shared.play(.tap)
      configuration.trigger()
    } label: {
      configuration.label
    }.buttonStyle(PencilPressVisualStyle(color: color))
  }
}

private struct PencilPressVisualStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.isEnabled) private var isEnabled
  let color: InkColor
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(.body, design: .rounded, weight: .semibold))
      .foregroundStyle(Pencil.ink).padding(.horizontal, 17).padding(.vertical, 13)
      .frame(maxWidth: .infinity).background(PencilOutline().fill(color.wash))
      .overlay(PencilOutline().stroke(Pencil.ink.opacity(0.35), lineWidth: 1.2))
      .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
      .animation(
        reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.75),
        value: configuration.isPressed)
  }
}

struct SectionTitle: View {
  let title: String
  var caption: String? = nil
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(LocalizedStringKey(title)).font(.system(.title3, design: .rounded, weight: .bold))
      if let caption {
        Text(LocalizedStringKey(caption)).font(.footnote).foregroundStyle(.secondary)
      }
    }
  }
}

struct EmptyPageCard: View {
  let symbol: String
  let title: String
  let detail: String
  var body: some View {
    PaperCard {
      HStack(alignment: .top, spacing: 14) {
        Image(systemName: symbol).font(.title2).foregroundStyle(Pencil.green)
        VStack(alignment: .leading, spacing: 5) {
          Text(LocalizedStringKey(title)).font(.headline)
          Text(LocalizedStringKey(detail)).font(.subheadline).foregroundStyle(.secondary)
        }
      }
    }
  }
}

struct Chip: View {
  let text: String
  var color: InkColor = .sage
  var body: some View {
    Text(text).font(.caption.weight(.medium)).padding(.horizontal, 9).padding(.vertical, 5)
      .background(color.wash, in: Capsule())
  }
}

struct Sprout: View, Animatable {
  var progress: Double = 1
  var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }
  var body: some View {
    Canvas { context, size in
      let x = size.width / 2
      let bottom = size.height * 0.84
      let height = size.height * (0.22 + 0.40 * min(1, max(0, progress)))
      var ground = Path()
      ground.move(to: CGPoint(x: x - 48, y: bottom))
      ground.addQuadCurve(to: CGPoint(x: x + 48, y: bottom), control: CGPoint(x: x, y: bottom + 7))
      context.stroke(
        ground, with: .color(Pencil.ink.opacity(0.4)),
        style: StrokeStyle(lineWidth: 2, lineCap: .round))
      var stem = Path()
      stem.move(to: CGPoint(x: x, y: bottom))
      stem.addQuadCurve(
        to: CGPoint(x: x + 3, y: bottom - height),
        control: CGPoint(x: x - 10, y: bottom - height / 2))
      context.stroke(
        stem, with: .color(Pencil.green), style: StrokeStyle(lineWidth: 4, lineCap: .round))
      for side: CGFloat in [-1, 1] {
        let origin = CGPoint(x: x, y: bottom - height * 0.7)
        let tip = CGPoint(x: x + side * 53, y: bottom - height * 0.98)
        var leaf = Path()
        leaf.move(to: origin)
        leaf.addQuadCurve(
          to: tip, control: CGPoint(x: x + side * 14, y: bottom - height - CGFloat(28)))
        leaf.addQuadCurve(to: origin, control: CGPoint(x: x + side * 45, y: bottom - height * 0.42))
        context.fill(leaf, with: .color(side < 0 ? InkColor.sage.wash : Pencil.green.opacity(0.55)))
        context.stroke(
          leaf, with: .color(Pencil.green), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
      }
    }.frame(height: 170).accessibilityLabel("Mầm cây, tiến độ \(Int(progress * 100)) phần trăm")
  }
}

struct ColorPickerRow: View {
  @Binding var selection: InkColor
  var body: some View {
    HStack {
      ForEach(InkColor.allCases) { color in
        Button {
          selection = color
          InteractionFeedback.shared.play(.selection)
        } label: {
          Circle().fill(color.wash).frame(width: 35, height: 35)
            .overlay {
              if selection == color { Image(systemName: "checkmark").foregroundStyle(Pencil.ink) }
            }
        }.buttonStyle(.plain).accessibilityLabel(color.title)
      }
    }
  }
}
