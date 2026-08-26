import EMathicaMathInputCore
import Foundation
import XCTest
@testable import OpenMathInkCollector

@MainActor
final class CollectorStorageCompatibilityTests: XCTestCase {
    func testLegacySampleWithoutASTRestoresThroughLatexIn() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalSampleStore(baseURL: root)
        let sample = legacySample(latex: "\\frac{1}{2}+\\sqrt{x}")
        try store.persistSampleIndex([sample])

        let workspace = CollectorWorkspaceState(store: store)
        try await waitForSelection(workspace, expected: sample.id)

        XCTAssertEqual(workspace.selectedSampleID, sample.id)
        XCTAssertTrue(workspace.currentLatex.contains("\\frac"))
        XCTAssertTrue(workspace.currentLatex.contains("\\sqrt"))
        XCTAssertNil(workspace.errorMessage)
    }

    func testInvalidLegacyLatexReportsErrorWithoutOverwritingStoredSample() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalSampleStore(baseURL: root)
        let invalidLatex = "\\frac{"
        let sample = legacySample(latex: invalidLatex)
        try store.persistSampleIndex([sample])

        let workspace = CollectorWorkspaceState(store: store)
        try await waitForSelection(workspace, expected: sample.id)

        XCTAssertEqual(workspace.currentLatex, invalidLatex)
        XCTAssertNotNil(workspace.errorMessage)
        XCTAssertEqual(try store.loadSamples().first?.latex, invalidLatex)
    }

    func testSaveRestartAndExportPreserveV2DatasetContract() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalSampleStore(baseURL: root)
        let workspace = CollectorWorkspaceState(store: store)
        try await waitForAnySelection(workspace)

        workspace.applyKeyboardAction(.insertTemplate(.fraction))
        workspace.applyKeyboardAction(.insertCharacter("1"))
        workspace.applyKeyboardAction(.tab)
        workspace.applyKeyboardAction(.insertCharacter("2"))
        workspace.saveCurrentDraft()

        let savedID = try XCTUnwrap(workspace.selectedSampleID)
        let saved = try XCTUnwrap(workspace.selectedSample)
        XCTAssertNotNil(saved.astJSONFileName)

        let restarted = CollectorWorkspaceState(store: store)
        try await waitForSelection(restarted, expected: savedID)
        XCTAssertEqual(restarted.currentLatex, workspace.currentLatex)
        XCTAssertEqual(restarted.currentSourceText, workspace.currentSourceText)

        let exportRoot = root.appendingPathComponent("export", isDirectory: true)
        let packageURL = try DatasetPackageBuilder().buildPackage(
            samples: [saved],
            store: store,
            targetDirectory: exportRoot,
            consent: ContributorConsent(
                agreedAt: Date(),
                voluntaryContribution: true,
                allowsOpenSourceDatasetSharing: true,
                acknowledgesNoAutoUpload: true
            )
        )

        let manifestURL = packageURL.appendingPathComponent("manifest.json")
        let sampleURL = packageURL
            .appendingPathComponent("samples", isDirectory: true)
            .appendingPathComponent("sample_000001.json")
        let astURL = packageURL
            .appendingPathComponent("samples", isDirectory: true)
            .appendingPathComponent("sample_000001.ast.json")

        XCTAssertTrue(FileManager.default.fileExists(atPath: manifestURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sampleURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: astURL.path))

        let manifest = try JSONSerialization.jsonObject(
            with: Data(contentsOf: manifestURL)
        ) as? [String: Any]
        XCTAssertEqual(manifest?["formatVersion"] as? String, "openmathink.sample.v2")
        XCTAssertEqual(manifest?["supportsAST"] as? Bool, true)

        let payload = try JSONSerialization.jsonObject(
            with: Data(contentsOf: sampleURL)
        ) as? [String: Any]
        XCTAssertEqual(payload?["latex"] as? String, saved.latex)
        XCTAssertEqual(payload?["sourceText"] as? String, saved.sourceText)
        XCTAssertEqual(payload?["computeExpression"] as? String, saved.computeExpression)
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func legacySample(latex: String) -> MathInkSample {
        MathInkSample(
            id: UUID(),
            latex: latex,
            sourceText: latex,
            computeExpression: latex,
            astJSONFileName: nil,
            status: .draft,
            drawingDataFileName: nil,
            imageFileName: nil,
            canvasWidth: 1024,
            canvasHeight: 512,
            createdAt: Date(),
            modifiedAt: Date()
        )
    }

    private func waitForAnySelection(
        _ workspace: CollectorWorkspaceState
    ) async throws {
        for _ in 0..<50 where workspace.selectedSampleID == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertNotNil(workspace.selectedSampleID)
    }

    private func waitForSelection(
        _ workspace: CollectorWorkspaceState,
        expected: UUID
    ) async throws {
        for _ in 0..<50 where workspace.selectedSampleID != expected {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(workspace.selectedSampleID, expected)
    }
}
