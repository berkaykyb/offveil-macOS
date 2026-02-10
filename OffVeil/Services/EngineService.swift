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
    
    func executeCommand(_ command: String) async -> Result<[String: Any], Error> {
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
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

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
    
    func getStatus() async -> Result<[String: Any], Error> {
        return await executeCommand("status")
    }
    
    func getDNS() async -> Result<[String: Any], Error> {
        return await executeCommand("get_dns")
    }
}
