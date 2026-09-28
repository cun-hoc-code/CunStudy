import CoreText
import PDFKit
import SwiftUI
import UIKit

extension PaperTone {
  var paperUIColor: UIColor {
    switch self {
    case .cream: return UIColor(red: 0.965, green: 0.914, blue: 0.759, alpha: 1)
    case .ivory: return UIColor(red: 0.982, green: 0.969, blue: 0.914, alpha: 1)
    case .sage: return UIColor(red: 0.874, green: 0.922, blue: 0.843, alpha: 1)
    case .rose: return UIColor(red: 0.969, green: 0.875, blue: 0.865, alpha: 1)
    case .night: return UIColor(red: 0.105, green: 0.122, blue: 0.113, alpha: 1)
    }
  }

  var inkUIColor: UIColor {
    self == .night
      ? UIColor(red: 0.88, green: 0.91, blue: 0.85, alpha: 1)
      : UIColor(red: 0.16, green: 0.18, blue: 0.145, alpha: 1)
  }
}

struct ReadingFont: Identifiable, Hashable, Sendable {
  let id: String
  let title: String

  static let options = [
    ReadingFont(id: "Georgia", title: "Georgia"),
    ReadingFont(id: "Palatino-Roman", title: "Palatino"),
    ReadingFont(id: "Baskerville", title: "Baskerville"),
    ReadingFont(id: "Charter-Roman", title: "Charter"),
    ReadingFont(id: "IowanOldStyle-Roman", title: "Iowan Old Style"),
    ReadingFont(id: "HoeflerText-Regular", title: "Hoefler Text"),
    ReadingFont(id: "TimesNewRomanPSMT", title: "Times New Roman"),
    ReadingFont(id: "AvenirNext-Regular", title: "Avenir Next"),
    ReadingFont(id: "HelveticaNeue", title: "Helvetica Neue"),
    ReadingFont(id: "System-Serif", title: "New York / Serif"),
  ]

  static func uiFont(named name: String, size: CGFloat) -> UIFont {
    if name == "System-Serif",
      let descriptor = UIFont.systemFont(ofSize: size).fontDescriptor.withDesign(.serif)
    {
      return UIFont(descriptor: descriptor, size: size)
    }
    return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size)
  }
}

/// Immutable pagination result. Core Text objects are immutable after construction.
final class BookLayout: @unchecked Sendable {
  let attributed: NSAttributedString
  let framesetter: CTFramesetter
  let ranges: [NSRange]
  let pageSize: CGSize
  let textRect: CGRect

  private init(
    attributed: NSAttributedString, framesetter: CTFramesetter, ranges: [NSRange],
    pageSize: CGSize, textRect: CGRect
  ) {
    self.attributed = attributed
    self.framesetter = framesetter
    self.ranges = ranges
    self.pageSize = pageSize
    self.textRect = textRect
  }

  static func make(text: String, size: CGSize, preferences: ReaderPreferences) throws -> BookLayout
  {
    guard size.width >= 120, size.height >= 180 else {
      throw StudyError.invalid("Khung đọc sách quá nhỏ.")
    }
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = CGFloat(preferences.lineSpacing)
    paragraph.paragraphSpacing = CGFloat(preferences.lineSpacing * 0.6)
    paragraph.hyphenationFactor = 0.45
    let attributed = NSAttributedString(
      string: text,
      attributes: [
        .font: ReadingFont.uiFont(named: preferences.font, size: CGFloat(preferences.size)),
        .foregroundColor: preferences.tone.inkUIColor,
        .paragraphStyle: paragraph,
      ])
    let framesetter = CTFramesetterCreateWithAttributedString(attributed)
    let margin = max(25, min(54, size.width * 0.075))
    let rect = CGRect(
      x: margin, y: 54, width: max(40, size.width - margin * 2),
      height: max(70, size.height - 108))
    let path = CGPath(rect: rect, transform: nil)
    let total = (text as NSString).length
    var location = 0
    var ranges: [NSRange] = []
    ranges.reserveCapacity(max(1, total / 900))
    while location < total {
      try Task.checkCancellation()
      let frame = CTFramesetterCreateFrame(
        framesetter, CFRange(location: location, length: 0), path, nil)
      let visible = CTFrameGetVisibleStringRange(frame)
      guard visible.length > 0 else {
        throw StudyError.invalid("Không thể chia trang với cỡ chữ và khung hiện tại.")
      }
      ranges.append(NSRange(location: visible.location, length: visible.length))
      location += visible.length
    }
    if ranges.isEmpty { ranges = [NSRange(location: 0, length: 0)] }
    return BookLayout(
      attributed: attributed, framesetter: framesetter, ranges: ranges, pageSize: size,
      textRect: rect)
  }

