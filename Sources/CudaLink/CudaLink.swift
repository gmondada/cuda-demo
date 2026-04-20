import ArgumentParser
import Foundation

@main
struct CudaLink: ParsableCommand {
    @Option(name: .customLong("nvcc-path"), help: "Path to nvcc")
    var nvccPath: String = "/usr/local/cuda/bin/nvcc"

    @Option(name: .customLong("clangpp-path"), help: "Path to clang++")
    var clangppPath: String = "/usr/bin/clang++"

    @Argument(help: "Input .cpp files to link")
    var inputFiles: [String]

    @Option(name: .customShort("o"), help: "Output file path")
    var output: String

    @Flag(name: .customShort("v"), help: "Enable verbose output")
    var verbose: Bool = false

    mutating func run() throws {
        if verbose {
            print("CUDA Link")
            print("Input files: \(inputFiles)")
            print("Output file: \(output)")
        }

        for input in inputFiles {
            try clang(args: ["-c", input, "-o", input + ".o"])
        }

        try nvcc(args: ["--device-link"] + inputFiles.map { $0 + ".o" } + ["-o", output, "-Xcompiler", "-E"])
    }

    func nvcc(args: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: nvccPath)
        process.arguments = ["-ccbin=\(clangppPath)"] + (verbose ? ["-v"] : []) + args
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw CudaLinkError.nvccFailed(process.terminationStatus)
        }
    }

    func clang(args: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: clangppPath)
        process.arguments = (verbose ? ["-v"] : []) + args
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw CudaLinkError.clangFailed(process.terminationStatus)
        }
    }
}

enum CudaLinkError: Error, CustomStringConvertible {
    case nvccFailed(Int32)
    case clangFailed(Int32)

    var description: String {
        switch self {
            case .nvccFailed(let code): return "nvcc failed with exit code \(code)"
            case .clangFailed(let code): return "clang++ failed with exit code \(code)"
        }
    }
}
