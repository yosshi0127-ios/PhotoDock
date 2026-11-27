//
//  PhotoZoomView.swift
//  PhotoDock
//

import SwiftUI

/// 写真を、画面いっぱいに出す。写真詳細では、表と一緒に1画面に入るように写真を縮めているので、
/// 細かいところを見たいときはここで見る。所見の枠も一緒に出す。
///
/// 2本の指で拡大・縮小、拡大中は1本の指で動かせる。2回押すと、拡大と元の大きさを切り替える
struct PhotoZoomView: View {
    let image: UIImage
    let findings: [StoredFinding]

    /// いまの倍率と位置（指を動かしている最中の値）
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    /// 指を離した時点の倍率と位置。次の操作は、ここから始める
    @State private var settledScale: CGFloat = 1
    @State private var settledOffset: CGSize = .zero
    @State private var containerSize: CGSize = .zero

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PhotoWithFindings(image: image, findings: findings)
            .scaleEffect(scale)
            .offset(offset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { containerSize = $0 }
            .gesture(magnify.simultaneously(with: drag))
            .onTapGesture(count: 2) { toggleZoom() }
            // 拡大していないときは、どこを押しても閉じられる（拡大中は、動かす操作と取り違えないように閉じない）
            .onTapGesture { if scale == 1 { dismiss() } }
            .background(Color.black)
            .overlay(alignment: .topTrailing) {
                Button("閉じる", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(Spacing.s)
                    .background(.black.opacity(0.5), in: .circle)
                    .padding(Spacing.m)
            }
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(named: scale == 1 ? "拡大" : "元の大きさに戻す") { toggleZoom() }
    }

    // MARK: - 操作

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(Self.maxScale, max(1, settledScale * value.magnification))
                offset = clamped(settledOffset)
            }
            .onEnded { _ in settle() }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                // 拡大していないときは、動かさない（画面からはみ出す部分が無い）
                guard scale > 1 else { return }
                offset = clamped(CGSize(
                    width: settledOffset.width + value.translation.width,
                    height: settledOffset.height + value.translation.height
                ))
            }
            .onEnded { _ in settle() }
    }

    private func settle() {
        settledScale = scale
        settledOffset = offset
    }

    private func toggleZoom() {
        withAnimation(reduceMotion ? nil : Motion.settle) {
            scale = scale > 1 ? 1 : Self.doubleTapScale
            offset = .zero
        }
        settle()
    }

    /// 写真の端より外へは、動かせないようにする
    private func clamped(_ proposed: CGSize) -> CGSize {
        let fitted = fittedSize
        let limitX = max(0, (fitted.width * scale - containerSize.width) / 2)
        let limitY = max(0, (fitted.height * scale - containerSize.height) / 2)
        return CGSize(
            width: min(limitX, max(-limitX, proposed.width)),
            height: min(limitY, max(-limitY, proposed.height))
        )
    }

    /// 拡大していないときに、写真が画面の中で占める大きさ
    private var fittedSize: CGSize {
        guard image.size.width > 0, image.size.height > 0, containerSize.width > 0, containerSize.height > 0 else {
            return containerSize
        }
        let ratio = min(containerSize.width / image.size.width, containerSize.height / image.size.height)
        return CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
    }

    private static let maxScale: CGFloat = 5
    private static let doubleTapScale: CGFloat = 2.5
}

#Preview {
    PhotoZoomView(image: UIImage(systemName: "photo") ?? UIImage(), findings: [])
}
