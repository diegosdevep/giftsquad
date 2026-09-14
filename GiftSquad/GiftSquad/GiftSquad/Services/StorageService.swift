import Foundation
import FirebaseStorage

@MainActor
final class StorageService {
    static let shared = StorageService()
    private let storage = Storage.storage()

    func uploadItemImage(_ data: Data, ownerId: String) async throws -> URL {
        let path = "items/\(ownerId)/\(UUID().uuidString).jpg"
        let ref = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: metadata)
        return try await ref.downloadURL()
    }
}
