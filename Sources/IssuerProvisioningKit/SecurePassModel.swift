// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import PassKit

public struct SecurePassModel {
    
    public enum PassState: Equatable {
        case activated
        case deactivated
        case suspended
        case activating
        case requiresActivation
        case unknown
    }
    
    public let primaryAccountSuffix: String
    public let primaryAccountId: String?
    public let state: PassState
    
    public init(primaryAccountSuffix: String, primaryAccountId: String?, state: PassState) {
        self.primaryAccountSuffix = primaryAccountSuffix
        self.primaryAccountId = primaryAccountId
        self.state = state
    }
}
