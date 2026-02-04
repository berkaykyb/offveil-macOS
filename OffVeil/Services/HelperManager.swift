//
//  HelperManager.swift
//  OffVeil
//
//  Privileged Helper lifecycle yönetimi
//

import Foundation
import ServiceManagement

class HelperManager {
    static let shared = HelperManager()
    
    private var currentConnection: NSXPCConnection?
    
    private init() {}
    
    // MARK: - Helper Installation
    
    func installHelper(completion: @escaping (Bool, Error?) -> Void) {
        // SMJobBless kullanarak helper'ı yükle
        var authRef: AuthorizationRef?
        let authRightName = kSMRightBlessPrivilegedHelper
        
        authRightName.withCString { namePtr in
            var authItem = AuthorizationItem(
                name: namePtr,
                valueLength: 0,
                value: nil,
                flags: 0
            )
            
            withUnsafeMutablePointer(to: &authItem) { itemPtr in
                var authRights = AuthorizationRights(count: 1, items: itemPtr)
                let authFlags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]
                
                let status = AuthorizationCreate(&authRights, nil, authFlags, &authRef)
                
                guard status == errAuthorizationSuccess, let authRef = authRef else {
                    completion(false, NSError(domain: "HelperManager", code: Int(status)))
                    return
                }
                
                defer {
                    AuthorizationFree(authRef, [])
                }
                
                var error: Unmanaged<CFError>?
                let result = SMJobBless(
                    kSMDomainSystemLaunchd,
                    HelperConstants.machServiceName as CFString,
                    authRef,
                    &error
                )
                
                if let error = error?.takeRetainedValue() {
                    completion(false, error)
                } else {
                    completion(result, nil)
                }
            }
        }
    }
    
    // MARK: - XPC Connection
    
    func connect() -> NSXPCConnection {
        if let connection = currentConnection {
            return connection
        }
        
        let connection = NSXPCConnection(machServiceName: HelperConstants.machServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        
        connection.invalidationHandler = {
            self.currentConnection = nil
        }
        
        connection.interruptionHandler = {
            self.currentConnection = nil
        }
        
        connection.resume()
        currentConnection = connection
        
        return connection
    }
    
    func getHelper() -> HelperProtocol? {
        let connection = connect()
        return connection.remoteObjectProxyWithErrorHandler { error in
            NSLog("OffVeil: Helper XPC error: \(error)")
        } as? HelperProtocol
    }
    
    // MARK: - Helper Operations
    
    func getVersion(completion: @escaping (String?) -> Void) {
        guard let helper = getHelper() else {
            completion(nil)
            return
        }
        
        helper.getVersion { version in
            completion(version)
        }
    }
    
    func startProtection(completion: @escaping (Bool, String?) -> Void) {
        guard let helper = getHelper() else {
            completion(false, "Helper not available")
            return
        }
        
        helper.startProtection(completion: completion)
    }
    
    func stopProtection(completion: @escaping (Bool, String?) -> Void) {
        guard let helper = getHelper() else {
            completion(false, "Helper not available")
            return
        }
        
        helper.stopProtection(completion: completion)
    }
    
    func checkStatus(completion: @escaping ([String: Any]?) -> Void) {
        guard let helper = getHelper() else {
            completion(nil)
            return
        }
        
        helper.checkStatus(completion: completion)
    }
}
