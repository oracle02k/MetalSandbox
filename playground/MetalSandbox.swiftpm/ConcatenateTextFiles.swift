import Foundation

func concatenateTextFilesFromResources() -> String? {
    let fileManager = FileManager.default

    // Playgrounds の Resources/Shaders フォルダのパスを取得
    guard let resourcePath = Bundle.main.resourcePath else {
        print("Resources フォルダが見つかりません")
        return nil
    }

    do {
        // Shaders フォルダ内のファイル一覧を取得
        let fileURLs = try fileManager.contentsOfDirectory(atPath: resourcePath)

        // .txt ファイルのみフィルタリング
        let txtFiles = fileURLs.filter { $0.hasSuffix(".metal.txt") }

        // 各ファイルの内容を読み込み結合
        let concatenatedString = try txtFiles.map {
            let filePath = resourcePath + "/" + $0
            return try String(contentsOfFile: filePath, encoding: .utf8)
        }.joined(separator: "\n") // 改行で結合

        return concatenatedString
    } catch {
        print("Error reading shader files: \(error)")
        return nil
    }
}
