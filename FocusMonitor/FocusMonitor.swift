import DeviceActivity
import ManagedSettings

/// The OS invokes this extension even when the app is not in the foreground.
final class FocusMonitor: DeviceActivityMonitor {
  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
    guard activity.rawValue == "mam.focus" else { return }
    ManagedSettingsStore(named: .init("mam.focus")).clearAllSettings()
  }
}
