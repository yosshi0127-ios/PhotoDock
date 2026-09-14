//
//  ContinuedProcessingService.swift
//  PhotoDock
//

import Foundation

/// 前面で始めた長い処理を、ユーザーがアプリを離れた後も OS に止められずに続けるための申告。
/// 実装は BackgroundTasks（BGContinuedProcessingTask）。
///
/// 申告は「加速」ではなく「延命」。申告できない環境でも処理の結果は変わらないので、
/// 呼び手は nil を受けたら前面での処理をそのまま続ける（申告できないことを失敗として扱わない）。
/// OS は進捗を Live Activity に出し、ユーザーはそこから中止できる。
protocol ContinuedProcessingService: Sendable {
    /// 継続を OS に申告し、進捗を報告するためのハンドルを返す。申告できなければ nil。
    /// - Parameter onExpire: OS が処理を打ち切るとき（ユーザーの中止・資源不足）に1回だけ呼ばれる。
    ///   呼び手はここで処理を止める。呼ばれた後の report / end は無視される
    func begin(
        _ work: ContinuedWork,
        onExpire: @escaping @Sendable () -> Void
    ) async -> ContinuedProcessingSession?
}
