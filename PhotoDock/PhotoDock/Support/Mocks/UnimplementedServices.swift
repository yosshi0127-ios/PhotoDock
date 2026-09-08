//
//  UnimplementedServices.swift
//  PhotoDock
//

// testValue に登録する実装をまとめる。依存が増えたらここに Unimplemented<名前> を足す。
// 呼ばれたら必ず落ちる = テストでの上書き忘れを、静かな誤動作ではなくクラッシュとして知らせる。

struct UnimplementedPhotoLibraryService: PhotoLibraryService {
    func currentAccess() async -> PhotoLibraryAccess {
        fatalError("UnimplementedPhotoLibraryService.currentAccess() が呼ばれた（テストで上書きすること）")
    }

    func requestAccess() async -> PhotoLibraryAccess {
        fatalError("UnimplementedPhotoLibraryService.requestAccess() が呼ばれた（テストで上書きすること）")
    }

    func fetchAllAssetMetadata() async -> [AssetMetadata] {
        fatalError("UnimplementedPhotoLibraryService.fetchAllAssetMetadata() が呼ばれた（テストで上書きすること）")
    }
}

struct UnimplementedPixelSourceService: PixelSourceService {
    func fetchImageData(for id: String) async -> PixelSourceOutcome {
        fatalError("UnimplementedPixelSourceService.fetchImageData(for:) が呼ばれた（テストで上書きすること）")
    }
}
