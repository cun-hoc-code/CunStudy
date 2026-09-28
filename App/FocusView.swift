import SwiftUI

struct FocusView: View {
  @EnvironmentObject private var store: AppStore
  @EnvironmentObject private var reminders: ReminderService
  @EnvironmentObject private var activity: FocusActivityService
  @Environment(\.mamReduceMotion) private var reduceMotion
  @State private var subject = ""
  @State private var minutes = 25
  @State private var stopping = false
  @State private var showStats = false
  @State private var breakMessage = false
  var body: some View {
    NavigationStack {
      TimelineView(.periodic(from: .now, by: 1)) { context in
        PaperPage {
          Text("Chỉ một việc, lúc này.").font(.system(.title, design: .rounded, weight: .bold))
          Text("Đặt điện thoại xuống. Dành một khoảng nhỏ cho điều bạn muốn hiểu.").font(
            .subheadline
          ).foregroundStyle(.secondary)
          if let active = store.state.activeFocus {
            activeContent(active, at: context.date)
          } else {
            if let completed = store.completedFocus {
              FocusCelebration(session: completed)
              Button("Đã nhận mầm mới") { store.completedFocus = nil }.font(.subheadline)
            }
            setupContent
          }
          AmbientPanel()
          Button {
            showStats = true
          } label: {
            Label("Vườn, streak & thống kê", systemImage: "chart.bar.xaxis")
          }.buttonStyle(PencilButtonStyle(color: .butter))
          Text(
            "Thời gian nghỉ không được tính. Khóa máy hoặc rời app vẫn giữ đồng hồ của phiên học."
          ).font(.caption).foregroundStyle(.secondary)
        }
      }
      .navigationTitle("Tập trung").navigationBarTitleDisplayMode(.inline)
      .onAppear { minutes = store.state.preferences.focusMinutes }
      .sheet(isPresented: $showStats) { ProgressDashboard() }
      .confirmationDialog("Kết thúc phiên này?", isPresented: $stopping, titleVisibility: .visible)
      {
        Button("Lưu thời gian đã học") { store.finishFocus() }
        Button("Bỏ phiên này", role: .destructive) { store.finishFocus(discard: true) }
      }
      .alert("Đã bắt đầu giờ nghỉ", isPresented: $breakMessage) {
        Button("Được") {}
      } message: {
        Text(
          "Bạn sẽ nhận thông báo sau \(store.state.preferences.breakMinutes) phút. Thả lỏng vai và nhìn ra xa một chút nhé."
        )
      }
    }
  }
  private var setupContent: some View {
    VStack(spacing: 18) {
      if store.completedFocus == nil { GrowingGarden(progress: 0.25, active: false) }
      PaperCard {
        VStack(alignment: .leading, spacing: 14) {
          Text("Mầm tiếp theo của bạn").font(.headline)
          TextField("Môn học hoặc mục tiêu phiên này", text: $subject).textInputAutocapitalization(
            .sentences)
          HStack {
            ForEach([25, 45, 60], id: \.self) { n in
              Button("\(n) phút") {
                minutes = n
                StudyHaptics.selection(enabled: store.state.preferences.haptics)
              }.buttonStyle(PencilButtonStyle(color: minutes == n ? .sage : .sky))
                .accessibilityAddTraits(minutes == n ? .isSelected : [])
            }
          }
          Stepper("Tùy chỉnh: \(minutes) phút", value: $minutes, in: 5...120, step: 5)
        }
      }
      Button {
        store.startFocus(subject: subject, minutes: minutes)
      } label: {
        Label("Trồng một mầm mới", systemImage: "play.fill")
      }.buttonStyle(PencilButtonStyle())
      Button("Nghỉ \(store.state.preferences.breakMinutes) phút") {
        Task {
          breakMessage = await reminders.startBreak(minutes: store.state.preferences.breakMinutes)
          if !breakMessage {
            store.errorMessage = reminders.problems.first ?? "Chưa đặt được giờ nghỉ."
          }
        }
      }.font(.subheadline)
    }
  }
  private func activeContent(_ active: ActiveFocus, at now: Date) -> some View {
    let elapsed = active.elapsed(at: now)
    let progress = elapsed / active.plannedSeconds
    let left = max(0, Int(ceil(active.plannedSeconds - elapsed)))
    return VStack(spacing: 18) {
      PaperCard {
        VStack(spacing: 14) {
          HStack {
            Chip(
              text: active.isPaused ? "Tạm dừng" : "Đang vun trồng",
              color: active.isPaused ? .butter : .sage)
            Spacer()
            Text("\(Int(active.plannedSeconds / 60)) phút").font(.caption).foregroundStyle(
              .secondary)
          }
          ZStack {
            Circle().stroke(Pencil.green.opacity(0.12), lineWidth: 7)
            Circle().trim(from: 0, to: progress)
              .stroke(Pencil.green, style: StrokeStyle(lineWidth: 7, lineCap: .round))
              .rotationEffect(.degrees(-90))
              .animation(reduceMotion ? nil : .linear(duration: 0.8), value: progress)
            GrowingGarden(progress: progress, active: !active.isPaused)
              .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: progress)
          }.frame(width: 205, height: 205).padding(.vertical, 8).accessibilityHidden(true)
          Text(String(format: "%02d:%02d", left / 60, left % 60))
            .font(.system(size: 60, weight: .light, design: .rounded)).monospacedDigit()
            .minimumScaleFactor(0.65).lineLimit(1)
            .accessibilityLabel("Còn \(left / 60) phút \(left % 60) giây")
          Text(active.subject).font(.headline).multilineTextAlignment(.center)
          Text(active.isPaused ? "Mầm chờ bạn. Cứ nghỉ một chút." : "Mỗi phút là một chút lớn lên.")
            .font(.subheadline).foregroundStyle(.secondary)
        }
      }
      HStack {
        Button(active.isPaused ? "Tiếp tục" : "Tạm dừng") {
          store.pauseOrResume()
          StudyHaptics.selection(enabled: store.state.preferences.haptics)
        }.buttonStyle(PencilButtonStyle())
        Button("Kết thúc") { stopping = true }.buttonStyle(PencilButtonStyle(color: .peach))
      }
      if store.state.preferences.liveActivities {
        Label(activity.message, systemImage: "lock.iphone").font(.caption).foregroundStyle(
          .secondary)
      }
    }
  }
}

