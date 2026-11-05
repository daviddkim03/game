import Foundation

/// A JSON document. Cloud data stays in this form between reads and saves, so
/// fields this app does not model (for example, ones the website adds later)
/// survive a round trip.
public enum JSONValue: Hashable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
}

extension JSONValue {
    public subscript(key: String) -> JSONValue? {
        if case .object(let fields) = self { return fields[key] }
        return nil
    }

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    /// Numbers, plus the numeric strings older versions of the site saved.
    public var doubleValue: Double? {
        switch self {
        case .number(let value): return value.isFinite ? value : nil
        case .string(let value): return Double(value.trimmingCharacters(in: .whitespaces))
        default: return nil
        }
    }

    public var intValue: Int? {
        doubleValue.flatMap { Int(exactly: $0.rounded()) }
    }

    public var arrayValue: [JSONValue]? {
        if case .array(let items) = self { return items }
        return nil
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let fields) = self { return fields }
        return nil
    }

    /// A list of whole numbers, ignoring anything that is not one.
    public var intsValue: [Int] {
        (arrayValue ?? []).compactMap(\.intValue)
    }

    /// Lays this value over `base`, keeping whatever only `base` has. Lists
    /// keep this value's order and membership, with items matched by `id` so
    /// each one holds on to its own unknown fields.
    public func merged(over base: JSONValue?, replacing: Set<String> = []) -> JSONValue {
        switch (self, base) {
        case (.object(let overlay), .object(let original)?):
            var result = original
            for (key, value) in overlay {
                result[key] = replacing.contains(key) ? value : value.merged(over: original[key])
            }
            return .object(result)
        case (.array(let overlay), .array(let original)?):
            var byId: [JSONValue: JSONValue] = [:]
            for item in original {
                if let id = item["id"], byId[id] == nil { byId[id] = item }
            }
            return .array(
                overlay.map { item in
                    guard let id = item["id"], let match = byId[id] else { return item }
                    return item.merged(over: match)
                })
        default:
            return self
        }
    }
}

extension JSONValue: ExpressibleByNilLiteral, ExpressibleByBooleanLiteral,
    ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByStringLiteral,
    ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral
{
    public init(nilLiteral: ()) { self = .null }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
    public init(floatLiteral value: Double) { self = .number(value) }
    public init(stringLiteral value: String) { self = .string(value) }
    public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { _, last in last }))
    }
}

extension JSONValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

/// A value stored as one cloud document.
public protocol CloudValue: Hashable, Sendable {
    /// Upgrades saved data, or returns nil when it is unusable.
    init?(json: JSONValue)
    func toJSON() -> JSONValue
    /// What a brand new document holds.
    static var empty: Self { get }
    /// Top-level keys saved as they are, for maps entries get deleted from.
    static var replacedKeys: Set<String> { get }
}

extension CloudValue {
    public static var replacedKeys: Set<String> { [] }
}
