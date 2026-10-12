import Foundation

/// Follows the system (or per-app) preferred language: Chinese for zh-*, English otherwise.
enum AppLanguage {
  static let isChinese: Bool = {
    let preferred = Bundle.preferredLocalizations(
      from: ["en", "zh-Hans"], forPreferences: Locale.preferredLanguages)
    return preferred.first?.hasPrefix("zh") ?? false
  }()

  static var locale: Locale {
    isChinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
  }
}

func L(_ chinese: String, _ english: String) -> String {
  AppLanguage.isChinese ? chinese : english
}
