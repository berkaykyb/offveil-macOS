import Foundation

class EngineService {
    static let shared = EngineService()
    
    private let enginePath: String
    
    private init() {
        let bundle = Bundle.main
        if let resourcePath = bundle.resourcePath {
            enginePath = resourcePath + "/engine/main.py"
        } else {
            enginePath = ""
        }
    }
    
    func executeCommandSync(_ command: String) -> Result<[String: Any], Error> {
        guard !enginePath.isEmpty, FileManager.default.fileExists(atPath: enginePath) else {
            return .failure(
                NSError(
                    domain: "EngineService",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Engine script not found at \(enginePath)"]
                )
            )
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [enginePath, command]
        var env = ProcessInfo.processInfo.environment
        env["OFFVEIL_OWNER_PID"] = String(ProcessInfo.processInfo.processIdentifier)
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()

            // Drain both pipes on background threads while the process runs.
            // This prevents a deadlock: if the pipe buffer fills up, the child
            // process blocks on write() waiting for a reader — while we'd be
            // waiting on waitUntilExit(). Reading concurrently avoids that.
            var stdoutData = Data()
            var stderrData = Data()
            let group = DispatchGroup()

            group.enter()
            DispatchQueue.global().async {
                stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }

            group.enter()
            DispatchQueue.global().async {
                stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }

            process.waitUntilExit()
            group.wait()

            let stdout = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if process.terminationStatus != 0 {
                return .failure(
                    NSError(
                        domain: "EngineService",
                        code: Int(process.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: "Engine exited with code \(process.terminationStatus). \(stderr)"]
                    )
                )
            }

            if let json = try? JSONSerialization.jsonObject(with: Data(stdout.utf8)) as? [String: Any] {
                return .success(json)
            } else {
                return .failure(
                    NSError(
                        domain: "EngineService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid JSON. stdout: \(stdout) stderr: \(stderr)"]
                    )
                )
            }
        } catch {
            return .failure(error)
        }
    }


    func executeCommand(_ command: String) async -> Result<[String: Any], Error> {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                let result = executeCommandSync(command)
                continuation.resume(returning: result)
            }
        }
    }
    
    func getStatus() async -> Result<[String: Any], Error> {
        return await executeCommand("status")
    }
}
