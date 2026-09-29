import Foundation

public enum Aktion: String, Codable, Sendable {
    case beabsichtigt, geloescht, abgebrochen, gesichert
}

public struct ProtokollEintrag: Codable, Equatable, Sendable {
    public let zeit: Date
    public let id: String
    public let name: String
    public let groesseBytes: Int64
    public let aktion: Aktion
    public let grund: String?

    public init(zeit: Date, id: String, name: String, groesseBytes: Int64,
                aktion: Aktion, grund: String?) {
        self.zeit = zeit
        self.id = id
        self.name = name
        self.groesseBytes = groesseBytes
        self.aktion = aktion
        self.grund = grund
    }
}

public struct Protokoll: Codable, Equatable, Sendable {
    public private(set) var eintraege: [ProtokollEintrag] = []

    public init() {}

    public mutating func hinzufuegen(_ eintrag: ProtokollEintrag) {
        eintraege.append(eintrag)
    }

    public func json() throws -> Data {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(self)
    }

    public static func aus(json: Data) throws -> Protokoll {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try dec.decode(Protokoll.self, from: json)
    }

    public func csv() -> String {
        let format = ISO8601DateFormatter()
        format.formatOptions = [.withInternetDateTime]
        var zeilen = ["Zeit;ID;Name;Groesse_Bytes;Aktion;Grund"]
        for e in eintraege {
            let felder = [format.string(from: e.zeit), e.id, e.name, String(e.groesseBytes),
                          e.aktion.rawValue, e.grund ?? ""]
            zeilen.append(felder.map(Protokoll.feld).joined(separator: ";"))
        }
        return zeilen.joined(separator: "\n")
    }

    /// Hinweis: `\r\n` ist in Swift ein einzelnes Zeichen, deshalb wird über Unicode-Skalare geprüft.
    static func feld(_ s: String) -> String {
        let braucht = s.unicodeScalars.contains { $0 == ";" || $0 == "\"" || $0 == "\n" || $0 == "\r" }
        guard braucht else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
