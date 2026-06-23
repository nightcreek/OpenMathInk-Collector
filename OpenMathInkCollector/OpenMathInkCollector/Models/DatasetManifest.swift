import Foundation

struct DatasetManifest: Codable {
    var datasetName: String
    var version: String
    var createdAt: Date
    var sampleCount: Int
    var formatVersion: String
    var supportsAST: Bool?
    var privacy: DatasetPrivacyInfo
}

struct DatasetPrivacyInfo: Codable {
    var containsPersonalIdentifiers: Bool
    var autoUploaded: Bool
    var userConfirmedExport: Bool
}
