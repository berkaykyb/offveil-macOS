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

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.offveil.networkmonitor", qos: .utility)
    private var lastInterfaceTypes: Set<NWInterface.InterfaceType> = []
    private var isMonitoring = false

    private init() {}

    /// Start observing network changes.
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }

            let currentTypes = Set(path.availableInterfaces.map(\.type))

            // Only react if the set of interface types actually changed
            guard currentTypes != self.lastInterfaceTypes else { return }
            self.lastInterfaceTypes = currentTypes

            // Only re-apply if protection is currently active
            self.reapplyIfActive()
        }

        monitor.start(queue: queue)
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        monitor.cancel()
        isMonitoring = false
    }

    // MARK: - Private

    private func reapplyIfActive() {
        Task {
            let statusResult = await EngineService.shared.getStatus()
            guard case .success(let data) = statusResult,
                  (data["status"] as? String) == "active" else {
                return
            }

            // Re-run check_and_restore which verifies proxy is set
            // on the correct interfaces and fixes if needed
            _ = await EngineService.shared.executeCommand("check_and_restore")
        }
    }
}
