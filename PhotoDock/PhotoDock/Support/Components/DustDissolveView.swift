//
//  DustDissolveView.swift
//  PhotoDock
//

import SwiftUI
import UIKit

/// 写真が粒になって、風に流されるように消える。削除が実行されたときに1回だけ流す。
///
/// 写真を小さな升目の色に置き換え、左から順に、右上へ流しながら薄くする。
/// 写真そのものは使わない（升目の色だけ）ので、消える途中で中身が読めることは無い
struct DustDissolveView: View {
    private let aspectRatio: CGFloat
    /// 升目の色。出たときに1回だけ作る
    @State private var grid: DustGrid?
    @State private var startedAt = Date.now
    /// 流し終えた。描くものが無いのに、毎コマ呼ばれ続けないように止める
    @State private var isFinished = false

    init(image: UIImage) {
        aspectRatio = image.size.height > 0 ? image.size.width / image.size.height : 1
        // @State の初期値は、最初の1回しか使われない（親が描き直されても、作り直した値は捨てられる）
        _grid = State(initialValue: DustGrid(image: image, columns: Self.columns))
    }

    var body: some View {
        // 粒は写真の外まで流れるので、描く場所は写真よりひと回り広く取る
        Color.clear
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay {
                TimelineView(.animation(paused: isFinished)) { timeline in
                    let progress = timeline.date.timeIntervalSince(startedAt) / Self.duration
                    Canvas { context, size in
                        guard let grid, progress < 1 else { return }
                        context.translateBy(x: Self.spread, y: Self.spread)
                        let photoSize = CGSize(width: size.width - Self.spread * 2, height: size.height - Self.spread * 2)
                        grid.draw(in: &context, size: photoSize, progress: max(0, progress))
                    }
                }
                .padding(-Self.spread)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task {
                startedAt = .now
                // 最後のコマを描ききってから止める
                try? await Task.sleep(for: .seconds(Self.duration + 0.2))
                if !Task.isCancelled { isFinished = true }
            }
    }

    private static let duration: TimeInterval = 1.4
    private static let columns = 44
    /// 粒が写真の外へ流れる、最大の距離
    private static let spread: CGFloat = 120
}
