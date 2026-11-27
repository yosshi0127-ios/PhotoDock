//
//  PhotoZoomView.swift
//  PhotoDock
//

import SwiftUI

/// 写真を、画面いっぱいに出す。写真詳細では、表と一緒に1画面に入るように写真を縮めているので、
/// 細かいところを見たいときはここで見る。所見の枠も一緒に出す
struct PhotoZoomView: View {
    let image: UIImage
    let findings: [StoredFinding]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PhotoWithFindings(image: image, findings: findings)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .overlay(alignment: .topTrailing) {
                Button("閉じる", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(Spacing.s)
                    .background(.black.opacity(0.5), in: .circle)
                    .padding(Spacing.m)
            }
            // 写真のどこを押しても閉じられる
            .onTapGesture { dismiss() }
            .accessibilityAddTraits(.isModal)
    }
}

#Preview {
    PhotoZoomView(image: UIImage(systemName: "photo") ?? UIImage(), findings: [])
}
