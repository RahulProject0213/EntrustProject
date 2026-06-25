//
//  File.swift
//  IssuerProvisioningKit
//
//  Created by rahul anand on 25/06/26.
//

import Foundation
import PassKit

public protocol PassLibraryProviding {
    func canAddSecureElementPass(accountId: String) -> Bool
    func paymentPassesOnCurrentDevice() -> [SecurePassModel]
}

class PaymentPasses: PassLibraryProviding {
    
    private let library: PKPassLibrary
    
    init(library: PKPassLibrary = PKPassLibrary()) {
        self.library = library
    }
  
    func paymentPassesOnCurrentDevice() -> [SecurePassModel] {
        guard PKPassLibrary.isPassLibraryAvailable() else {
            return []
        }
        
        return library
            .passes(of: .secureElement)
            .filter {!$0.isRemotePass}
            .compactMap { pass in
                pass.secureElementPass
            }.map { pass in
                SecurePassModel(primaryAccountSuffix: pass.primaryAccountNumberSuffix ,
                                primaryAccountId: pass.primaryAccountIdentifier,
                                state: map(pass.passActivationState))
            }
    }
    
    func canAddSecureElementPass(accountId: String) -> Bool {
        library.canAddSecureElementPass(primaryAccountIdentifier: accountId)
    }
    
    private func map(_ state: PKSecureElementPass.PassActivationState) -> SecurePassModel.PassState {
        switch state {
        case .activated:
            return .activated
        case .activating:
            return .activating
        case .suspended:
            return .suspended
        case .requiresActivation:
            return .requiresActivation
        case .deactivated:
            return .deactivated
        @unknown default:
            return .unknown
        }
    }
}