private struct FocusCelebration: View {
  @EnvironmentObject private var store: AppStore
  @Environment(\.mamReduceMotion) private var reduceMotion
  @State private var arrived = false
  @State private var burst = false
  let session: FocusSession
  var body: some View {
    let progress = StudyProgress.summary(store.state, at: Date())
    PaperCard(color: .sage) {
      VStack(spacing: 12) {
        ZStack {
          Sprout()
          ForEach(0..<6, id: \.self) { index in
            Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "leaf.fill")
              .font(index.isMultiple(of: 2) ? .body : .caption)
              .foregroundStyle(Pencil.green.opacity(0.65))
              .offset(
                x: CGFloat(index.isMultiple(of: 2) ? -1 : 1) * (65 + CGFloat(index % 3) * 15),
                y: CGFloat(index / 2) * 42 - 55
              )
              .scaleEffect(arrived || reduceMotion ? 1 : 0.1)
              .opacity(arrived || reduceMotion ? 1 : 0)
          }
        }
        Text("Một mầm mới trong vườn!").font(.system(.title2, design: .rounded, weight: .bold))
          .multilineTextAlignment(.center)
        Text("Bạn đã dành \(Int(session.seconds / 60)) phút cho \(session.subject).").font(
          .subheadline
        ).multilineTextAlignment(.center)
        Label(
          "\(progress.currentStreak) ngày giữ nhịp • Cấp \(progress.level)",
          systemImage: "flame.fill"
        ).font(.subheadline.bold())
        Text("Lưu xong rồi. Đến lúc nghỉ một chút.").font(.caption).foregroundStyle(.secondary)
      }.frame(maxWidth: .infinity)
    }
    .overlay { if burst { LeafCelebration() } }
    .onAppear {
      burst = true
      withAnimation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.65)) {
        arrived = true
      }
    }
  }
}
