import Foundation

struct MathInkSample: Identifiable, Codable, Equatable {
    var id: UUID
    var latex: String
    var sourceText: String
    var computeExpression: String
    var astJSONFileName: String?
    var status: SampleStatus
    var drawingDataFileName: String?
    var imageFileName: String?
    var canvasWidth: Double
    var canvasHeight: Double
    var createdAt: Date
    var modifiedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case latex
        case sourceText
        case computeExpression
        case astJSONFileName
        case status
        case drawingDataFileName
        case imageFileName
        case canvasWidth
        case canvasHeight
        case createdAt
        case modifiedAt
    }

    init(
        id: UUID,
        latex: String,
        sourceText: String,
        computeExpression: String,
        astJSONFileName: String?,
        status: SampleStatus,
        drawingDataFileName: String?,
        imageFileName: String?,
        canvasWidth: Double,
        canvasHeight: Double,
        createdAt: Date,
        modifiedAt: Date
    ) {
        self.id = id
        self.latex = latex
        self.sourceText = sourceText
        self.computeExpression = computeExpression
        self.astJSONFileName = astJSONFileName
        self.status = status
        self.drawingDataFileName = drawingDataFileName
        self.imageFileName = imageFileName
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        latex = try container.decode(String.self, forKey: .latex)
        sourceText = try container.decodeIfPresent(String.self, forKey: .sourceText) ?? ""
        computeExpression = try container.decodeIfPresent(String.self, forKey: .computeExpression) ?? ""
        astJSONFileName = try container.decodeIfPresent(String.self, forKey: .astJSONFileName)
        status = try container.decode(SampleStatus.self, forKey: .status)
        drawingDataFileName = try container.decodeIfPresent(String.self, forKey: .drawingDataFileName)
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        canvasWidth = try container.decode(Double.self, forKey: .canvasWidth)
        canvasHeight = try container.decode(Double.self, forKey: .canvasHeight)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
    }
}
