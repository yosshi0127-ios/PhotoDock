//
//  BGTaskSchedulerContinuedProcessingService.swift
//  PhotoDock
//

import BackgroundTasks
import Foundation
import os

/// BGContinuedProcessingTask で「前面で始めた処理をアプリを離れても続けたい」と OS に申告する。
///
/// 流れ: ①識別子の launch handler を登録（初回だけ）→ ②request を submit → ③OS が handler に task を渡す
/// → ④task に進捗を書き、終わったら setTaskCompleted。ユーザーが Live Activity で中止すると expirationHandler。
///
/// 登録は BGTask 一般の「起動完了前に」の縛りから除外されている（SDK ヘッダに明記）ので、
/// 最初の申告時にここで行う。App 側に起動フックを足さずに済む。
/// handler は識別子ごとに1回しか登録できない（2回目はアプリが落ちる）が、submit は何度でもよく、
/// OS はそのたびに同じ handler へ task を渡す。
///
/// BGTask は Sendable でないので、この actor の外へ出さない。セッションの状態も全部ここに置き、
/// 外（UseCase・OS の handler）とは ID だけをやり取りする
actor BGTaskSchedulerContinuedProcessingService: ContinuedProcessingService {
    /// Info.plist の BGTaskSchedulerPermittedIdentifiers には `com.upft.photodock.scan.*` を登録する（ワイルドカード形式が必須）。
    /// 提出するのはその接頭辞 + 用途。全量スキャンは同時に1本しか走らないので用途名は固定でよい
    static let taskIdentifier = "com.upft.photodock.scan.full"

    private let logger = Logger(subsystem: "com.upft.photodock", category: "ContinuedProcessing")

    /// nil = まだ登録していない。false = 登録できなかった（Info.plist に識別子が無い）
    private var registration: Bool?
    /// 申告中のセッション。終わったら消す（消えている = 以後の report / end は無視）
    private var sessions: [UUID: TaskSession] = [:]
    /// submit したが OS からまだ task が渡っていないセッション。渡る順は submit の順
    private var waiting: [UUID] = []

    func begin(
        _ work: ContinuedWork,
        onExpire: @escaping @Sendable () -> Void
    ) async -> ContinuedProcessingSession? {
        guard registerIfNeeded() else { return nil }

        let id = UUID()
        let request = BGContinuedProcessingTaskRequest(
            identifier: Self.taskIdentifier,
            title: work.title,
            subtitle: work.subtitle
        )
        // 既定の .queue。OS が混んでいれば task は遅れて渡るが、こちらは待たずに処理を進める
        // （申告は延命であって処理の開始条件ではない）
        request.strategy = .queue

        // 背景で GPU を使えるときだけ継続する。Vision の OCR は内部で Metal を使い（推論の割り当てを
        // Neural Engine にしても変わらない）、GPU の無い背景では UIKit の猶予（約30秒）が切れた時点で詰まり、
        // 進捗ゼロが45秒続いて OS に打ち切られる（2026-09-14 実機ログ）。GPU の要求には
        // entitlement「Background GPU Access」（有料の Developer Program）が要り、無ければ submit が拒否される。
        // そのときは継続せず、前面だけで進める（安全側。entitlement を付ければここは変更なしで有効になる）
        guard BGTaskScheduler.supportedResources.contains(.gpu) else {
            logger.notice("この端末は背景の GPU に対応していないので、継続は申告しない")
            return nil
        }
        request.requiredResources = .gpu

        sessions[id] = TaskSession(work: work, onExpire: onExpire)
        waiting.append(id)
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("継続を申告した（GPU あり）: totalUnits=\(work.totalUnits)")
        } catch {
            sessions[id] = nil
            waiting.removeAll { $0 == id }
            logger.notice("継続を申告できないので前面だけで進める（GPU の権限なし = entitlement 未設定、または OS の拒否）: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        return ContinuedProcessingSession(
            report: { completed, subtitle in await self.report(id, completedUnits: completed, subtitle: subtitle) },
            end: { success in await self.end(id, success: success) }
        )
    }

    private func registerIfNeeded() -> Bool {
        if let registration { return registration }

        // @Sendable を明示する: actor のメソッド内で作った普通のクロージャは「この actor に隔離」と推論され、
        // OS が自分のキューから呼んだ瞬間に実行時の隔離チェックで落ちる（Incorrect actor executor assumption）
        let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { @Sendable task in
            // BGTask は Sendable でない。OS の handler スレッドから actor へ渡すために、
            // 「この後ここでは触らない」ことを自分で保証して送る
            nonisolated(unsafe) let task = task
            Task { await self.attach(task) }
        }
        if registered {
            logger.info("launch handler を登録した")
        } else {
            logger.error("launch handler を登録できない。Info.plist の BGTaskSchedulerPermittedIdentifiers を確認")
        }
        registration = registered
        return registered
    }

    /// OS から task が渡った。順番待ちの先頭のセッションに結びつけ、貯めていた進捗をまとめて書く
    private func attach(_ task: BGTask) {
        guard let task = task as? BGContinuedProcessingTask, !waiting.isEmpty,
              var session = sessions[waiting[0]] else {
            // 対応するセッションが無い = 申告した処理はもう終わっている。持っていても仕方がないのですぐ返す
            logger.notice("対応するセッションの無い task を受け取った。すぐ返す")
            task.setTaskCompleted(success: false)
            return
        }
        let id = waiting.removeFirst()
        logger.info("OS から task を受け取った。進捗の報告を始める: completed=\(session.completedUnits)/\(session.work.totalUnits)")

        // 進捗を書かないタスクは「止まっている」と見なされて優先的に打ち切られる。
        // Apple のサンプルと同じく Progress を1回取り出して保持し、以後はその参照に書く
        let progress = task.progress
        progress.totalUnitCount = Int64(max(1, session.work.totalUnits))
        progress.completedUnitCount = Int64(session.completedUnits)
        session.progress = progress
        task.updateTitle(session.work.title, subtitle: session.subtitle)
        // こちらも OS のキューから呼ばれるので @Sendable（上の register と同じ理由）
        task.expirationHandler = { @Sendable [onExpire = session.onExpire] in
            // 先に処理を止める。OS への完了報告は actor 経由（task の参照を切るため）
            onExpire()
            Task { await self.expire(id) }
        }

        session.task = task
        session.attachedAt = .now
        sessions[id] = session
    }

    private func report(_ id: UUID, completedUnits: Int, subtitle: String) {
        guard var session = sessions[id] else { return }
        session.completedUnits = completedUnits
        session.subtitle = subtitle

        if let task = session.task {
            session.progress?.completedUnitCount = Int64(completedUnits)

            // Live Activity の文言は毎枚更新しない（数千回になる）。1秒に1回か、最後の1枚だけ
            let now = ContinuousClock.now
            let dueForUpdate = session.lastTitleUpdate.map { now - $0 >= .seconds(1) } ?? true
            if dueForUpdate || completedUnits >= session.work.totalUnits {
                task.updateTitle(session.work.title, subtitle: subtitle)
                session.lastTitleUpdate = now
            }
        }

        sessions[id] = session
    }

    private func end(_ id: UUID, success: Bool) {
        guard let session = sessions.removeValue(forKey: id) else { return }

        if let task = session.task {
            task.setTaskCompleted(success: success)
            logger.info("終了を報告した: success=\(success) completed=\(session.completedUnits)/\(session.work.totalUnits)")
        } else {
            // task が渡る前に終わった。キューに残った request を取り下げる
            waiting.removeAll { $0 == id }
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
            logger.info("task が渡る前に終わった。request を取り下げた: success=\(success)")
        }
    }

    private func expire(_ id: UUID) {
        // 打ち切りの理由は OS から渡されない。時間・発熱・低電力モードを一緒に残して原因を推定する
        let session = sessions[id]
        let elapsedSeconds = session?.attachedAt.map { (ContinuousClock.now - $0).components.seconds } ?? -1
        let process = ProcessInfo.processInfo
        // OS が見ている Progress の中身も出す。こちらの completed と食い違えば「進捗が届いていない」が確定する
        let held = session?.progress
        let onTask = session?.task?.progress
        logger.notice("""
            OS が打ち切った（ユーザーの中止か資源不足）: completed=\(session?.completedUnits ?? -1)/\(session?.work.totalUnits ?? -1) \
            経過=\(elapsedSeconds)秒 thermal=\(process.thermalState.rawValue) lowPower=\(process.isLowPowerModeEnabled) \
            progress(held)=\(held?.completedUnitCount ?? -1)/\(held?.totalUnitCount ?? -1) fraction=\(held?.fractionCompleted ?? -1) \
            progress(task)=\(onTask?.completedUnitCount ?? -1)/\(onTask?.totalUnitCount ?? -1) same=\(held === onTask)
            """)
        end(id, success: false)
    }
}

/// 申告1件の状態。OS から task が渡るのは submit の後（キュー待ちなら遅れる）なので、
/// 渡る前の進捗は貯めておき、渡った時点でまとめて書く。actor の中でだけ触る
private struct TaskSession {
    let work: ContinuedWork
    let onExpire: @Sendable () -> Void

    var task: BGContinuedProcessingTask?
    /// task.progress を1回取り出して保持したもの（Apple のサンプルと同じ扱い）
    var progress: Progress?
    /// OS から task が渡った時刻。打ち切られたときに「どれだけ走れたか」を残すため
    var attachedAt: ContinuousClock.Instant?
    var completedUnits = 0
    var subtitle: String
    var lastTitleUpdate: ContinuousClock.Instant?

    init(work: ContinuedWork, onExpire: @escaping @Sendable () -> Void) {
        self.work = work
        self.subtitle = work.subtitle
        self.onExpire = onExpire
    }
}
