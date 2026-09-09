//
//  FindingListView.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/09.
//

import SwiftUI

/// 所見のリスト。写真の枠（FindingOverlay）と対になる、読み上げ可能な本体。
struct FindingListView: View {
    let findings: [Finding]
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(findings.indices, id: \.self) { index in
                row(findings[index])
            }
        }
    }

    private func row(_ finding: Finding) -> some View {
        HStack(spacing: 12) {
            Image(systemName: finding.severity.icon)
                .foregroundStyle(finding.severity.tint)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(finding.kind.label)
                    .font(.headline)
                Text(finding.maskedText)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            
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
        Finding(
            kind: .cardNumber,
            severity: .danger,
            region: Region(x: 0, y: 0, width: 1, height: 1),
            maskedText: "•••• •••• •••• 1234"
        ),
        Finding(
            kind: .address,
            severity: .caution,
            region: Region(x: 0, y: 0, width: 1, height: 1),
            maskedText: "東京都◯◯区◯◯ ◯-◯"
        )
    ])
    .padding()
}

#Preview("1件") {
    FindingListView(findings: [
        Finding(
            kind: .credential,
            severity: .danger,
            region: Region(x: 0, y: 0, width: 1, height: 1),
            maskedText: "パスワード: ••••••••"
        )
    ])
    .padding()
}
