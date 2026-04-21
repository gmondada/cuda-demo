import Foundation
import PackagePlugin

@main
struct CudaBuild: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {

        print("CUDA Build Plugin")

        guard let clangUrl = try? context.tool(named: "clang++") else {
            fatalError("clang++ not found")
        }

        print("Use clang++ at: \(clangUrl.url.path)")

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

        let outputDir = context.pluginWorkDirectoryURL

        var commands: [Command] = []

        // Invoke `encuda compile` to compile each .cu file to .cpp

        let encuda = try context.tool(named: "encuda")

        for inputFile in inputFiles {
            let outputCpp = URL(string: inputFile.relativePath, relativeTo: outputDir)!.deletingPathExtension().appendingPathExtension("cpp")
            commands.append(
                .buildCommand(
                    displayName: "Compiling \(inputFile.lastPathComponent) to \(outputCpp.lastPathComponent)",
                    executable: encuda.url,
                    arguments: [
                        "compile",
                        "--clangpp", clangUrl.url.path,
                        "-I", sourceDir.path,
                        inputFile.path,
                        "-o", outputCpp.path,
                    ],
                    inputFiles: [inputFile],
                    outputFiles: [outputCpp]
                )
            )
        }

        // Invoke `encuda link` with all .cpp files

        let outputCpps = inputFiles.map { inputFile in
            URL(string: inputFile.relativePath, relativeTo: outputDir)!
                .deletingPathExtension()
                .appendingPathExtension("cpp")
        }

        let linkOutput = outputDir.appendingPathComponent("__cuda_link.cpp")

        commands.append(
            .buildCommand(
                displayName: "Linking CUDA objects",
                executable: encuda.url,
                arguments: [
                    "link",
                    "--clangpp", clangUrl.url.path,
                ] + outputCpps.map { $0.path } + ["-o", linkOutput.path],
                inputFiles: outputCpps,
                outputFiles: [linkOutput]
            )
        )

        return commands
    }
}
