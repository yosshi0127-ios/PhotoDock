//
//  ScanProgressPolicy.swift
//  PhotoDock
//

/// 診断の残り時間の見積もり。純粋関数のみ。
///
/// 式は「実際に診断した枚数 ÷ 経過時間」で出した速さを、これから診断する枚数に掛けるだけ（brief「診断中の表示」）。
/// **一瞬で終わる写真は、速さにも残りにも数えない**:
/// - 記録を再利用した写真（診断しない）
/// - iCloud にあって端末に無い写真（取れないことがすぐ分かる）
///
/// 混ぜて平均すると、写真の並びで見積もりがぶれる。実機（3,053枚・うち iCloud のみ 2,169枚）では、
/// 端末にある新しい写真が先に流れるので、開始直後に「あと約 6 分」と出て 2 分で終わった
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
    ///   - diagnosedNow: 今回の診断で実際に診断した枚数（`takesTime` が true の結果だけ）
    ///   - remaining: これから実際に診断する見込みの枚数
    ///   - elapsedSeconds: 診断を始めてからの経過秒
    func remainingSeconds(diagnosedNow: Int, remaining: Int, elapsedSeconds: Double) -> Double? {
        guard remaining > 0, diagnosedNow >= minimumSamples, elapsedSeconds >= minimumElapsedSeconds else {
            return nil
        }
        return elapsedSeconds / Double(diagnosedNow) * Double(remaining)
    }

    /// 時間のかかる結果か。画像を取り出して読んだもの（と、取り寄せを試したもの）だけが true。
    /// 端末に無い・見つからない写真は、画像を読む前に分かるので false
    func takesTime(_ outcome: ScanRecord.Outcome) -> Bool {
        switch outcome {
        case .scanned, .failed, .unavailableInCloud: true
        case .notAvailableLocally, .missing: false
        }
    }
}
