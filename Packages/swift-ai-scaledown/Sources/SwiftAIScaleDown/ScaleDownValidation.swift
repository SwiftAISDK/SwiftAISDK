import Foundation
import SwiftAIProvider

struct ScaleDownSchemaError: Error {}

func scaleDownOptionalNumber(_ value: JSONValue?) throws -> Double? {
    guard let value, value != .null else { return nil }
    guard let number = value.doubleValue, number.isFinite else { throw ScaleDownSchemaError() }
    return number
}
func scaleDownOptionalString(_ value: JSONValue?) throws -> String? {
    guard let value, value != .null else { return nil }
    guard let string = value.stringValue else { throw ScaleDownSchemaError() }
    return string
}
func scaleDownOptionalObject(_ value: JSONValue?) throws -> [String: JSONValue]? {
    guard let value, value != .null else { return nil }
    guard let object = value.objectValue else { throw ScaleDownSchemaError() }
    return object
}
func scaleDownTokenCount(_ value: JSONValue?) throws -> Int? {
    guard let number = try scaleDownOptionalNumber(value) else { return nil }
    // Swift's usage contract is integral; preserve every representable upstream count.
    guard let count = Int(exactly: number) else { throw ScaleDownSchemaError() }
    return count
}

/// Retains the exact inner content when ScaleDown returns invalid extraction JSON.
public struct ScaleDownInvalidExtractionContentError: Error, Equatable, CustomStringConvertible, Sendable {
    public var data: String
    public let message = "ScaleDown did not return valid extraction content."
    public var description: String { message }
    public init(data: String) { self.data = data }
}
