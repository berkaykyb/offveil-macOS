import Foundation

class ISPManager: ObservableObject {
    static let shared = ISPManager()
    
    @Published var ispName: String = "Algılanıyor..."
    @Published var isDetecting: Bool = false
    
    private let cacheKey = "cached_isp_info"
    private let cacheTimestampKey = "cached_isp_timestamp"
    private let cacheValidityDuration: TimeInterval = 6 * 60 * 60 // 6 saat
    
    private init() {
        loadCachedISP()
    }
    
    func detectISP() {
        // Cache'i kontrol et
        if let cachedISP = getCachedISP() {
            ispName = cachedISP
            return
        }
        
        // Cache yoksa veya eski ise, API'den al
        isDetecting = true
        
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
                        self.ispName = "Bilinmiyor"
                    }
                case .failure:
                    self.ispName = "Algılanamadı"
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
    
    private func loadCachedISP() {
        if let cached = getCachedISP() {
            ispName = cached
        }
    }
    
    func invalidateCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheTimestampKey)
        ispName = "Algılanıyor..."
    }
}
