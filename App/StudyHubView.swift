import SwiftUI

struct StudyHubView: View {
  @EnvironmentObject private var store: AppStore
  var body: some View {
    PaperPage {
      HStack {
        VStack(alignment: .leading, spacing: 8) {
          Text(store.t("Góc học của bạn", "Your study studio")).font(
            .system(.largeTitle, design: .serif, weight: .bold))
          Text(
            store.t("Gom những điều nhỏ, nuôi một ước mơ lớn.", "Small steps. Room for big dreams.")
          ).foregroundStyle(.secondary)
        }
        Image(systemName: "leaf.circle.fill").font(.system(size: 48)).foregroundStyle(Pencil.green)
      }
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 14)], spacing: 14) {
        tile("Lịch & khung học", "Schedule & blocks", "calendar", .sage) { ScheduleStudio() }
        tile("Thư viện", "Library", "books.vertical", .butter) { LibraryView() }
        tile("Kệ sách", "Bookshelf", "book.pages", .peach) { BookshelfView() }
        tile("Luyện đề", "Practice", "checkmark.seal", .lavender) { PracticeView() }
        tile("Điểm & tín chỉ", "Grades & credits", "graduationcap", .sky) { AcademicsView() }
        tile("Nhật ký học", "Learning journal", "book.closed", .peach) { JournalView() }
        tile("Mục tiêu", "Goals", "flag.checkered", .sage) { GoalsView() }
        tile("Ví sinh viên", "Student wallet", "wallet.pass", .rose) { WalletView() }
        tile("Trao đổi bộ thẻ", "Deck exchange", "rectangle.on.rectangle.angled", .lavender) {
          DeckToolsView()
        }
        tile("Kết nối & dữ liệu", "Connections & data", "externaldrive.badge.icloud", .sky) {
          ConnectionsView()
        }
      }
    }.navigationTitle(store.t("Góc học tập", "Study studio")).navigationBarTitleDisplayMode(.inline)
  }
  private func tile<D: View>(
    _ vi: String, _ en: String, _ icon: String, _ color: InkColor, @ViewBuilder destination: () -> D
  ) -> some View {
    NavigationLink(destination: destination()) {
      PaperCard(color: color) {
        VStack(alignment: .leading, spacing: 15) {
          Image(systemName: icon).font(.system(size: 28))
          Text(store.t(vi, en)).font(.system(.headline, design: .rounded))
          Spacer(minLength: 0)
          Image(systemName: "arrow.up.right").font(.caption.bold()).frame(
            maxWidth: .infinity, alignment: .trailing)
        }.frame(minHeight: 105)
      }
    }.buttonStyle(SoftPressStyle()).modifier(
      CascadeArrival(
        index: [
          "calendar", "books.vertical", "book.pages", "checkmark.seal", "graduationcap", "book.closed",
          "flag.checkered", "wallet.pass", "rectangle.on.rectangle.angled",
          "externaldrive.badge.icloud",
        ].firstIndex(of: icon) ?? 0))
  }
}
