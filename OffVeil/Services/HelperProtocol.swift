//
//  HelperProtocol.swift
//  OffVeil - Shared
//
//  XPC Protocol definition - Main App ↔ Helper iletişimi
//

import Foundation

struct HelperConstants {
    static let machServiceName = "com.offveil.OffVeilHelper"
    static let version = "1.0.0"
}

@objc protocol HelperProtocol {
    func getVersion(completion: @escaping (String) -> Void)
    func startProtection(completion: @escaping (Bool, String?) -> Void)
    func stopProtection(completion: @escaping (Bool, String?) -> Void)
    func checkStatus(completion: @escaping ([String: Any]) -> Void)
}
