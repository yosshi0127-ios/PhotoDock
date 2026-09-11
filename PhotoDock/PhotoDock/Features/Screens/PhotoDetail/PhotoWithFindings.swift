//
//  PhotoWithFindings.swift
//  PhotoDock
//

import SwiftUI

/// 写真に所見の枠を重ねたもの。
/// .resizable().scaledToFit() で Image のレイアウトサイズが実描画矩形と等しくなるため、
/// overlay した枠の座標がレターボックスの余白に影響されない。この2つは外せない。
struct PhotoWithFindings: View {
    let image: UIImage
    let findings: [StoredFinding]

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .overlay { FindingOverlay(findings: findings) }
    }
}
