import XCTest
@testable import IssuerProvisioningKit

final class ProvisioningStausTests: XCTestCase {
    // Verifies that empty customer card input reports no local or remote entries while preserving authentication.
    func testNoCustomerCardsAvailable() {
        let blue = MockPassesService()
        let service = ProvisioningStaus(paymentPasses: blue)
        service.status(for: [], requiresAuth: true) { result in
            XCTAssertFalse(result.passEntriesAvailable)
            XCTAssertFalse(result.remotePassEntriesAvailable)
            XCTAssertTrue(result.requiresAuthentication)
        }
    }
    
    // Verifies that an active matching card already on the device is not reported as locally available.
    func testActiveCardOnDeviceNotLocallyAvailable() {
        let blue = MockPassesService()
        
        blue.passes = [
            SecurePassModel(primaryAccountSuffix: "1234",
                            primaryAccountId: "card-1",
                            state: .activated)
        ]
        
        let service = ProvisioningStaus(paymentPasses: blue)
        
        service.status(for: ["1234"], requiresAuth: false) { result in
            XCTAssertFalse(result.passEntriesAvailable)
        }
    }
    
    // Verifies that a matching deactivated card is reported as locally available but not remotely available.
    func testDeactivatedCardIsLocallyAvailable() {
        
        let blue = MockPassesService()
        
        let deactivatedCard = SecurePassModel(primaryAccountSuffix: "1234",
                                              primaryAccountId: "card-1",
                                              state: .deactivated)
        blue.passes = [
            deactivatedCard
        ]
        
        let service = ProvisioningStaus(paymentPasses: blue)
        
        service.status(for: ["1234"], requiresAuth: false) { result in
            XCTAssertTrue(result.passEntriesAvailable)
            XCTAssertFalse(result.remotePassEntriesAvailable)
        }
    }
    
    // Verifies that an active local card is reported as remotely available when its identifier is Watch-eligible.
    func testActiveCardCanBeAddedToWatch() {
        let blue = MockPassesService()
        
        let locallyAvailableCard = SecurePassModel(primaryAccountSuffix: "1234",
                                                  primaryAccountId: "card-1",
                                                  state: .activated)
        blue.passes = [locallyAvailableCard]
        blue.addableIdentifiers = ["card-1"]
        
        let service = ProvisioningStaus(paymentPasses: blue)
        
        service.status(for: ["1234"], requiresAuth: true) {result in
            XCTAssertFalse(result.passEntriesAvailable)
            XCTAssertTrue(result.remotePassEntriesAvailable)
        }
    }
    
    // Verifies that status calculation completes within the required 100-millisecond performance limit.
    func testStatusCompletesWithinOneHundredMilliseconds() {
        let blue = MockPassesService()
        
        blue.passes = (0..<100).map { index in
            SecurePassModel(primaryAccountSuffix: String(format: "%04d", index),
                            primaryAccountId: "card-\(index)",
                            state: .activated)
        }
        
        let service = ProvisioningStaus(paymentPasses: blue)
        let startTime = CFAbsoluteTimeGetCurrent()
        
       service.status(for: ["0999"], requiresAuth: false) { _ in}
        
        let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertLessThan(
               elapsedTime,
               0.1,
               "status() took \(elapsedTime * 1_000) ms")
    }
    
    // Verifies that one unmatched card among several customer and installed cards makes local provisioning available.
    func testMultipleProvisionCards() {
        let blue = MockPassesService()
        
        blue.passes = [
            SecurePassModel(primaryAccountSuffix: "1234",
                            primaryAccountId: "card-1",
                            state: .activated),
            SecurePassModel(primaryAccountSuffix: "5678",
                            primaryAccountId: "card-2",
                            state: .activated),
            SecurePassModel(primaryAccountSuffix: "2378",
                            primaryAccountId:"card-3", state: .activated)
        ]
        
        let service = ProvisioningStaus(paymentPasses: blue)
        
        service.status(for: ["8888", "3333", "1234"], requiresAuth: false) { result in
            XCTAssertTrue(result.passEntriesAvailable)
        }
    }
    
    // Verifies that processing stops once remote availability is found first and local availability is found later.
    func testStopsEarlyWhenRemoteFoundFirstThenLocalFound() {
        let blue = MockPassesService()

        blue.passes = [
            SecurePassModel(primaryAccountSuffix: "1234",
                            primaryAccountId: "card-1",
                            state: .activated
            ),
            SecurePassModel(primaryAccountSuffix: "5555",
                            primaryAccountId: "card-5",
                            state: .activated
            )
        ]

        blue.addableIdentifiers = ["card-1", "card-5"]

        let service = ProvisioningStaus(paymentPasses: blue)

        service.status(for: ["1234", "9999", "5555"], requiresAuth: false) { result in
            XCTAssertTrue(result.remotePassEntriesAvailable)
            XCTAssertTrue(result.passEntriesAvailable)
        }

        XCTAssertEqual(blue.canAddSecureElementPassCallCount, 1)
    }
    
    // Verifies that duplicate customer card suffixes are processed only once.
    func testDuplicateLastDigitsProcessedOnce() {
        let blue = MockPassesService()

        blue.passes = [
            SecurePassModel(
                primaryAccountSuffix: "1234",
                primaryAccountId: "card-1",
                state: .activated
            )
        ]

        blue.addableIdentifiers = ["card-1"]

        let service = ProvisioningStaus(paymentPasses: blue)

        service.status(for: ["1234", "1234", "1234"], requiresAuth: false) { result in
            XCTAssertFalse(result.passEntriesAvailable)
            XCTAssertTrue(result.remotePassEntriesAvailable)
        }

        XCTAssertEqual(blue.canAddSecureElementPassCallCount, 1)
    }
    
    // Verifies that status stops early even when many installed passes exist.
    func testStatusStopsEarlyWithManyInstalledPasses() {
        let blue = MockPassesService()

        blue.passes = (0..<10_000).map { index in
            SecurePassModel(
                primaryAccountSuffix: String(format: "%04d", index),
                primaryAccountId: "card-\(index)",
                state: .activated
            )
        }

        blue.addableIdentifiers = ["card-1"]

        let service = ProvisioningStaus(paymentPasses: blue)
        let startTime = CFAbsoluteTimeGetCurrent()

        service.status(
            for: ["0001", "99999"],
            requiresAuth: false
        ) { result in
            XCTAssertTrue(result.remotePassEntriesAvailable)
            XCTAssertTrue(result.passEntriesAvailable)
        }

        let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime

        XCTAssertEqual(blue.canAddSecureElementPassCallCount, 1)

        XCTAssertLessThan(
            elapsedTime,
            0.1,
            "status() took \(elapsedTime * 1_000) ms"
        )
    }
}
