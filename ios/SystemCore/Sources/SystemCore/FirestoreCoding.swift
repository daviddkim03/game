import Foundation

/// Converts between plain JSON and the typed values Firestore's REST API uses.
enum FirestoreCoding {
    private static let maxSafeInteger = 9_007_199_254_740_992.0

    static func encode(_ value: JSONValue) -> JSONValue {
        switch value {
        case .null:
            return ["nullValue": nil]
        case .bool(let flag):
            return ["booleanValue": .bool(flag)]
        case .number(let number):
            // Whole numbers go up as integers, as the website's SDK sends them.
            if number == number.rounded(), abs(number) < maxSafeInteger {
                return ["integerValue": .string(String(Int64(number)))]
            }
            return ["doubleValue": .number(number)]
        case .string(let text):
            return ["stringValue": .string(text)]
        case .array(let items):
            return ["arrayValue": ["values": .array(items.map(encode))]]
        case .object(let fields):
            return ["mapValue": ["fields": .object(fields.mapValues(encode))]]
        }
    }

    static func decode(_ typed: JSONValue) -> JSONValue {
        guard let (type, inner) = typed.objectValue?.first else { return .null }
        switch type {
        case "booleanValue":
            return inner
        case "integerValue", "doubleValue":
            return inner.doubleValue.map(JSONValue.number) ?? .null
        case "stringValue", "timestampValue", "referenceValue", "bytesValue":
            return inner
        case "arrayValue":
            return .array((inner["values"]?.arrayValue ?? []).map(decode))
        case "mapValue":
            return .object(decodeFields(inner["fields"]))
        default:
            return .null
        }
    }

    static func decodeFields(_ fields: JSONValue?) -> [String: JSONValue] {
        (fields?.objectValue ?? [:]).mapValues(decode)
    }
}
