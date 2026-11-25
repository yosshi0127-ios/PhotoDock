//
//  FindingRulesVersionTests.swift
//  PhotoDockTests
//

import Testing
@testable import PhotoDock

/// 判定ルールの版（`FindingRules.version`）の上げ忘れを見つけるためのテスト。
///
/// スキャン済み記録は判定ルールの版を含む世代を持ち、版が変わると診断し直される。
/// ルールを変えたのに版を上げないと、記録済みの写真には古い判定が残り続ける。
///
/// **このテストが落ちたら**: 代表的な行の判定結果が変わっている。意図した変更なら
/// 1. `FindingRules.version` を1つ上げる
/// 2. 下の `expectedVersion` を同じ値にする
/// 3. 変わった行の期待値を更新する
/// の3つを同じコミットで行う。意図していない変更なら、ルールの変更を見直す。
///
/// 個々のルールの正しさは `FindingPolicyTests` が持つ。ここは「変わったこと」だけを見る
@Suite("FindingRules.version")
struct FindingRulesVersionTests {
    /// 下の期待値を記録したときの判定ルールの版
    private static let expectedVersion = 1

    /// 代表的な行と、その判定（`種類/危険度`。所見なしは `-`）
    private static let expected: [(line: String, verdict: String)] = [
        ("4242 4242 4242 4242", "cardNumber/danger"),
        ("4111 1111 1111 1111 12/28", "cardNumber/danger"),
        ("3782 822463 10005", "cardNumber/danger"),
        ("No.401288888888188112/28", "cardNumber/danger"),
        ("1234 5678 1234 5670", "cardNumber/caution"),
        ("4901234567894", "-"),
        ("9123456789012348", "-"),
        ("4111 1111 / 1111 1111", "-"),
        ("パスワード: hunter2", "credential/danger"),
        ("暗証番号 1234", "credential/danger"),
        ("PASSWORD=correcthorse", "credential/danger"),
        ("API_KEY=abcdEFGHijkl", "credential/danger"),
        ("sk-proj-abcdefghijklmnopqrstuvwxyz", "credential/danger"),
        ("パスワードを忘れた方はこちら", "credential/caution"),
        ("Password: ********", "credential/caution"),
        ("Password must be at least 8 characters", "credential/caution"),
        ("AB1234567", "identityDocumentNumber/caution"),
        ("yamada@example.com", "email/caution"),
        ("連絡先は yamada@example.com です", "email/caution"),
        ("〒160-0023 東京都新宿区西新宿2-8-1", "address/caution"),
        ("大阪市北区梅田1丁目2番3号", "address/caution"),
        ("八王子市万町4-5", "address/caution"),
        ("渋谷区神南1ー2ー3", "address/caution"),
        ("横浜市 2026-09-12", "-"),
        ("神南1-2-3", "-"),
        ("渋谷区役所 8:30-17:15", "-"),
        ("090-1234-5678", "phoneNumber/caution"),
        ("08012345678", "phoneNumber/caution"),
        ("TEL 03-1234-5678", "phoneNumber/caution"),
        ("0120-123-456", "phoneNumber/caution"),
        ("050-1234-5678", "phoneNumber/caution"),
        ("渋谷区役所 03-1234-5678", "phoneNumber/caution"),
        ("注文番号 1209012345678", "-"),
        ("発行日 01-02-2026", "-"),
        ("伝票 1203-1234-5678", "-"),
        ("〒150-0041", "postalCode/caution"),
        ("150-0041東京都", "postalCode/caution"),
        ("注文番号 20261119-00123", "-"),
        ("市場1234-5678-9012", "-"),
        ("型番 XR-150-0041", "-"),
        ("０９０－１２３４－５６７８", "phoneNumber/caution"),
        ("ｙａｍａｄａ＠ｅｘａｍｐｌｅ．ｃｏｍ", "email/caution"),
        ("こんにちは", "-"),
        ("合計 12点 ¥3,480", "-"),
        ("2026年11月20日 12:34", "-")
    ]

    @Test("期待値は今の判定ルールの版で記録されたもの")
    func expectationsMatchCurrentVersion() {
        #expect(
            FindingRules.version == Self.expectedVersion,
            "FindingRules.version を変えたら、expectedVersion と期待値も同じコミットで更新する"
        )
    }

    @Test("代表的な行の判定結果が、記録した期待値から変わっていない")
    func verdictsAreUnchanged() {
        let policy = FindingPolicy()

        let changed = Self.expected.compactMap { item -> String? in
            let actual = policy.classify(item.line).map { "\($0.kind)/\($0.severity)" } ?? "-"
            return actual == item.verdict ? nil : "\(item.line): \(item.verdict) → \(actual)"
        }

        #expect(
            changed.isEmpty,
            "判定結果が変わった。意図した変更なら FindingRules.version を上げて期待値を更新する: \(changed)"
        )
    }
}
