import Foundation

@MainActor
final class ContributorConsentManager: ObservableObject {
    static let shared = ContributorConsentManager()

    @Published var showConsentSheet: Bool = false
    @Published var hasCompletedOnboarding: Bool = false
    @Published var voluntaryContribution: Bool = false
    @Published var allowsOpenSourceSharing: Bool = false
    @Published var acknowledgesNoAutoUpload: Bool = false

    private let consentKey = "contributor_consent_v1"
    private let onboardingKey = "consent_onboarding_completed"

    private var cachedConsent: ContributorConsent?
    private var cachedConsentKey: String?

    var currentConsent: ContributorConsent? {
        if let cached = cachedConsent, cachedConsentKey == consentKey {
            return cached
        }
        guard let data = UserDefaults.standard.data(forKey: consentKey),
              let consent = try? JSONDecoder().decode(ContributorConsent.self, from: data) else {
            cachedConsent = nil
            cachedConsentKey = nil
            return nil
        }
        cachedConsent = consent
        cachedConsentKey = consentKey
        return consent
    }

    var hasValidConsent: Bool {
        currentConsent != nil
    }

    var allAgreementsAccepted: Bool {
        voluntaryContribution && allowsOpenSourceSharing && acknowledgesNoAutoUpload
    }

    private init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)
    }

    func requestConsent() {
        voluntaryContribution = false
        allowsOpenSourceSharing = false
        acknowledgesNoAutoUpload = false
        showConsentSheet = true
    }

    func submitConsent() {
        guard allAgreementsAccepted else { return }
        let consent = ContributorConsent(
            agreedAt: Date(),
            voluntaryContribution: voluntaryContribution,
            allowsOpenSourceDatasetSharing: allowsOpenSourceSharing,
            acknowledgesNoAutoUpload: acknowledgesNoAutoUpload
        )
        do {
            let data = try JSONEncoder().encode(consent)
            UserDefaults.standard.set(data, forKey: consentKey)
            cachedConsent = consent
            cachedConsentKey = consentKey
        } catch {
            print("[ContributorConsentManager] 同意书编码失败: \(error)")
        }
        showConsentSheet = false
    }

    func cancelConsent() {
        showConsentSheet = false
    }

    func clearConsent() {
        UserDefaults.standard.removeObject(forKey: consentKey)
        UserDefaults.standard.removeObject(forKey: onboardingKey)
        hasCompletedOnboarding = false
        cachedConsent = nil
        cachedConsentKey = nil
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardingKey)
    }
}
