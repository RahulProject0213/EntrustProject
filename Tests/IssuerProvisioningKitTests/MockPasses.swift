//
//  File.swift
//  IssuerProvisioningKit
//
//  Created by rahul anand on 25/06/26.
//

import Foundation
@testable import IssuerProvisioningKit

final class MockPassesService: PassLibraryProviding {
   
    var passes: [SecurePassModel] = []
    
    var addableIdentifiers: Set<String> = []
    
    var canAddSecureElementPassCallCount = 0
    
    func paymentPassesOnCurrentDevice() -> [SecurePassModel] {
        passes
    }

    func canAddSecureElementPass(accountId: String) -> Bool {
        canAddSecureElementPassCallCount += 1
        return addableIdentifiers.contains(accountId)
    }
}
