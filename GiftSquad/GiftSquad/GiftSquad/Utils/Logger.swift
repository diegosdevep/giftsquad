import Foundation
import OSLog

final class Logger {
    static let shared = Logger()
    private let logger = os.Logger(subsystem: "com.diegomaidana.GiftSquad", category: "app")

    func info(_ message: String) { logger.info("\(message, privacy: .public)") }
    func error(_ message: String) { logger.error("\(message, privacy: .public)") }
}
