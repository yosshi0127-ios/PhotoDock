//
//  DependencyValues+ContinuedProcessing.swift
//  PhotoDock
//

import Dependencies

// 前面で始めた処理をアプリを離れても続けたいと OS に申告する（BGContinuedProcessingTask）。
// 全量スキャンの開始時に1回申告し、1枚ごとに進捗を報告する。
// preview は「申告できない環境」として振る舞う（nil）。Live Activity は Preview に出ないし、
// 申告は延命であって処理の結果を変えないので、Preview の見た目には関係しない
private enum ContinuedProcessingServiceKey: DependencyKey {
    static let liveValue: any ContinuedProcessingService = BGTaskSchedulerContinuedProcessingService()
    static let previewValue: any ContinuedProcessingService = StubContinuedProcessingService()
    static let testValue: any ContinuedProcessingService = UnimplementedContinuedProcessingService()
}

extension DependencyValues {
    var continuedProcessing: any ContinuedProcessingService {
        get { self[ContinuedProcessingServiceKey.self] }
        set { self[ContinuedProcessingServiceKey.self] = newValue }
    }
}
