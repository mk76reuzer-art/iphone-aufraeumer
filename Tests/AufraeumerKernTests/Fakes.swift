import Foundation
@testable import AufraeumerKern

enum FakeFehler: Error { case export, ablegen, nutzerAbbruch }

/// Thread-sichere Ereignisliste, damit die Reihenfolge der Aufrufe geprüft werden kann.
final class Ereignisse: @unchecked Sendable {
    private let lock = NSLock()
    private var _liste: [String] = []
    func add(_ s: String) { lock.lock(); _liste.append(s); lock.unlock() }
    var liste: [String] { lock.lock(); defer { lock.unlock() }; return _liste }
    func index(_ s: String) -> Int? { liste.firstIndex(of: s) }
    func enthaeltPraefix(_ p: String) -> Bool { liste.contains { $0.hasPrefix(p) } }
}

final class FakeBibliothek: MedienBibliothek, @unchecked Sendable {
    let log: Ereignisse
    var exportFehlerFuer: Set<String> = []
    var loeschFehler: Error?
    init(log: Ereignisse) { self.log = log }

    func exportieren(id: String) async throws -> Export {
        if exportFehlerFuer.contains(id) { throw FakeFehler.export }
        log.add("export:\(id)")
        return Export(datei: URL(fileURLWithPath: "/nicht-vorhanden/\(id)"), bytes: 1000, pruefsumme: "sum-\(id)")
    }

    func loeschen(ids: [String]) async throws {
        log.add("loeschen:\(ids.joined(separator: ","))")
        if let f = loeschFehler { throw f }
    }
}

final class FakeSicherung: Sicherung, @unchecked Sendable {
    var kopieBytesAbweichung: Int64 = 0
    var kopieSummeVerfaelscht: Set<String> = []
    /// Nach wie vielen Nachfragen „hochgeladen“ gemeldet wird; `Int.max` = nie.
    var hochgeladenNach = 1
    private var nachfragen: [String: Int] = [:]

    func ablegen(_ export: Export, name: String) async throws -> SicherungsBeleg {
        SicherungsBeleg(kennung: export.pruefsumme)
    }

    func kopieLesen(_ beleg: SicherungsBeleg) async throws -> KopieInfo {
        KopieInfo(bytes: 1000 + kopieBytesAbweichung,
                  pruefsumme: kopieSummeVerfaelscht.contains(beleg.kennung) ? "verfaelscht" : beleg.kennung)
    }

    func istHochgeladen(_ beleg: SicherungsBeleg) async throws -> Bool {
        nachfragen[beleg.kennung, default: 0] += 1
        return nachfragen[beleg.kennung]! >= hochgeladenNach
    }
}
