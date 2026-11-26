//
//  FlowLayout.swift
//  PhotoDock
//

import SwiftUI

/// 札を左から並べ、入りきらなければ次の行に送る。
/// HStack だと、文字が大きい設定や種類の多い写真で、札が画面からはみ出す
struct FlowLayout: Layout {
    var spacing: CGFloat = Spacing.xxs

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, in: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let origins = arrange(subviews, in: bounds.width).origins
        for (subview, origin) in zip(subviews, origins) {
            subview.place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: ProposedViewSize(width: bounds.width, height: nil)
            )
        }
    }

    private func arrange(_ subviews: Subviews, in width: CGFloat) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var cursor = CGPoint.zero
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            // 1つで幅を超える札は、その幅に収めて折り返させる
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if cursor.x > 0, cursor.x + size.width > width {
                cursor = CGPoint(x: 0, y: cursor.y + rowHeight + spacing)
                rowHeight = 0
            }
            origins.append(cursor)
            cursor.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, cursor.x - spacing)
        }

        return (CGSize(width: widest, height: cursor.y + rowHeight), origins)
    }
}

#Preview {
    FlowLayout {
        ForEach(["住所", "電話番号", "メールアドレス", "郵便番号", "パスワード・認証情報"], id: \.self) { text in
            Text(text)
                .font(.label)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xxs)
                .background(Color.surfaceMuted, in: .rect(cornerRadius: Metrics.tagRadius))
        }
    }
    .frame(width: 220)
    .padding()
}
