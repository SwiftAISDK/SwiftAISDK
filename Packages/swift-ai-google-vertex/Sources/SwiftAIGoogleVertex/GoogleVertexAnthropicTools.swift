import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIAnthropic

public enum GoogleVertexAnthropicTools {
    public static func bash_20241022() -> JSONValue { AnthropicTools.bash_20241022() }
    public static func bash_20250124() -> JSONValue { AnthropicTools.bash_20250124() }
    public static func computer_20241022(displayWidthPx: Int, displayHeightPx: Int, displayNumber: Int? = nil) -> JSONValue {
        AnthropicTools.computer_20241022(displayWidthPx: displayWidthPx, displayHeightPx: displayHeightPx, displayNumber: displayNumber)
    }
    public static func textEditor_20241022() -> JSONValue { AnthropicTools.textEditor_20241022() }
    public static func textEditor_20250124() -> JSONValue { AnthropicTools.textEditor_20250124() }
    public static func textEditor_20250429() -> JSONValue { AnthropicTools.textEditor_20250429() }
    public static func textEditor_20250728(maxCharacters: Int? = nil) -> JSONValue { AnthropicTools.textEditor_20250728(maxCharacters: maxCharacters) }
    public static func webSearch_20250305(maxUses: Int? = nil, allowedDomains: [String]? = nil, blockedDomains: [String]? = nil, userLocation: JSONValue? = nil) -> JSONValue {
        AnthropicTools.webSearch_20250305(maxUses: maxUses, allowedDomains: allowedDomains, blockedDomains: blockedDomains, userLocation: userLocation)
    }
    public static func toolSearchRegex_20251119() -> JSONValue { AnthropicTools.toolSearchRegex_20251119() }
    public static func toolSearchBm25_20251119() -> JSONValue { AnthropicTools.toolSearchBm25_20251119() }
}
