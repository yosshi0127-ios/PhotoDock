//
//  PhotoDetailState.swift
//  PhotoDock
//
//  Created by akito.yoshikawa on 2026/09/09.
//

import Observation
import UIKit

@MainActor
@Observable
final class PhotoDetailState {
 
    enum Phase: Equatable {
        case empty
        case checking
        case checked([Finding])
        /// 読み込めなかった（選択の読み込み失敗・画像として壊れている）
        case undecodable
    }
    
    private(set) var phase: Phase = .empty
    
    private(set) var image: UIImage?

    private let scanImage = ScanImageUseCase()

    /// imageData が nil なのは、PhotosPicker からの読み込みが失敗した場合
    func check(imageData: Data?) async {
        guard let imageData, let decoded = UIImage(data: imageData) else {
            image = nil
            phase = .undecodable
            return
        }

        image = decoded
        phase = .checking
        phase = .checked(await scanImage(imageData: imageData, quality: .precise))
    }
}
