import EMathicaFormulaDisplayCore
import EMathicaMathInputCore
import XCTest
@testable import OpenMathInkCollector

@MainActor
final class CollectorFormulaDisplayTests: XCTestCase {
    func testEmptyFormulaIncludesCursorAndInsertionMarker() {
        let state = CollectorMathInputState()
        let serialized = FormulaDisplayDocumentSerializer.serialize(state.displayDocument)

        XCTAssertTrue(serialized.contains("\\cursor{}"))
        XCTAssertTrue(serialized.contains("\\eminsertion{}"))
    }

    func testStructuredTemplatesProduceDisplayDocuments() {
        let cases: [(EditorTemplateKind, String, Bool)] = [
            (.fraction, "\\frac{", true),
            (.sqrt, "\\sqrt{", false),
            (.nthRoot, "\\sqrt[", true),
            (.superscript, "^{", true),
            (.subscriptTemplate, "_{", true),
            (.matrix(rows: 2, cols: 2), "\\begin{pmatrix}", true),
            (.piecewise(rows: 2), "\\begin{cases}", true)
        ]

        for (template, expectedMarkup, expectsPlaceholder) in cases {
            let state = CollectorMathInputState()
            state.apply(.insertTemplate(template))
            let serialized = FormulaDisplayDocumentSerializer.serialize(
                state.displayDocument
            )

            XCTAssertTrue(
                serialized.contains(expectedMarkup),
                "Display projection for \(template) was \(serialized)"
            )
            if expectsPlaceholder {
                XCTAssertTrue(
                    serialized.contains("\\placeholder{}"),
                    "Display projection for \(template) omitted empty-field placeholders"
                )
            }
            XCTAssertTrue(
                serialized.contains("\\cursor{}"),
                "Display projection for \(template) omitted the editor cursor"
            )
        }
    }

    func testASTJSONRoundTripPreservesEditorTruthAndDisplayProjection() throws {
        let original = CollectorMathInputState()
        original.apply(.insertTemplate(.fraction))
        original.apply(.insertCharacter("1"))
        original.apply(.tab)
        original.apply(.insertTemplate(.sqrt))
        original.apply(.insertCharacter("x"))

        let fixture = try original.exportASTJSON(prettyPrinted: true)
        let restored = CollectorMathInputState()
        try restored.importASTJSON(fixture)

        XCTAssertEqual(restored.latex, original.latex)
        XCTAssertEqual(restored.sourceText, original.sourceText)
        XCTAssertEqual(restored.computeExpression, original.computeExpression)
        XCTAssertEqual(restored.displayDocument, original.displayDocument)
    }

    func testFailedLatexImportDoesNotReplaceExistingEditorState() {
        let state = CollectorMathInputState()
        state.apply(.insertCharacter("x"))
        let before = state.displayDocument

        XCTAssertFalse(state.replaceWithLatex("\\frac{"))
        XCTAssertEqual(state.sourceText, "x")
        XCTAssertEqual(state.displayDocument, before)
    }
}
