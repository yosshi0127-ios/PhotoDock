//
//  DependencyValues+OCR.swift
//  PhotoDock
//

import Dependencies

// 画像のバイト列から文字を読む。第2段スキャンの中核。
// preview は Vision を呼ばず固定結果を返す（本物だと 1,240 枚の Preview が数分固まる）。
private enum OCRServiceKey: DependencyKey {
    static let liveValue: any OCRService = VisionOCRService()
    static let previewValue: any OCRService = StubOCRService()
    static let testValue: any OCRService = UnimplementedOCRService()
}

extension DependencyValues {
    var ocr: any OCRService {
        get { self[OCRServiceKey.self] }
        set { self[OCRServiceKey.self] = newValue }
    }
}
