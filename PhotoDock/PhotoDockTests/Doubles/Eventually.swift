//
//  Eventually.swift
//  PhotoDockTests
//

import Foundation

/// 「決まった時間だけ待ってから確かめる」をやめるための待ち方。
///
/// 固定の `Task.sleep` は、速い環境では無駄に待ち、遅い環境（CI のランナー）では足りずに落ちる。
/// 条件が成り立つまで・値が落ち着くまで待ち、上限を超えたら諦めて呼び出し側の `#expect` に落とさせる。
enum Eventually {
    /// 条件が成り立つまで待つ。上限までに成り立たなければ false
    static func holds(
        within timeout: Duration = .seconds(10),
        pollingEvery interval: Duration = .milliseconds(10),
        _ condition: () async -> Bool
    ) async -> Bool {
        let deadline = ContinuousClock.now + timeout

        while ContinuousClock.now < deadline {
            if await condition() { return true }
            try? await Task.sleep(for: interval)
        }
        return await condition()
    }

    /// 値が変わらなくなるまで待ち、落ち着いた値を返す（「止まったこと」を確かめるため）。
    /// `quietChecks` 回続けて同じ値なら落ち着いたとみなす。上限までに落ち着かなければ最後の値を返す
    /// — 止まらない実装なら値が増え切るので、呼び出し側の上限チェックで落ちる
    static func settledValue<Value: Equatable>(
        within timeout: Duration = .seconds(10),
        pollingEvery interval: Duration = .milliseconds(50),
        quietChecks: Int = 4,
        _ value: () async -> Value
    ) async -> Value {
        let deadline = ContinuousClock.now + timeout
        var last = await value()
        var quiet = 0

        while quiet < quietChecks, ContinuousClock.now < deadline {
            try? await Task.sleep(for: interval)
            let current = await value()
            quiet = current == last ? quiet + 1 : 0
            last = current
        }
        return last
    }
}
