//
//  StoredFinding.swift
//  PhotoDock
//

/// 保存用の所見。Finding から maskedText を落としたもの。
/// 検出テキスト本文を端末に残さないための型（Finding と分けることで、本文を保存する経路を作れなくする）。
struct StoredFinding: Sendable, Equatable, Codable {
    let kind: FindingKind
    let severity: Severity
    let region: Region

    init(kind: FindingKind, severity: Severity, region: Region) {
        self.kind = kind
        self.severity = severity
        self.region = region
    }

    init(_ finding: Finding) {
        self.init(kind: finding.kind, severity: finding.severity, region: finding.region)
    }
}
