//
//  ScanProgressPolicy.swift
//  PhotoDock
//

/// 診断の残り時間の見積もり。純粋関数のみ。
///
/// 式は「今回診断した枚数 ÷ 経過時間」で出した速さを、残りの枚数に掛けるだけ（brief「診断中の表示」）。
/// **記録を再利用した写真は数に入れない**。再利用の分は一瞬で流れるので、入れると
/// 「2,000 枚を 1 秒で終えた」速さで残りを見積もり、ほぼ 0 秒と出てしまう
struct ScanProgressPolicy: Sendable {
    /// 見積もりを出し始める枚数。数枚では1枚ごとのばらつき（文字の多い写真は遅い）がそのまま出る
    let minimumSamples: Int
    /// 見積もりを出し始める経過秒。開始直後は記録の読み込みが混ざって速さが安定しない
    let minimumElapsedSeconds: Double

    init(minimumSamples: Int = 10, minimumElapsedSeconds: Double = 3) {
        self.minimumSamples = minimumSamples
        self.minimumElapsedSeconds = minimumElapsedSeconds
    }

    /// 残りの秒数。まだ見積もれない・残りが無いときは nil（画面には出さない）
    /// - Parameters:
    ///   - diagnosedNow: 今回の診断で実際に処理した枚数（記録の再利用を除く）
    ///   - remaining: まだ結果が出ていない枚数
    ///   - elapsedSeconds: 診断を始めてからの経過秒
    func remainingSeconds(diagnosedNow: Int, remaining: Int, elapsedSeconds: Double) -> Double? {
        guard remaining > 0, diagnosedNow >= minimumSamples, elapsedSeconds >= minimumElapsedSeconds else {
            return nil
        }
        return elapsedSeconds / Double(diagnosedNow) * Double(remaining)
    }
}
