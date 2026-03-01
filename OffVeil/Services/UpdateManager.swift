//
//  UpdateManager.swift
//  OffVeil
//
//  Created by AI Assistant on 4.02.2026.
//

import Foundation
import AppKit
import CryptoKit

/// Manages in-app update checking, downloading, and installation via GitHub Releases.
class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    private let owner = "berkaykyb"
    private let repo = "offveil-macOS"

    // MARK: - Published state

    @Published var updateAvailable = false
    @Published var latestVersion: String = ""
    @Published var isChecking = false
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0  // 0.0 – 1.0
    @Published var errorMessage: String?

    // MARK: - Internal state

    private var dmgAssetURL: URL?
    private var expectedDMGHash: String?
    private var downloadTask: URLSessionDownloadTask?

    private var apiURL: URL {
        URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
    }

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private var periodicTask: Task<Void, Never>?
    private var lastCheckDate: Date?

    private init() {}

    // MARK: - Periodic check

    /// Start checking for updates every 6 hours in the background.
    func startPeriodicChecks() {
        guard periodicTask == nil else { return }
        periodicTask = Task.detached { [weak self] in
            // Initial check after 30 seconds (let the app finish launching)
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            while !Task.isCancelled {
                await self?.checkForUpdate()
                // Re-check every 6 hours
                try? await Task.sleep(nanoseconds: 6 * 60 * 60 * 1_000_000_000)
            }
        }
    }

    func stopPeriodicChecks() {
        periodicTask?.cancel()
        periodicTask = nil
    }

    // MARK: - Public API

    /// Check for updates only if the last check was more than 30 minutes ago.
    /// Called when the popover opens to keep the UI fresh without spamming the API.
    @MainActor
    func checkIfStale() async {
        if let last = lastCheckDate, Date().timeIntervalSince(last) < 30 * 60 {
            return  // checked recently, skip
        }
        await checkForUpdate()
    }

    /// Check GitHub for a newer release.
    @MainActor
    func checkForUpdate() async {
        guard !isChecking else { return }
        isChecking = true
        errorMessage = nil
        defer {
            isChecking = false
            lastCheckDate = Date()
        }

        do {
            var request = URLRequest(url: apiURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 15

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                errorMessage = "GitHub API error"
                return
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                errorMessage = "Invalid response"
                return
            }

            guard let tagName = json["tag_name"] as? String else {
                errorMessage = "No tag found"
                return
            }

            let remoteVersion = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            latestVersion = remoteVersion

            if isNewerVersion(remoteVersion, than: currentVersion) {
                // Find .dmg asset
                if let assets = json["assets"] as? [[String: Any]] {
                    dmgAssetURL = assets
                        .first(where: {
                            ($0["name"] as? String)?.hasSuffix(".dmg") == true
                        })
                        .flatMap {
                            ($0["browser_download_url"] as? String).flatMap(URL.init(string:))
                        }
                }

                // Parse SHA256 hash from release body (format: "SHA256: <hex>")
                if let body = json["body"] as? String {
                    let lines = body.components(separatedBy: .newlines)
                    for line in lines {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.uppercased().hasPrefix("SHA256:") {
                            let hash = trimmed
                                .dropFirst("SHA256:".count)
                                .trimmingCharacters(in: .whitespaces)
                                .lowercased()
                            if !hash.isEmpty {
                                expectedDMGHash = hash
                            }
                            break
                        }
                    }
                }

                updateAvailable = true
            } else {
                updateAvailable = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Download the .dmg and install (mount + copy + relaunch).
    @MainActor
    func downloadAndInstall() async {
        guard let assetURL = dmgAssetURL else {
            errorMessage = "No download URL"
            return
        }

        guard !isDownloading else { return }
        isDownloading = true
        downloadProgress = 0
        errorMessage = nil

        do {
            let localURL = try await downloadDMG(from: assetURL)

            // Verify SHA256 hash of downloaded DMG
            if let expected = expectedDMGHash {
                let actual = try computeSHA256(of: localURL)
                guard actual == expected else {
                    throw NSError(
                        domain: "UpdateManager", code: -7,
                        userInfo: [NSLocalizedDescriptionKey: "DMG hash doğrulaması başarısız. İndirilen dosya bozulmuş veya değiştirilmiş olabilir."]
                    )
                }
            }

            await installFromDMG(at: localURL)
        } catch {
            errorMessage = error.localizedDescription
            isDownloading = false
        }
    }

    // MARK: - Download

    private func downloadDMG(from url: URL) async throws -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let tempDir = appSupport
            .appendingPathComponent("OffVeil", isDirectory: true)
            .appendingPathComponent("Update", isDirectory: true)

        try? FileManager.default.removeItem(at: tempDir)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let destination = tempDir.appendingPathComponent("OffVeil.dmg")

        let delegate = DownloadDelegate()
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let request = URLRequest(url: url)

        defer { session.finishTasksAndInvalidate() }

        return try await withCheckedThrowingContinuation { continuation in
            delegate.onProgress = { [weak self] progress in
                Task { @MainActor in
                    self?.downloadProgress = progress
                }
            }
            delegate.onComplete = { tempFileURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let tempFileURL = tempFileURL else {
                    continuation.resume(throwing: NSError(
                        domain: "UpdateManager", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Download failed"]
                    ))
                    return
                }
                do {
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.moveItem(at: tempFileURL, to: destination)
                    continuation.resume(returning: destination)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            let task = session.downloadTask(with: request)
            task.resume()
        }
    }

    // MARK: - Install

    private func installFromDMG(at dmgPath: URL) async {
        do {
            // 1. Mount the DMG silently
            let mountPoint = try mountDMG(at: dmgPath)

            // 2. Find the .app inside
            guard let appName = try findApp(in: mountPoint) else {
                throw NSError(
                    domain: "UpdateManager", code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "No .app found in DMG"]
                )
            }

            let sourceApp = URL(fileURLWithPath: mountPoint)
                .appendingPathComponent(appName)
            let currentAppURL = Bundle.main.bundleURL

            // 3. Replace current app with new version
            let destURL = currentAppURL

            // Use a temporary staging location next to the app
            let parentDir = destURL.deletingLastPathComponent()
            let backupURL = parentDir.appendingPathComponent("OffVeil_old.app")
            let newAppStaging = parentDir.appendingPathComponent("OffVeil_new.app")

            let fm = FileManager.default

            // Clean up any previous staging artifacts
            try? fm.removeItem(at: backupURL)
            try? fm.removeItem(at: newAppStaging)

            // Copy new app from mounted DMG to staging
            try fm.copyItem(at: sourceApp, to: newAppStaging)

            // Verify code signature of the new app before installing
            try verifyCodeSignature(at: newAppStaging)

            // Swap: current → backup, staging → current
            try fm.moveItem(at: destURL, to: backupURL)
            try fm.moveItem(at: newAppStaging, to: destURL)

            // Clean up backup
            try? fm.removeItem(at: backupURL)

            // 4. Unmount DMG
            unmountDMG(mountPoint: mountPoint)

            // 5. Relaunch
            relaunchApp(at: destURL)

        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isDownloading = false
            }
        }
    }

    private func mountDMG(at path: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", path.path, "-nobrowse", "-noverify", "-noautoopen", "-plist"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()

        // Parse plist output to find mount point
        guard let plist = try PropertyListSerialization.propertyList(
            from: data, format: nil
        ) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]] else {
            throw NSError(
                domain: "UpdateManager", code: -4,
                userInfo: [NSLocalizedDescriptionKey: "Failed to mount DMG"]
            )
        }

        guard let mountPoint = entities
            .compactMap({ $0["mount-point"] as? String })
            .first else {
            throw NSError(
                domain: "UpdateManager", code: -5,
                userInfo: [NSLocalizedDescriptionKey: "No mount point found"]
            )
        }

        return mountPoint
    }

    private func findApp(in mountPoint: String) throws -> String? {
        let contents = try FileManager.default.contentsOfDirectory(atPath: mountPoint)
        return contents.first(where: { $0.hasSuffix(".app") })
    }

    private func unmountDMG(mountPoint: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["detach", mountPoint, "-force"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
    }

    /// Verify the code signature of the downloaded app.
    private func verifyCodeSignature(at appURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--verify", "--deep", "--strict", appURL.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw NSError(
                domain: "UpdateManager", code: -6,
                userInfo: [NSLocalizedDescriptionKey: "Code signature verification failed. The update may be tampered."]
            )
        }
    }

    /// Compute SHA256 hash of a file using CryptoKit.
    private func computeSHA256(of fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func relaunchApp(at appURL: URL) {
        // Mark that we're relaunching after an update so the new version can
        // auto-activate protection on launch.
        UserDefaults.standard.set(true, forKey: "pendingRelaunchActivation")
        // Tell AppDelegate to skip deactivation during this terminate —
        // the new version will inherit the active protection state.
        UserDefaults.standard.set(true, forKey: "skipCleanupOnTerminate")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-g", "--fresh", appURL.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            try? process.run()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - Version comparison

    /// Returns true if `remote` is newer than `local` using semantic versioning.
    private func isNewerVersion(_ remote: String, than local: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let localParts = local.split(separator: ".").compactMap { Int($0) }

        let maxLen = max(remoteParts.count, localParts.count)
        for i in 0..<maxLen {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }
}

// MARK: - URLSession Download Delegate

private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    var onProgress: ((Double) -> Void)?
    var onComplete: ((URL?, Error?) -> Void)?

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        onComplete?(location, nil)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        onProgress?(progress)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            onComplete?(nil, error)
        }
    }
}
