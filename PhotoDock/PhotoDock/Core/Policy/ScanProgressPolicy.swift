//
//  ScanProgressPolicy.swift
//  PhotoDock
//

/// 診断の残り時間の見積もり。純粋関数のみ。
///
/// 式は「実際に診断した枚数 ÷ 経過時間」で出した速さを、これから診断する枚数に掛けるだけ（brief「診断中の表示」）。
/// **すぐ終わる写真は、速さの計算に入れない**:
/// - 記録を再利用した写真（診断しない）
/// - iCloud にあって端末に無い写真（取れないことがすぐ分かる）
///
/// 後者は「すぐ」でも 0 ではないので、残りには決まった秒数（`quickSecondsPerPhoto`）で足す
///
/// 混ぜて平均すると、写真の並びで見積もりがぶれる。実機（3,053枚・うち iCloud のみ 2,169枚）では、
/// 端末にある新しい写真が先に流れるので、開始直後に「あと約 6 分」と出て 2 分で終わった
struct ScanProgressPolicy: Sendable {
    /// 見積もりを出し始める枚数。数枚では1枚ごとのばらつき（文字の多い写真は遅い）がそのまま出る
    let minimumSamples: Int
    /// 見積もりを出し始める経過秒。開始直後は記録の読み込みが混ざって速さが安定しない
    let minimumElapsedSeconds: Double
    /// 端末に無い写真1枚が「取れない」と分かるまでの秒数。
    /// 実機（iPhone 15 Pro Max・2026-11-26）で 2,169枚に 25秒 = 1枚 約 0.012秒。
    /// 0 として扱うと、端末の写真を診断し終えたあとの 25秒が見積もりから抜け、最後に「あと 1 分以内」が長く続く
    let quickSecondsPerPhoto: Double

    init(minimumSamples: Int = 10, minimumElapsedSeconds: Double = 3, quickSecondsPerPhoto: Double = 0.012) {
        self.minimumSamples = minimumSamples
        self.minimumElapsedSeconds = minimumElapsedSeconds
        self.quickSecondsPerPhoto = quickSecondsPerPhoto
    }

    /// 残りの秒数。まだ見積もれない・残りが無いときは nil（画面には出さない）
    /// - Parameters:
    ///   - diagnosedNow: 今回の診断で実際に診断した枚数（`takesTime` が true の結果だけ）
    ///   - remainingToDiagnose: これから実際に診断する見込みの枚数
    ///   - remainingQuick: 残りのうち、すぐ終わる見込みの枚数（端末に無い写真）
    ///   - elapsedSeconds: 診断を始めてからの経過秒
    func remainingSeconds(
        diagnosedNow: Int,
        remainingToDiagnose: Int,
        remainingQuick: Int,
        elapsedSeconds: Double
    ) -> Double? {
        let toDiagnose = max(0, remainingToDiagnose)
        let quick = max(0, remainingQuick)
        guard toDiagnose + quick > 0 else { return nil }

        let quickSeconds = Double(quick) * quickSecondsPerPhoto
        // 診断する写真が残っていなければ、速さを測るまでもない
        guard toDiagnose > 0 else { return quickSeconds }

        guard diagnosedNow >= minimumSamples, elapsedSeconds >= minimumElapsedSeconds else { return nil }
        return elapsedSeconds / Double(diagnosedNow) * Double(toDiagnose) + quickSeconds
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
