import SwiftUI

struct PaperReveal: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduce
  @State private var appeared = false
  func body(content: Content) -> some View {
    content.opacity(appeared || reduce ? 1 : 0).scaleEffect(
      appeared || reduce ? 1 : 0.965, anchor: .bottom
    ).offset(y: appeared || reduce ? 0 : 14)
      .onAppear {
        withAnimation(reduce ? nil : .spring(response: 0.5, dampingFraction: 0.84)) {
          appeared = true
        }
      }
  }
}
struct SoftPressStyle: PrimitiveButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    Button {
      InteractionFeedback.shared.play(.tap)
      configuration.trigger()
    } label: {
      configuration.label
    }.buttonStyle(QuietPressStyle())
  }
}
private struct QuietPressStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduce
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed && !reduce ? 0.985 : 1)
      .opacity(configuration.isPressed ? 0.88 : 1)
      .animation(reduce ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
  }
}
struct LeafCelebration: View {
  @Environment(\.accessibilityReduceMotion) private var reduce
  @State private var expanded = false
  var body: some View {
    GeometryReader { geometry in
      ZStack {
        ForEach(0..<14, id: \.self) { i in
          let angle = Double(i) * .pi * 2 / 14
          Image(systemName: i.isMultiple(of: 3) ? "sparkle" : "leaf.fill").font(
            .system(size: CGFloat(10 + i % 4 * 3))
          )
          .foregroundStyle([Pencil.green, InkColor.peach.wash, InkColor.butter.wash][i % 3])
          .rotationEffect(.degrees(expanded ? Double(i * 41) : 0))
          .offset(
            x: expanded ? cos(angle) * min(geometry.size.width * 0.4, 150) : 0,
            y: expanded ? sin(angle) * 130 : 0
          ).opacity(expanded ? 0 : 1)
        }
      }.frame(maxWidth: .infinity, maxHeight: .infinity).onAppear {
        withAnimation(reduce ? nil : .easeOut(duration: 1.25)) { expanded = true }
      }
    }.allowsHitTesting(false).accessibilityHidden(true).opacity(reduce ? 0 : 1)
  }
}
struct GrowingGarden: View {
  @Environment(\.accessibilityReduceMotion) private var reduce
  @Environment(\.scenePhase) private var scene
  let progress: Double
  var active = false
  var body: some View {
    TimelineView(
      .animation(minimumInterval: 1.0 / 24, paused: reduce || !active || scene != .active)
    ) { tick in
      let sway = reduce || !active ? 0 : sin(tick.date.timeIntervalSinceReferenceDate * 1.6) * 2.2
      ZStack {
        Ellipse().fill(InkColor.sage.wash.opacity(0.4)).frame(width: 185, height: 100).blur(
          radius: 25
        ).offset(y: 28)
        Circle().trim(from: 0.05, to: 0.05 + min(1, max(0, progress)) * 0.9).stroke(
          Pencil.green.opacity(0.16),
          style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 7])
        ).frame(width: 170, height: 170).rotationEffect(.degrees(-90))
        Sprout(progress: progress).rotationEffect(.degrees(sway), anchor: .bottom)
        if active && !reduce {
          ForEach(0..<4, id: \.self) { i in
            let phase = tick.date.timeIntervalSinceReferenceDate * 0.45 + Double(i) * 1.8
            Circle().fill(Pencil.green.opacity(0.4)).frame(width: 4, height: 4).offset(
              x: cos(phase) * 85, y: sin(phase * 1.3) * 65)
          }
        }
      }.frame(height: 185)
    }.accessibilityElement(children: .ignore).accessibilityLabel("Mầm cây").accessibilityValue(
      "\(Int(progress * 100))%")
  }
}
struct GardenTabBar: View {
  @EnvironmentObject private var store: AppStore
  @Environment(\.accessibilityReduceMotion) private var reduce
  @Environment(\.dynamicTypeSize) private var size
  @Namespace private var leaf
  private let symbols = [
    "sun.max", "calendar", "leaf", "rectangle.on.rectangle", "pencil.and.scribble",
  ]
  var body: some View {
    HStack(spacing: 4) {
      ForEach(0..<5, id: \.self) { index in
        let selected = store.tab == index
        Button {
          guard store.tab != index else { return }
          store.tab = index
        } label: {
          VStack(spacing: 5) {
            ZStack {
              if selected {
                Capsule().fill(InkColor.sage.wash).matchedGeometryEffect(id: "leaf", in: leaf)
                  .frame(width: 53, height: 31)
              }
              Image(systemName: symbols[index]).font(
                .system(size: 20, weight: selected ? .semibold : .regular)
              )
            }.frame(height: 32)
            if !size.isAccessibilitySize {
              Text(title(index)).font(
                .system(size: 10, weight: selected ? .bold : .medium, design: .rounded)
              ).lineLimit(1).minimumScaleFactor(0.7)
            }
          }.frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(selected ? Pencil.green : Pencil.ink.opacity(0.64))
          .accessibilityLabel(title(index)).accessibilityAddTraits(selected ? .isSelected : [])
      }
    }.padding(.horizontal, 10).padding(.vertical, 8)
      .animation(reduce ? nil : .spring(response: 0.32, dampingFraction: 0.92), value: store.tab)
      .background(
        .regularMaterial, in: RoundedRectangle(cornerRadius: 26)
      ).overlay(RoundedRectangle(cornerRadius: 26).stroke(Pencil.green.opacity(0.14), lineWidth: 1))
      .shadow(color: .black.opacity(0.06), radius: 16, y: 5).padding(.horizontal, 12).padding(
        .bottom, 5)
  }
  private func title(_ index: Int) -> String {
    store.t(
      ["Hôm nay", "Kế hoạch", "Tập trung", "Ôn thẻ", "Sổ tay"][index],
      ["Today", "Planner", "Focus", "Cards", "Notes"][index])
  }
}
struct StudioEditor<Content: View>: View {
  @Environment(\.dismiss) private var dismiss
  let title: String
  var canSave = true
  var save: () -> Bool
  var delete: (() -> Bool)? = nil
  @ViewBuilder var content: () -> Content
  @State private var confirm = false
  var body: some View {
    NavigationStack {
      Form {
        content()
        if delete != nil { Button("Xóa", role: .destructive) { confirm = true } }
      }.navigationTitle(LocalizedStringKey(title)).navigationBarTitleDisplayMode(.inline).toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Lưu") { if save() { dismiss() } }.disabled(!canSave)
        }
      }.confirmationDialog("Xóa mục này?", isPresented: $confirm, titleVisibility: .visible) {
        Button("Xóa", role: .destructive) { if delete?() == true { dismiss() } }
      }
    }
  }
}
struct LayoutPicker: View {
  @EnvironmentObject private var store: AppStore
  var body: some View {
    Picker(
      "Kiểu xem",
      selection: Binding(
        get: { store.state.studio.settings.layout },
        set: { value in _ = store.editStudio { $0.settings.layout = value } })
    ) { ForEach(CollectionLayout.allCases) { Text(LocalizedStringKey($0.title)).tag($0) } }
    .pickerStyle(.segmented)
  }
}

/// Finite stagger on hub entry; no repeating work after arrival.
struct CascadeArrival: ViewModifier {
  let index: Int
  @Environment(\.accessibilityReduceMotion) private var reduce
  @State private var arrived = false
  func body(content: Content) -> some View {
    content.opacity(arrived || reduce ? 1 : 0)
      .offset(y: arrived || reduce ? 0 : 22)
      .rotationEffect(
        .degrees(arrived || reduce ? 0 : (index.isMultiple(of: 2) ? -2 : 2)), anchor: .bottom
      )
      .onAppear {
        withAnimation(
          reduce ? nil : .spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.045)
        ) { arrived = true }
      }
  }
}
