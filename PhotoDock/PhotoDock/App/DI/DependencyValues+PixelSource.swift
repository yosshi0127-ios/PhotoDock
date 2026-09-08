//
//  DependencyValues+PixelSource.swift
//  PhotoDock
//

import Dependencies

// 1枚の画像本体（ピクセル）の取得。第2段スキャンの入口。
// preview は文字を描いた合成画像を返すので、Preview でも所見が実際に出る（id から決定的に決まる）。
private enum PixelSourceServiceKey: DependencyKey {
    static let liveValue: any PixelSourceService = PhotoKitPixelSourceService()
    static let previewValue: any PixelSourceService = StubPixelSourceService()
    static let testValue: any PixelSourceService = UnimplementedPixelSourceService()
}

extension DependencyValues {
    var pixelSource: any PixelSourceService {
        get { self[PixelSourceServiceKey.self] }
        set { self[PixelSourceServiceKey.self] = newValue }
    }
}
