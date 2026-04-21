import Foundation

func searchForCommand(_ name: String) -> URL? {
    let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
    for folder in path.split(separator: ":") {
        let url = URL(fileURLWithPath: String(folder)).appendingPathComponent(name)
        if FileManager.default.isExecutableFile(atPath: url.path) {
            return url
        }
    }
    return nil
}
