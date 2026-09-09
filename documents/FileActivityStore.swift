import Combine
import Foundation
import GoogleSignIn

@MainActor
final class FileActivityStore: ObservableObject {
  static let shared = FileActivityStore()
  @Published private(set) var revision = 0

  private var storageKey: String {
    "recentlyOpened." + (GIDSignIn.sharedInstance.currentUser?.userID ?? "preview")
  }

  private var openedDates: [String: Double] {
    UserDefaults.standard.dictionary(forKey: storageKey) as? [String: Double] ?? [:]
  }

  func recordOpened(_ file: FolderFile) {
    var dates = openedDates
    dates[file.id] = Date().timeIntervalSince1970
    let recent = dates.sorted { $0.value > $1.value }.prefix(100)
    UserDefaults.standard.set(
      Dictionary(uniqueKeysWithValues: recent.map { ($0.key, $0.value) }), forKey: storageKey)
    revision += 1
  }

  func recentFiles(in files: [FolderFile]) -> [FolderFile] {
    let dates = openedDates
    var seen = Set<String>()
    return Array(
      files.filter { dates[$0.id] != nil && seen.insert($0.id).inserted }
        .sorted { dates[$0.id, default: 0] > dates[$1.id, default: 0] }
        .prefix(12))
  }

  func openedDateDescription(for file: FolderFile) -> String {
    guard let timestamp = openedDates[file.id] else { return file.date }
    return Date(timeIntervalSince1970: timestamp).formatted(.relative(presentation: .named))
  }
}