  func page(containingUTF16Offset offset: Int) -> Int {
    let safe = max(0, offset)
    var low = 0
    var high = ranges.count - 1
    while low <= high {
      let middle = (low + high) / 2
      let range = ranges[middle]
      if safe < range.location {
        high = middle - 1
      } else if safe >= range.location + max(1, range.length) {
        low = middle + 1
      } else {
        return middle
      }
    }
    return min(max(0, low), max(0, ranges.count - 1))
  }

  func text(for page: Int) -> String {
    guard ranges.indices.contains(page) else { return "" }
    return attributed.attributedSubstring(from: ranges[page]).string
  }
}

private final class BookPaperView: UIView {
  let layout: BookLayout?
  let pdfPage: PDFPage?
  let title: String
  let pageIndex: Int
  let pageCount: Int
  let tone: PaperTone

  init(
    layout: BookLayout?, pdfPage: PDFPage?, title: String, pageIndex: Int, pageCount: Int,
    tone: PaperTone
  ) {
    self.layout = layout
    self.pdfPage = pdfPage
    self.title = title
    self.pageIndex = pageIndex
    self.pageCount = pageCount
    self.tone = tone
    super.init(frame: .zero)
    isOpaque = true
    contentMode = .redraw
    isAccessibilityElement = true
    accessibilityTraits = .staticText
    accessibilityLabel = layout?.text(for: pageIndex) ?? "Trang PDF \(pageIndex + 1)"
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else { return }
    tone.paperUIColor.setFill()
    context.fill(bounds)

    let shadow =
      [
        UIColor.black.withAlphaComponent(tone == .night ? 0.22 : 0.11).cgColor,
        UIColor.clear.cgColor,
      ] as CFArray
    if let gradient = CGGradient(
      colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: shadow, locations: [0, 1])
    {
      context.drawLinearGradient(
        gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: min(24, bounds.width), y: 0),
        options: [])
    }
    context.setStrokeColor(tone.inkUIColor.withAlphaComponent(0.035).cgColor)
    context.setLineWidth(0.45)
    for y in stride(from: 18.0, to: bounds.height, by: 31.0) {
      let wobble = CGFloat(Int(y) % 11) * 0.22
      context.move(to: CGPoint(x: 12, y: y + wobble))
      context.addCurve(
        to: CGPoint(x: bounds.width - 12, y: y),
        control1: CGPoint(x: bounds.width * 0.28, y: y - 0.8),
        control2: CGPoint(x: bounds.width * 0.71, y: y + 0.7))
      context.strokePath()
    }

    let headerStyle = NSMutableParagraphStyle()
    headerStyle.alignment = .center
    (title as NSString).draw(
      in: CGRect(x: 42, y: 19, width: max(20, bounds.width - 84), height: 24),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 11, weight: .medium),
        .foregroundColor: tone.inkUIColor.withAlphaComponent(0.55),
        .paragraphStyle: headerStyle,
      ])
    ("\(pageIndex + 1) / \(pageCount)" as NSString).draw(
      in: CGRect(
        x: 30, y: max(0, bounds.height - 36), width: max(20, bounds.width - 60), height: 20),
      withAttributes: [
        .font: UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
        .foregroundColor: tone.inkUIColor.withAlphaComponent(0.5),
        .paragraphStyle: headerStyle,
      ])

    if let layout, layout.ranges.indices.contains(pageIndex) {
      context.saveGState()
      // UIKit may leave a flipped text matrix in the drawing context. Core Text
      // also needs the coordinate system below to be flipped, so reset the text
      // matrix first or every glyph is rendered upside down/mirrored.
      context.textMatrix = .identity
      context.translateBy(x: 0, y: bounds.height)
      context.scaleBy(x: 1, y: -1)
      let frame = CTFramesetterCreateFrame(
        layout.framesetter,
        CFRange(
          location: layout.ranges[pageIndex].location,
          length: layout.ranges[pageIndex].length),
        CGPath(rect: layout.textRect, transform: nil), nil)
      CTFrameDraw(frame, context)
      context.restoreGState()
    } else if let pdfPage {
      let pageBounds = pdfPage.bounds(for: .mediaBox)
      let target = CGRect(x: 24, y: 50, width: bounds.width - 48, height: bounds.height - 98)
      guard pageBounds.width > 0, pageBounds.height > 0, target.width > 0, target.height > 0 else {
        return
      }
      let scale = min(target.width / pageBounds.width, target.height / pageBounds.height)
      let rendered = CGSize(width: pageBounds.width * scale, height: pageBounds.height * scale)
      let origin = CGPoint(
        x: target.midX - rendered.width / 2, y: target.midY - rendered.height / 2)
      context.saveGState()
      context.setShadow(
        offset: CGSize(width: 0, height: 2), blur: 8,
        color: UIColor.black.withAlphaComponent(0.14).cgColor)
      UIColor.white.setFill()
      context.fill(CGRect(origin: origin, size: rendered))
      context.setShadow(offset: .zero, blur: 0, color: nil)
      context.translateBy(x: origin.x, y: origin.y + rendered.height)
      context.scaleBy(x: scale, y: -scale)
      context.translateBy(x: -pageBounds.minX, y: -pageBounds.minY)
      pdfPage.draw(with: .mediaBox, to: context)
      context.restoreGState()
    }
  }
}

