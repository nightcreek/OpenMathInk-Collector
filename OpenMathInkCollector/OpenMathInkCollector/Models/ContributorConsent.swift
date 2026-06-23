import Foundation

struct ContributorConsent: Codable {
    var agreedAt: Date
    var voluntaryContribution: Bool
    var allowsOpenSourceDatasetSharing: Bool
    var acknowledgesNoAutoUpload: Bool
}
