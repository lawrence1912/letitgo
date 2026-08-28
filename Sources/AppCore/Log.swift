import OSLog

/// 统一日志入口。用 `Log.ui.debug("…")` 这种方式打点，
/// Console.app 里可以按 subsystem / category 过滤。
public enum Log {
    public static let subsystem = "com.lawrence.LetItGo"

    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let ui = Logger(subsystem: subsystem, category: "ui")
    public static let data = Logger(subsystem: subsystem, category: "data")
}
