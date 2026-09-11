//
//  FindingListView.swift
//  PhotoDock
//

import SwiftUI

/// 所見のリスト。写真の枠（FindingOverlay）と対になる、読み上げ可能な本体。
/// 本文は出さない — 写真そのものが表示されていて枠が場所を示すので、種類と段階で足りる。
struct FindingListView: View {
    let findings: [StoredFinding]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(findings.indices, id: \.self) { index in
                row(findings[index])
            }
        }
    }

    private func row(_ finding: StoredFinding) -> some View {
        HStack(spacing: 12) {
            Image(systemName: finding.severity.icon)
                .foregroundStyle(finding.severity.tint)

            Text(finding.kind.label)
                .font(.headline)

            Spacer()

            Text(finding.severity.label)
                .font(.footnote)
                .foregroundStyle(finding.severity.tint)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("危険と要注意") {
    FindingListView(findings: [
        StoredFinding(kind: .cardNumber, severity: .danger, region: Region(x: 0, y: 0, width: 1, height: 1)),
        StoredFinding(kind: .address, severity: .caution, region: Region(x: 0, y: 0, width: 1, height: 1)),
        StoredFinding(kind: .bystanderFace, severity: .caution, region: Region(x: 0, y: 0, width: 1, height: 1))
    ])
    .padding()
}

#Preview("1件") {
    FindingListView(findings: [
        StoredFinding(kind: .credential, severity: .danger, region: Region(x: 0, y: 0, width: 1, height: 1))
    ])
    .padding()
}
