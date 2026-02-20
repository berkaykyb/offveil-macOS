//
//  NetworkMonitor.swift
//  OffVeil
//
//  Watches for network interface changes (WiFi switch, Ethernet connect/disconnect)
//  and re-applies proxy settings when protection is active.
//

import Foundation
import Network

class NetworkMonitor {
    static let shared = NetworkMonitor()

    private var monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.offveil.networkmonitor", qos: .utility)
    private var lastInterfaceTypes: Set<NWInterface.InterfaceType> = []
    private var isMonitoring = false
    private var rebindTask: Task<Void, Never>?

    private let stabilizationDelayNs: UInt64 = 1_200_000_000
    private let retryDelayNs: UInt64 = 1_000_000_000
    private let maxRebindAttempts = 3

    private init() {}

    /// Start observing network changes.
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // NWPathMonitor cannot be restarted after cancel() — create a fresh instance.
        monitor = NWPathMonitor()

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }

            let currentTypes = Set(path.availableInterfaces.map(\.type))

            guard currentTypes != self.lastInterfaceTypes else { return }
            self.lastInterfaceTypes = currentTypes

            self.reapplyIfActive()
        }

        monitor.start(queue: queue)
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        monitor.cancel()
        isMonitoring = false
        rebindTask?.cancel()
        rebindTask = nil
    }

    // MARK: - Private

    private func reapplyIfActive() {
        rebindTask?.cancel()
        rebindTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: stabilizationDelayNs)
            guard !Task.isCancelled else { return }

            let statusResult = await EngineService.shared.getStatus()
            guard case .success(let data) = statusResult,
                  (data["status"] as? String) == "active" else {
                return
            }

            for attempt in 1...maxRebindAttempts {
                guard !Task.isCancelled else { return }

                let rebindResult = await EngineService.shared.executeCommand("rebind_proxy")
                if self.isRebindSuccessful(rebindResult) {
                    return
                }

                // Retry only for transient sleep/wake timing windows.
                if !self.shouldRetryRebind(rebindResult) || attempt == self.maxRebindAttempts {
                    return
                }

                try? await Task.sleep(nanoseconds: retryDelayNs)
            }
        }
    }

    private func isRebindSuccessful(_ result: Result<[String: Any], Error>) -> Bool {
        guard case .success(let data) = result else { return false }
        return (data["success"] as? Bool) == true
    }

    private func shouldRetryRebind(_ result: Result<[String: Any], Error>) -> Bool {
        switch result {
        case .failure:
            // Process/network command failures can be transient during wake.
            return true
        case .success(let data):
            guard (data["success"] as? Bool) == false else { return false }
            let errorText = ((data["error"] as? String) ?? "").lowercased()
            return errorText.contains("no active network service found")
                || errorText.contains("failed to apply proxy")
        }
    }
}
