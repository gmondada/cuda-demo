import Foundation
import PackagePlugin

@main
struct CudaBuild: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {

        print("CUDA Build Plugin")

        let sourceDir = target.directoryURL

        print("Source directory: \(sourceDir.path)")

        let sourceDirPath = sourceDir.path.hasSuffix("/") ? sourceDir.path : sourceDir.path + "/"
        var inputFiles: [URL] = []
        if let enumerator = FileManager.default.enumerator(at: sourceDir, includingPropertiesForKeys: nil) {
            while let inputUrl = enumerator.nextObject() as? URL {
                if inputUrl.pathExtension == "cu" {
                    guard inputUrl.path.hasPrefix(sourceDirPath) else {
                        fatalError("Input file \(inputUrl.path) is not under source directory \(sourceDirPath)")
                    }
                    let relateivePath = String(inputUrl.path.dropFirst(sourceDirPath.count))
                    inputFiles.append(URL(string: relateivePath, relativeTo: sourceDir)!)
                }
            }
        }

        print("Input files: \(inputFiles.map { $0.relativePath })")

        guard let nvccUrl = searchForCommand("nvcc") else {
            fatalError("nvcc not found")
        }

        guard let clangUrl = try? context.tool(named: "clang++") else {
            fatalError("clang++ not found")
        }

        print("nvcc found at: \(nvccUrl.path)")
        print("clang++ found at: \(clangUrl.url.path)")

        let outputDir = context.pluginWorkDirectoryURL

        var commands: [Command] = []

        // Compile each .cu file to .cpp

        for inputFile in inputFiles {
            let outputCpp = URL(string: inputFile.relativePath, relativeTo: outputDir)!.deletingPathExtension().appendingPathExtension("cpp")
            commands.append(
                .buildCommand(
                    displayName: "Compiling \(inputFile.lastPathComponent) to \(outputCpp.lastPathComponent)",
                    executable: nvccUrl,
                    arguments: [
                        "-cuda", "-rdc=true",
                        "-ccbin=\(clangUrl.url.path)",
                        "-I", sourceDir.path,
                        "-I", sourceDir.path + "/../../../cuda-samples/Common",
                        // "-I", sourceDir.path + "/mlx",
                        inputFile.path,
                        "-o", outputCpp.path
                    ],
                    inputFiles: [inputFile],
                    outputFiles: [outputCpp]
                )
            )
        }

        // Invoke CudaLink command with all .cpp files

        let outputCpps = inputFiles.map { inputFile in
            URL(string: inputFile.relativePath, relativeTo: outputDir)!
                .deletingPathExtension()
                .appendingPathExtension("cpp")
        }

        let cudaLinkTool = try context.tool(named: "CudaLink")
        let linkOutput = outputDir.appendingPathComponent("__cuda_link.cpp")

        commands.append(
            .buildCommand(
                displayName: "Linking CUDA objects",
                executable: cudaLinkTool.url,
                arguments: [
                    "--nvcc-path", nvccUrl.path,
                    "--clangpp-path", clangUrl.url.path,
                ] + outputCpps.map { $0.path } + ["-o", linkOutput.path],
                inputFiles: outputCpps,
                outputFiles: [linkOutput]
            )
        )

        return commands
    }

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
}
