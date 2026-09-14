import Foundation

enum AppError: LocalizedError {
    case auth(String)
    case firestore(String)
    case functions(String)
    case validation(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .auth(let m), .firestore(let m), .functions(let m), .validation(let m), .unknown(let m):
            return m
        }
    }
}
