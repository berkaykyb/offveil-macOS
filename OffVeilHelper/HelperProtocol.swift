//
//  HelperProtocol.swift
//  OffVeilHelper
//
//  Created by Berkay KAYABAŞI on 5.02.2026.
//

import Foundation

@objc protocol HelperProtocol {
    func executeCommand(_ command: String, withReply reply: @escaping (Bool, String) -> Void)
}
