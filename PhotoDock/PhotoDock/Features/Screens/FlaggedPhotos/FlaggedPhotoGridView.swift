//
//  FlaggedPhotoGridView.swift
//  PhotoDock
//

import SwiftUI

/// 所見のあった写真の一覧。タップで写真詳細へ。
/// LazyVGrid なので、サムネイルの読み込みは画面に出たセルだけで走る。
struct FlaggedPhotoGridView: View {
    let photos: [ScannedPhoto]

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 4)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(photos, id: \.assetID) { photo in
                    NavigationLink {
                        PhotoDetailView(assetID: photo.assetID)
                    } label: {
                        FlaggedPhotoCell(photo: photo)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
        }
        .navigationTitle("所見のある写真")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        FlaggedPhotoGridView(photos: (0..<12).map { index in
            ScannedPhoto(
                assetID: "stub-\(index * 7)",
                outcome: .scanned([
                    Finding(
                        kind: index.isMultiple(of: 3) ? .cardNumber : .address,
                        severity: index.isMultiple(of: 3) ? .danger : .caution,
                        region: Region(x: 0, y: 0, width: 1, height: 1),
                        maskedText: "***"
                    )
                ])
            )
        })
    }
}