private final class BookPageController: UIViewController {
  let pageIndex: Int
  private let paper: BookPaperView

  init(
    layout: BookLayout?, pdfPage: PDFPage?, title: String, pageIndex: Int, pageCount: Int,
    tone: PaperTone
  ) {
    self.pageIndex = pageIndex
    paper = BookPaperView(
      layout: layout, pdfPage: pdfPage, title: title, pageIndex: pageIndex,
      pageCount: pageCount, tone: tone)
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func loadView() { view = paper }
}

/// Native iOS page curl with a reduced-motion scroll fallback.
struct PaperPageCurl: UIViewControllerRepresentable {
  let layout: BookLayout?
  let pdf: PDFDocument?
  let title: String
  let pageCount: Int
  let tone: PaperTone
  let reduceMotion: Bool
  @Binding var page: Int
  var completed: (Int) -> Void

  func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

  func makeUIViewController(context: Context) -> UIPageViewController {
    let options: [UIPageViewController.OptionsKey: Any]? =
      reduceMotion
      ? nil : [.spineLocation: NSNumber(value: UIPageViewController.SpineLocation.min.rawValue)]
    let controller = UIPageViewController(
      transitionStyle: reduceMotion ? .scroll : .pageCurl,
      navigationOrientation: .horizontal, options: options)
    controller.dataSource = context.coordinator
    controller.delegate = context.coordinator
    controller.isDoubleSided = false
    let initial = context.coordinator.controller(at: safePage(page))
    controller.setViewControllers([initial], direction: .forward, animated: false)
    return controller
  }

  func updateUIViewController(_ controller: UIPageViewController, context: Context) {
    context.coordinator.parent = self
    let target = safePage(page)
    let visible = (controller.viewControllers?.first as? BookPageController)?.pageIndex
    if visible != target {
      context.coordinator.show(target, in: controller, animated: !reduceMotion)
    }
  }

  private func safePage(_ value: Int) -> Int { min(max(0, value), max(0, pageCount - 1)) }

  @MainActor
  final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    var parent: PaperPageCurl
    private var turning = false
    private var pendingPage: Int?

    init(parent: PaperPageCurl) { self.parent = parent }

    fileprivate func controller(at index: Int) -> BookPageController {
      BookPageController(
        layout: parent.layout, pdfPage: parent.pdf?.page(at: index), title: parent.title,
        pageIndex: index, pageCount: max(1, parent.pageCount), tone: parent.tone)
    }

    func show(_ index: Int, in pager: UIPageViewController, animated: Bool) {
      let target = min(max(0, index), max(0, parent.pageCount - 1))
      let current = (pager.viewControllers?.first as? BookPageController)?.pageIndex ?? 0
      guard current != target else { return }
      guard !turning else {
        pendingPage = target
        return
      }
      turning = true
      pager.setViewControllers(
        [controller(at: target)], direction: target > current ? .forward : .reverse,
        animated: animated
      ) { [weak self, weak pager] finished in
        guard let self, let pager else { return }
        self.turning = false
        if finished {
          self.parent.page = target
          self.parent.completed(target)
          InteractionFeedback.shared.play(.page)
        }
        self.followPending(in: pager)
      }
    }

    private func followPending(in pager: UIPageViewController) {
      guard let pendingPage else { return }
      self.pendingPage = nil
      show(pendingPage, in: pager, animated: !parent.reduceMotion)
    }

    func pageViewController(
      _ pageViewController: UIPageViewController,
      viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
      guard let page = viewController as? BookPageController, page.pageIndex > 0 else { return nil }
      return controller(at: page.pageIndex - 1)
    }

    func pageViewController(
      _ pageViewController: UIPageViewController,
      viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
      guard let page = viewController as? BookPageController,
        page.pageIndex + 1 < parent.pageCount
      else { return nil }
      return controller(at: page.pageIndex + 1)
    }

    func pageViewController(
      _ pageViewController: UIPageViewController,
      willTransitionTo pendingViewControllers: [UIViewController]
    ) {
      turning = true
    }

    func pageViewController(
      _ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
      previousViewControllers: [UIViewController], transitionCompleted completed: Bool
    ) {
      turning = false
      if completed,
        let value = (pageViewController.viewControllers?.first as? BookPageController)?.pageIndex
      {
        parent.page = value
        parent.completed(value)
        InteractionFeedback.shared.play(.page)
      }
      followPending(in: pageViewController)
    }

    func pageViewController(
      _ pageViewController: UIPageViewController,
      spineLocationFor orientation: UIInterfaceOrientation
    ) -> UIPageViewController.SpineLocation {
      pageViewController.isDoubleSided = false
      return .min
    }
  }
}
