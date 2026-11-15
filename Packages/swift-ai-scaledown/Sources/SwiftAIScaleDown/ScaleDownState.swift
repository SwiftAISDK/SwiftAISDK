import Foundation
import SwiftAIProvider

func scaleDownText(_ value: JSONValue) throws -> String {
    if case let .string(text) = value { return text }
    return try decisionJSONText(value)
}

func scaleDownState(_ state: [AIDecisionStatePart]) throws -> [String: JSONValue] {
    var texts: [String] = [], document: String?, mimeType: String?
    for part in state {
        switch part {
        case let .text(text): texts.append(text)
        case let .json(value): texts.append(try decisionJSONText(value))
        case let .file(type, data, _, _):
            guard document == nil, ["image/jpeg", "image/png", "image/tiff", "application/pdf"].contains(type) else {
                throw AIDecisionUnsupportedFunctionalityError(functionality: "ScaleDown supports one JPEG, PNG, TIFF, or PDF document.")
            }
            switch data {
            case let .data(bytes): document = bytes.base64EncodedString()
            case let .base64(value): document = value
            default: throw AIDecisionUnsupportedFunctionalityError(functionality: "ScaleDown supports one JPEG, PNG, TIFF, or PDF document.")
            }
            mimeType = type
        }
    }
    return ["text": texts.isEmpty ? nil : .string(texts.joined(separator: "\n")),
            "document": document.map(JSONValue.string),
            "document_mime_type": mimeType.map(JSONValue.string)].compactMapValues { $0 }
}

func scaleDownExtractionSource(text entityText: String, start: Int?, end: Int?,
                               state: [AIDecisionStatePart], ocrText: String?) throws -> AIExtractionSource? {
    guard let start, let end, start >= 0, end >= start, entityText.utf8.count == end - start else { return nil }
    var offset = 0, filePart: Int?
    for (index, part) in state.enumerated() {
        let text: String
        switch part {
        case let .text(value): text = value
        case let .json(value): text = try decisionJSONText(value)
        case .file: filePart = index; continue
        }
        let bytes = Array(text.utf8)
        if start >= offset, end <= offset + bytes.count {
            guard case .text = part,
                  let prefix = String(bytes: bytes[0..<(start - offset)], encoding: .utf8),
                  let span = String(bytes: bytes[(start - offset)..<(end - offset)], encoding: .utf8),
                  span.utf8.elementsEqual(entityText.utf8) else { return nil }
            return .text(part: index, start: prefix.utf16.count, end: prefix.utf16.count + span.utf16.count)
        }
        offset += bytes.count + 1
    }
    if let filePart, start >= max(0, offset - 1), ocrText?.range(of: entityText, options: .literal) != nil {
        return .file(part: filePart)
    }
    return nil
}
