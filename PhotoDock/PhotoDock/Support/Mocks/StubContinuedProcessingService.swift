//
//  StubContinuedProcessingService.swift
//  PhotoDock
//

/// Preview 用。OS には申告せず、常に「申告できない環境」として nil を返す。
/// 申告は延命であって処理の結果を変えないので、Preview の見た目はこれで成立する
struct StubContinuedProcessingService: ContinuedProcessingService {
    func begin(_ work: ContinuedWork, onExpire: @escaping @Sendable () -> Void) async -> ContinuedProcessingSession? {
        nil
    }
}
