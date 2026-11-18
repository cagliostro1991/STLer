import Foundation

/// Which tool converts STEP files. Exactly one is used at a time.
enum StepEngine: String, Codable, CaseIterable {
    case freecad, opencascade

    var title: String { self == .freecad ? "FreeCAD" : "OpenCASCADE" }
}

/// STEP through the OpenCASCADE library (`brew install opencascade`) and a tiny helper that is compiled on first use.
/// The library is about 45 MB to download and 160 MB on disk against 2 GB for FreeCAD, and is the same kernel FreeCAD uses.
enum OpenCascade {
    private static let supportDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/STLer")
    static let helper = supportDirectory.appendingPathComponent("stler-step")

    /// Homebrew keg of OpenCASCADE, `nil` when it is not installed. `STLER_OCCT_PREFIX` overrides it (tests).
    static var prefix: String? {
        let candidates =
            ProcessInfo.processInfo.environment["STLER_OCCT_PREFIX"].map { [$0] } ?? [
                "/opt/homebrew/opt/opencascade", "/usr/local/opt/opencascade",
            ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    static var brew: String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first {
            FileManager.default.isExecutableFile(atPath: $0)
        }
    }

    /// Opens Terminal with `brew install opencascade`, so the download is visible and can be stopped.
    /// Without Homebrew it opens the Homebrew page instead.
    /// - Returns: What the user should do next.
    static func install() -> String {
        guard let brew else {
            Process.launchedProcess(launchPath: "/usr/bin/open", arguments: ["https://brew.sh"])
            return "Homebrew is not installed. Install it from brew.sh, then press Install again."
        }
        guard
            TerminalScript.run(
                "\(brew) install opencascade\necho\necho 'Finished. Go back to STLer and press Check again.'",
                name: "stler-install-opencascade")
        else { return "Could not prepare the install script. Run: brew install opencascade" }
        return "Installing in Terminal. When it finishes, press Check again."
    }

    /// Returns the converter helper, compiling it first when it is missing or out of date.
    /// - Returns: The helper, or an error message when OpenCASCADE is missing or the compile fails.
    static func ensureHelper() -> (url: URL?, error: String?) {
        guard let prefix else {
            return (nil, "OpenCASCADE is not installed (brew install opencascade)")
        }
        let fileManager = FileManager.default
        let sourceURL = supportDirectory.appendingPathComponent("stler-step.cpp")
        try? fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        let current = (try? String(contentsOf: sourceURL, encoding: .utf8)) == source
        if current, fileManager.isExecutableFile(atPath: helper.path) { return (helper, nil) }
        guard (try? source.write(to: sourceURL, atomically: true, encoding: .utf8)) != nil else {
            return (nil, "Could not write the helper source")
        }

        let libraries = ((try? fileManager.contentsOfDirectory(atPath: "\(prefix)/lib")) ?? [])
            .filter { $0.hasPrefix("libTK") && $0.hasSuffix(".dylib") }
            .map { String($0.dropFirst(3).dropLast(6)) }
            .filter { !$0.contains(".") }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/clang++")
        process.arguments =
            [
                "-w", "-std=c++17", "-O2", sourceURL.path, "-I\(prefix)/include/opencascade",
                "-L\(prefix)/lib", "-Wl,-rpath,\(prefix)/lib", "-Wl,-dead_strip_dylibs",
            ]
            + libraries.map { "-l\($0)" } + ["-o", helper.path]
        let errors = Pipe()
        process.standardError = errors
        process.standardOutput = FileHandle.nullDevice
        guard (try? process.run()) != nil else {
            return (
                nil, "clang++ not found: install the Command Line Tools (xcode-select --install)"
            )
        }
        let output = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return (
                nil,
                "Compiling the STEP helper failed: "
                    + String(decoding: output, as: UTF8.self).split(separator: "\n").prefix(3)
                    .joined(separator: " ")
            )
        }
        return (helper, nil)
    }

    private static let source = """
        #include <STEPControl_Reader.hxx>
        #include <IFSelect_ReturnStatus.hxx>
        #include <BRepMesh_IncrementalMesh.hxx>
        #include <BRepBndLib.hxx>
        #include <Bnd_Box.hxx>
        #include <StlAPI_Writer.hxx>
        #include <TopoDS_Shape.hxx>
        #include <TopoDS_Compound.hxx>
        #include <BRep_Builder.hxx>
        #include <TopExp_Explorer.hxx>
        #include <TopAbs_ShapeEnum.hxx>
        #include <cstdlib>
        #include <cstring>
        #include <algorithm>
        #include <cmath>
        #include <cstdio>

        // usage: stler-step [--parts N] in.step out.stl [in.step out.stl ...]
        // --parts N keeps the first N solids of an assembly (0 = all).
        int main(int argc, char** argv) {
            int first = 1, parts = 0;
            if (argc > 2 && std::strcmp(argv[1], "--parts") == 0) { parts = std::atoi(argv[2]); first = 3; }
            for (int i = first; i + 1 < argc; i += 2) {
                STEPControl_Reader reader;
                if (reader.ReadFile(argv[i]) != IFSelect_RetDone || reader.TransferRoots() <= 0) {
                    std::fprintf(stderr, "stler-fail %s\\n", argv[i]);
                    continue;
                }
                TopoDS_Shape shape = reader.OneShape();
                if (parts > 0) {
                    TopoDS_Compound kept;
                    BRep_Builder builder;
                    builder.MakeCompound(kept);
                    int count = 0;
                    for (TopExp_Explorer solids(shape, TopAbs_SOLID); solids.More() && count < parts; solids.Next(), ++count) builder.Add(kept, solids.Current());
                    if (count > 0) shape = kept;
                }
                Bnd_Box box;
                BRepBndLib::Add(shape, box);
                double deflection = box.IsVoid() ? 0.1 : std::max(std::sqrt(box.SquareExtent()) * 0.001, 0.001);
                BRepMesh_IncrementalMesh mesh(shape, deflection, false, 0.5, true);
                StlAPI_Writer writer;
                writer.ASCIIMode() = false;
                if (!writer.Write(shape, argv[i + 1])) std::fprintf(stderr, "stler-fail %s\\n", argv[i]);
            }
            return 0;
        }
        """
}
