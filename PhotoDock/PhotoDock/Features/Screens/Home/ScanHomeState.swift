//
//  ScanHomeState.swift
//  PhotoDock
//

import Observation

/// ホームの状態。開いたときは**今の状態を読むだけ**で、アクセスの確認は出さない。
/// 確認を出すのは、初回の案内でユーザーがボタンを押したときだけ
@MainActor
@Observable
final class ScanHomeState {

    enum Phase: Equatable {
        /// 最初の読み込み中。2回目以降の読み直しでは、前の表示を出したままにする
        case loading
        case loaded(ScanHomeSnapshot)
    }

    private(set) var phase: Phase = .loading

    /// 診断画面を出しているか。View の遷移に結び付ける
    var isScanPresented = false

    /// iCloud の写真を取り寄せる前の、確認の画面を出しているか
    var isCloudConfirmPresented = false

    /// いま出している（これから出す）診断が、iCloud から取り寄せるか。
    /// **設定としては残さない**。「iCloud の写真も診断する」を押した、その回だけ true になる
    /// （以前はスイッチで、一度オンにすると以後の診断でも毎回、黙って数GB を取り寄せた）
    private(set) var scanAllowsDownload = false

    /// 取り寄せを始めようとしたが、Wi-Fi でなかった
    private(set) var isOffWiFi = false

    private var startsCloudScanAfterDismiss = false

    /// 次に診断するときの品質。当面は精密のみ（brief「スキャン設定」）
    let quality: ScanQuality = .precise

    // 依存は UseCase 経由のみ
    private let loadHome = LoadScanHomeUseCase()
    private let requestAccess = RequestPhotoAccessUseCase()
    private let checkCloudReadiness = CheckCloudDownloadReadinessUseCase()
    private let reportPolicy = ScanReportPolicy()
    private let cloudPolicy = CloudDownloadPolicy()

    /// 結果票の項目を開いたときに並べる写真。並び順と判定は Policy が決める
    func photos(of kind: FindingKind) -> [ReportItemPhoto] {
        guard case let .loaded(.ready(content)) = phase else { return [] }
        return reportPolicy.photos(
            of: kind, in: content.flagged, assets: content.assets, dispositions: content.dispositions
        )
    }

    /// 結果票の、その項目の行（判定と枚数）
    func item(of kind: FindingKind) -> ScanReport.Item? {
        guard case let .loaded(.ready(content)) = phase else { return nil }
        return content.report?.items.first { $0.kind == kind }
    }

    /// ホームが表示されるたびに呼ぶ（診断から戻ったときに結果票を更新するため）
    func load() async {
        phase = .loaded(await loadHome(quality: quality))
    }

    /// 初回の案内のボタン。ここで初めてアクセスを聞き、許可されたらそのまま診断を始める
    func allowAccessAndStartScan() async {
        await requestAccess()
        await load()
        startScan()
    }

    /// 診断画面へ進む（端末にある写真だけ）。診断できる写真が無ければ何もしない
    func startScan() {
        guard case let .loaded(.ready(content)) = phase, !content.assets.isEmpty else { return }
        scanAllowsDownload = false
        isScanPresented = true
    }

    // MARK: - iCloud の写真

    /// iCloud にある写真を取り寄せる前の見積もり。未診断の写真が無ければ nil
    var cloudEstimate: CloudDownloadEstimate? {
        guard case let .loaded(.ready(content)) = phase,
              let count = content.report?.notAvailableLocally, count > 0 else { return nil }
        return cloudPolicy.estimate(photoCount: count)
    }

    /// 「iCloud の ◯ 枚も診断する」。いきなり始めず、確認の画面を出す
    func askCloudScan() {
        guard cloudEstimate != nil else { return }
        isOffWiFi = false
        isCloudConfirmPresented = true
    }

    /// 確認の画面の「取り寄せて診断する」。Wi-Fi でなければ始めず、その旨を出す。
    /// 始める場合は、確認の画面を閉じる（診断画面へ進むのは、閉じ終わってから。`cloudConfirmDidDismiss`）
    func confirmCloudScan() async {
        guard await checkCloudReadiness() else {
            isOffWiFi = true
            return
        }
        isOffWiFi = false
        startsCloudScanAfterDismiss = true
        isCloudConfirmPresented = false
    }

    /// 確認の画面が閉じ終わったとき。「取り寄せて診断する」で閉じたのなら、診断画面へ進む。
    /// 閉じるのと同時に進めると、画面が閉じる途中で遷移が重なる
    func cloudConfirmDidDismiss() {
        guard startsCloudScanAfterDismiss else { return }
        startsCloudScanAfterDismiss = false
        scanAllowsDownload = true
        isScanPresented = true
    }

    /// 次の診断で実際に診断する見込みの枚数（残り時間の見積もり用）
    var expectedToDiagnose: Int {
        guard case let .loaded(.ready(content)) = phase else { return 0 }
        return content.pendingCount(allowsDownload: scanAllowsDownload)
    }
}
