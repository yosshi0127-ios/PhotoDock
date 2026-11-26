//
//  FullScanView.swift
//  PhotoDock
//

import SwiftUI

/// 全量スキャン（第2段）。開いた瞬間に走り出し、画面を閉じると止まる。
/// 診断しながら結果票が埋まっていき、所見のあった項目は診断中から開ける
/// （数十分かかる処理なので、終わるまで結果が見えないのは長すぎる）。
/// 項目や写真詳細を開いている間も診断は続く。アプリを離れたときの継続は OS への申告が通ったときだけ
/// （背景で GPU を使う entitlement が要る。詳細は brief「検証済みの事実」）。
struct FullScanView: View {
    let assets: [AssetMetadata]
    let quality: ScanQuality
    /// 「iCloud の写真も診断する」の設定値。回線の判定は UseCase が行う
    let allowsDownload: Bool
    /// 実際に診断する見込みの枚数（記録の再利用と、iCloud にあって取れない写真を除く）。残り時間の見積もりに使う
    let expectedToDiagnose: Int

    @State private var state = FullScanState()

    /// 表の行を押して開いている項目
    @State private var selectedKind: FindingKind?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        FullScanContentView(
            phase: state.phase,
            total: state.total,
            remainingSeconds: state.remainingSeconds,
            elapsedSeconds: state.elapsedSeconds,
            onSelect: { select($0) },
            onStop: { stop() },
            onResume: { resume() },
            onClose: { close() }
        )
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedKind) { kind in
            ReportItemView(
                kind: kind,
                item: state.item(of: kind),
                photos: state.photos(of: kind),
                removed: state.removedPhotos(of: kind)
            ) {
                await state.reloadDispositions()
            }
        }
        // .task ではなく onAppear で同期に始める。.task は子画面を push しただけでキャンセルされるうえ、
        // 終わりまで await すると State を掴み続けて画面を閉じても捨てられない。
        // 項目から戻るたびに走るので、自動開始は State 側で一度きりに絞る
        .onAppear {
            state.startIfNeeded(
                assets: assets, quality: quality, allowsDownload: allowsDownload, expectedToDiagnose: expectedToDiagnose
            )
        }
    }

    // MARK: - 操作（レイアウトと混ぜないよう、body の外に置く）

    private func select(_ kind: FindingKind) {
        selectedKind = kind
    }

    private func stop() {
        state.stop()
    }

    /// 記録がある分は診断せずに流れるので、実際に続きから走る
    private func resume() {
        state.restart(assets: assets, quality: quality, allowsDownload: allowsDownload)
    }

    /// ホーム（結果票）に戻る。ホームは表示されるたびに記録を読み直す
    private func close() {
        dismiss()
    }
}

#Preview {
    NavigationStack {
        FullScanView(
            assets: (0..<40).map {
                AssetMetadata(
                    id: "stub-\($0)",
                    creationDate: nil,
                    modificationDate: nil,
                    coordinate: nil,
                    isScreenshot: false
                )
            },
            quality: .precise,
            allowsDownload: false,
            expectedToDiagnose: 40
        )
    }
}
