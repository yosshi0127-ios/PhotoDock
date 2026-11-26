//
//  CloudDownloadEstimate+Display.swift
//  PhotoDock
//

import Foundation

extension CloudDownloadEstimate {
    /// 「約 4.1GB」「約 38MB」。目安なので、細かい桁は出さない
    var sizeText: String {
        if megabytes >= 1_000 {
            let gigabytes = megabytes / 1_000
            return "約 \(gigabytes.formatted(.number.precision(.fractionLength(1))))GB"
        }
        return "約 \(Int(megabytes.rounded()).formatted())MB"
    }

    /// 「約 30 分」「1 分以内」
    var durationText: String {
        if seconds < 60 { return "1 分以内" }
        return "約 \(Int((seconds / 60).rounded()).formatted()) 分"
    }
}
