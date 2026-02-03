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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [enginePath, command]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            print("Engine path:", enginePath)
            print("Command:", command)
            
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            print("Raw output:", output)
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return .success(json)
            } else {
                return .failure(NSError(domain: "EngineService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON: \(output)"]))
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
