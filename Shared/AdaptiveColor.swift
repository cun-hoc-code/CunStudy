import SwiftUI
import UIKit

extension Color {
  static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
    func ui(_ hex: UInt32) -> UIColor {
      UIColor(
        red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
        blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
    let day = ui(light)
    let night = ui(dark)
    return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? night : day })
  }
}
