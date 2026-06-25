//
//  File.swift
//  IssuerProvisioningKit
//
//  Created by rahul anand on 25/06/26.
//

import PassKit

public final class ProvisioningStaus {
    
    private let paymentPasses: PassLibraryProviding
    
    public init(paymentPasses: PassLibraryProviding) {
        self.paymentPasses = paymentPasses
    }

    public convenience init() {
        self.init(paymentPasses: PaymentPasses())
    }
    
    public func status(for cardLastDigits: [String],
                       requiresAuth: Bool,
                       completion: @escaping (PKIssuerProvisioningExtensionStatus) -> Void) {
        let status = PKIssuerProvisioningExtensionStatus()
        status.requiresAuthentication = requiresAuth
        
        guard !cardLastDigits.isEmpty else {
            status.passEntriesAvailable = false
            status.remotePassEntriesAvailable = false
            completion(status)
            return
        }
        
        let passes = paymentPasses.paymentPassesOnCurrentDevice()
        var canAddCardToCurrentDevice = false
        var canAddCardToPairedDevice = false
        var seenLastDigits = Set<String>()
        
        let hasFoundAllAvailability = {
            canAddCardToCurrentDevice && canAddCardToPairedDevice
        }
        
        let passesBySuffix = Dictionary(grouping: passes) {
            $0.primaryAccountSuffix
        }
        
        for lastDigits in cardLastDigits where seenLastDigits.insert(lastDigits).inserted {
            let matchingPass = passesBySuffix[lastDigits]?.first
            
            guard let matchingPass else {
                canAddCardToCurrentDevice = true
                if hasFoundAllAvailability() { break }
                continue
            }
            
            if matchingPass.state == .deactivated {
                canAddCardToCurrentDevice = true
                if hasFoundAllAvailability() { break }
                continue
            }
            
            if let identifier = matchingPass.primaryAccountId,
               paymentPasses.canAddSecureElementPass(accountId: identifier) {
                canAddCardToPairedDevice = true
            }
            
            if hasFoundAllAvailability() {
                break
            }
        }
        
        status.passEntriesAvailable = canAddCardToCurrentDevice
        status.remotePassEntriesAvailable = canAddCardToPairedDevice
        completion(status)
    }
}

