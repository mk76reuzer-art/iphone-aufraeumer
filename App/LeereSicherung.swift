import Foundation
import AufraeumerKern

/// Nur für Läufe ohne Sicherungspflicht; wird von `Loeschlauf` nicht aufgerufen.
struct LeereSicherung: Sicherung, Sendable {
    func ablegen(_ export: Export, name: String) async throws -> SicherungsBeleg {
        SicherungsBeleg(kennung: export.pruefsumme)
    }

    func kopieLesen(_ beleg: SicherungsBeleg) async throws -> KopieInfo {
        KopieInfo(bytes: 0, pruefsumme: beleg.kennung)
    }

    func istHochgeladen(_ beleg: SicherungsBeleg) async throws -> Bool { true }
}
