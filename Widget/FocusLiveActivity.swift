import ActivityKit
import SwiftUI
import WidgetKit

struct FocusLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: FocusActivityAttributes.self) { context in
      HStack(spacing: 16) {
        LiveSprout().frame(width: 48, height: 64).accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 5) {
          Text(status(context)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
          Text(context.attributes.subject).font(.headline).lineLimit(1)
          FocusActivityClock(state: context.state, ended: context.isStale)
            .font(.system(.title, design: .rounded, weight: .semibold))
          activityProgress(context).tint(.green)
        }
        Image(systemName: context.state.isPaused ? "pause.circle" : "leaf.circle")
          .font(.title2).foregroundStyle(.green).accessibilityHidden(true)
      }
      .padding(16)
      .activityBackgroundTint(Color(uiColor: .secondarySystemBackground))
      .activitySystemActionForegroundColor(Color.primary)
      .widgetURL(URL(string: "mamstudy://focus"))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          LiveSprout().frame(width: 36, height: 45).padding(.top, 4)
        }
        DynamicIslandExpandedRegion(.trailing) {
          FocusActivityClock(state: context.state, ended: context.isStale)
            .font(.system(.title2, design: .rounded, weight: .semibold)).frame(width: 95)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 6) {
            Text(context.attributes.subject).font(.subheadline.weight(.semibold)).lineLimit(1)
            Text(status(context)).font(.caption).foregroundStyle(.secondary)
            activityProgress(context).tint(.green)
          }.padding(.bottom, 4)
        }
      } compactLeading: {
        Image(systemName: "leaf.fill").foregroundStyle(.green)
      } compactTrailing: {
        FocusActivityClock(state: context.state, ended: context.isStale)
          .font(.caption.monospacedDigit()).frame(width: 50)
      } minimal: {
        Image(systemName: context.state.isPaused ? "pause.fill" : "leaf.fill").foregroundStyle(
          .green)
      }
      .widgetURL(URL(string: "mamstudy://focus"))
      .keylineTint(.green)
    }
  }

  private func status(_ context: ActivityViewContext<FocusActivityAttributes>) -> String {
    if context.state.isComplete || context.isStale { return "MẦM ĐÃ LỚN • ĐẾN GIỜ NGHỈ" }
    return context.state.isPaused ? "MẦM • TẠM DỪNG" : "MẦM • ĐANG TẬP TRUNG"
  }

  @ViewBuilder private func activityProgress(
    _ context: ActivityViewContext<FocusActivityAttributes>
  ) -> some View {
    if context.state.isComplete || context.isStale {
      ProgressView(value: 1.0)
    } else if context.state.isPaused {
      ProgressView(value: context.state.progress)
    } else {
      ProgressView(
        timerInterval: context.state.timerStart...context.state.timerEnd, countsDown: false
      )
      .labelsHidden()
    }
  }
}

private struct FocusActivityClock: View {
  let state: FocusActivityAttributes.ContentState
  let ended: Bool
  var body: some View {
    Group {
      if state.isComplete || ended {
        Text("00:00")
      } else if state.isPaused {
        Text(String(format: "%02d:%02d", state.remainingSeconds / 60, state.remainingSeconds % 60))
      } else {
        Text(timerInterval: state.timerStart...state.timerEnd, countsDown: true, showsHours: false)
      }
    }.monospacedDigit().multilineTextAlignment(.leading)
  }
}

private struct LiveSprout: View {
  var body: some View {
    ZStack {
      Capsule().fill(.green).frame(width: 3, height: 35).offset(y: 10)
      Ellipse().fill(.green.opacity(0.65)).frame(width: 26, height: 14).rotationEffect(.degrees(30))
        .offset(x: -10, y: -6)
      Ellipse().fill(.green).frame(width: 26, height: 14).rotationEffect(.degrees(-30)).offset(
        x: 10, y: -12)
      Ellipse().fill(Color.secondary.opacity(0.2)).frame(width: 40, height: 5).offset(y: 29)
    }
  }
}
