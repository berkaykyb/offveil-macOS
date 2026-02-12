import Foundation

class ISPManager: ObservableObject {
    static let shared = ISPManager()
    
    @Published var ispName: String = "Detecting..."
    @Published var isDetecting: Bool = false
    
    private let cacheKey = "cached_isp_info"
    private let cacheTimestampKey = "cached_isp_timestamp"
    private let refreshTimestampKey = "cached_isp_refresh_timestamp"
    private let cacheValidityDuration: TimeInterval = 6 * 60 * 60 // 6 saat
    private let minRefreshInterval: TimeInterval = 2 * 60 // 2 dakika
    
    private init() {
        loadCachedISP()
    }
    
    func detectISP() {
        if isDetecting {
            return
        }

        // Cache'i ekranda hemen göster
        if let cachedISP = getCachedISP() {
            ispName = cachedISP
        }

        // Çok sık API çağrısı yapma
        if !shouldRefreshFromNetwork() {
            return
        }
        
        isDetecting = true
        markRefreshAttempt()
        
        Task {
            let result = await EngineService.shared.executeCommand("detect_isp")
            
            await MainActor.run {
                switch result {
                case .success(let data):
                    if data["success"] as? Bool == true,
                       let normalizedISP = data["normalized_isp"] as? String {
                        self.ispName = normalizedISP
                        self.cacheISP(normalizedISP)
                    } else {
                        self.ispName = "Unknown"
                    }
                case .failure:
                    self.ispName = "Detection failed"
                }
                self.isDetecting = false
            }
        }
    }
    
    private func getCachedISP() -> String? {
        guard let timestamp = UserDefaults.standard.object(forKey: cacheTimestampKey) as? Date else {
            return nil
        }
        
        // Cache 6 saatten eski mi?
        if Date().timeIntervalSince(timestamp) > cacheValidityDuration {
            return nil
        }
        
        return UserDefaults.standard.string(forKey: cacheKey)
    }
    
    private func cacheISP(_ isp: String) {
        UserDefaults.standard.set(isp, forKey: cacheKey)
        UserDefaults.standard.set(Date(), forKey: cacheTimestampKey)
    }

    private func shouldRefreshFromNetwork() -> Bool {
        guard let lastRefresh = UserDefaults.standard.object(forKey: refreshTimestampKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastRefresh) >= minRefreshInterval
    }

    private func markRefreshAttempt() {
        UserDefaults.standard.set(Date(), forKey: refreshTimestampKey)
    }
    
    private func loadCachedISP() {
        if let cached = getCachedISP() {
            ispName = cached
        }
    }
    
    func invalidateCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheTimestampKey)
        UserDefaults.standard.removeObject(forKey: refreshTimestampKey)
        ispName = "Detecting..."
    }
}
