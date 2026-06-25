# IssuerProvisioningKit

`IssuerProvisioningKit` is a small Swift package that calculates availability for cards in an Apple Wallet issuer-provisioning flow.

The package does not implement the full `PKIssuerProvisioningExtensionHandler` flow and does not provision payment cards. It focuses on the fast status decision needed by a Wallet extension: whether cards are available for the current device, whether cards are available for a paired Apple Watch, and whether issuer authentication is required.

## Requirements

- Swift 6.2 or later
- iOS 14 or later, as declared in `Package.swift`
- PassKit
- A physical iOS device for real Wallet behavior
- Apple’s required issuer-provisioning entitlements for production payment-card provisioning

Apple restricts payment-pass provisioning through special entitlements. This package does not provide, replace, or bypass those entitlements.

## What the package does

Given a list of customer card last digits, the package checks the secure-element payment passes already present on the current iOS device and returns a `PKIssuerProvisioningExtensionStatus` through a completion handler.

The returned PassKit status contains:

- `passEntriesAvailable`: whether at least one card can be added to the current iPhone
- `remotePassEntriesAvailable`: whether at least one already-present card can be added to a paired Apple Watch
- `requiresAuthentication`: whether the issuer wants authentication before continuing

The main public API is:

```swift
public func status(
    for cardLastDigits: [String],
    requiresAuth: Bool,
    completion: @escaping (PKIssuerProvisioningExtensionStatus) -> Void
)
```

## Decision rules

`ProvisioningStaus.status(for:requiresAuth:completion:)` currently follows these rules:

1. If no customer card suffixes are supplied, both local and remote availability are `false`.
2. If a customer card suffix does not match any installed secure-element pass, local availability becomes `true`.
3. If a matching installed pass is `.deactivated`, local availability becomes `true`.
4. If a matching installed pass is active, suspended, activating, requires activation, or unknown, it is treated as already present on the current device.
5. If a matching installed pass has a primary account identifier, the package asks PassKit whether that identifier can be added to a paired Apple Watch.
6. If PassKit says the identifier can be added to a paired Apple Watch, remote availability becomes `true`.
7. Duplicate input suffixes are processed once while preserving the original customer-card order.
8. Processing stops early once both `passEntriesAvailable` and `remotePassEntriesAvailable` have been found.

## Package structure

```text
Sources/IssuerProvisioningKit/
├── ProvisioningStaus.swift
├── PaymentPasses.swift
└── SecurePassModel.swift

Tests/IssuerProvisioningKitTests/
├── ProvisioningStausTests.swift
└── MockPasses.swift
```

## Main classes and models

### `ProvisioningStaus`

`ProvisioningStaus` contains the status decision logic. It receives customer card suffixes, reads installed payment passes through `PassLibraryProviding`, creates a `PKIssuerProvisioningExtensionStatus`, fills its properties, and returns it through the completion handler.

Current note: the class name is misspelled as `ProvisioningStaus`. A future cleanup should rename it to `ProvisioningStatus` or `ProvisioningStatusService`.

### `PassLibraryProviding`

`PassLibraryProviding` is the protocol used by `ProvisioningStaus` so the decision logic does not need to directly read `PKPassLibrary` during tests.

```swift
public protocol PassLibraryProviding {
    func canAddSecureElementPass(accountId: String) -> Bool
    func paymentPassesOnCurrentDevice() -> [SecurePassModel]
}
```

### `PaymentPasses`

`PaymentPasses` is the production PassKit adapter. It uses `PKPassLibrary` to:

- read secure-element passes from the current device
- ignore remote passes when calculating current-device availability
- convert `PKSecureElementPass` values into `SecurePassModel`
- call `canAddSecureElementPass(primaryAccountIdentifier:)` for Apple Watch eligibility

### `SecurePassModel`

`SecurePassModel` is the package-owned representation of an installed secure-element pass. It keeps only the data needed by the status algorithm:

```swift
public struct SecurePassModel {
    public let primaryAccountSuffix: String
    public let primaryAccountId: String?
    public let state: PassState
}
```

The supported states are:

```swift
case activated
case deactivated
case suspended
case activating
case requiresActivation
case unknown
```

### `MockPassesService`

`MockPassesService` is used by the test target. It lets tests provide fake installed passes and fake Apple Watch eligibility without depending on the real Wallet app.

## Installation

### Add the package in Xcode

1. Push this package to a Git repository.
2. Open the consuming app or extension project in Xcode.
3. Select **File → Add Package Dependencies**.
4. Enter the repository URL.
5. Choose a version, branch, or commit.
6. Add the `IssuerProvisioningKit` product to the app-extension target that will use it.

### Add it to another `Package.swift`

```swift
dependencies: [
    .package(
        url: "https://github.com/your-organization/IssuerProvisioningKit.git",
        from: "1.0.0"
    )
],
targets: [
    .target(
        name: "IssuerExtension",
        dependencies: [
            .product(
                name: "IssuerProvisioningKit",
                package: "IssuerProvisioningKit"
            )
        ]
    )
]
```

Replace the example URL with the actual repository URL.

## Basic usage

```swift
import IssuerProvisioningKit

let service = ProvisioningStaus()

service.status(
    for: ["1234", "5678"],
    requiresAuth: true
) { status in
    print(status.passEntriesAvailable)
    print(status.remotePassEntriesAvailable)
    print(status.requiresAuthentication)
}
```

## Using it inside a Wallet issuer-provisioning extension

In a real extension, call the framework from `PKIssuerProvisioningExtensionHandler.status(completion:)`.

```swift
import PassKit
import IssuerProvisioningKit

final class IssuerExtensionHandler: PKIssuerProvisioningExtensionHandler {

    private let provisioningStatus = ProvisioningStaus()

    override func status(
        completion: @escaping (PKIssuerProvisioningExtensionStatus) -> Void
    ) {
        provisioningStatus.status(
            for: customerCardLastDigits,
            requiresAuth: true,
            completion: completion
        )
    }

    private var customerCardLastDigits: [String] {
        // Use already-cached issuer card data here.
        ["1234", "5678"]
    }
}
```

The extension’s `status(completion:)` method must return quickly. Avoid network calls, slow database reads, or backend authentication inside this method. Prepare and cache the customer card suffixes before Wallet asks the extension for status.

## Using a custom pass provider

You can inject your own `PassLibraryProviding` implementation for tests or for another adapter.

```swift
import IssuerProvisioningKit

final class CustomPassProvider: PassLibraryProviding {
    var passes: [SecurePassModel] = [
        SecurePassModel(
            primaryAccountSuffix: "1234",
            primaryAccountId: "card-1",
            state: .activated
        )
    ]

    func paymentPassesOnCurrentDevice() -> [SecurePassModel] {
        passes
    }

    func canAddSecureElementPass(accountId: String) -> Bool {
        accountId == "card-1"
    }
}

let provider = CustomPassProvider()
let service = ProvisioningStaus(paymentPasses: provider)

service.status(
    for: ["1234", "5678"],
    requiresAuth: false
) { status in
    print(status.passEntriesAvailable)
    print(status.remotePassEntriesAvailable)
}
```

## Understanding common results

| Customer and Wallet state | `passEntriesAvailable` | `remotePassEntriesAvailable` |
|---|---:|---:|
| No customer cards | `false` | `false` |
| Customer card is not installed | `true` | `false` |
| Matching pass is deactivated | `true` | `false` |
| Matching pass is active and Watch-eligible | `false` | `true` |
| Matching pass is active and not Watch-eligible | `false` | `false` |
| Matching active pass has no primary account identifier | `false` | `false` |
| One card is locally available and another card is Watch-eligible | `true` | `true` |

Suspended, activating, requires-activation, and unknown passes are treated as already present on the current device. Only `.deactivated` is treated as locally addable.

## Testing

The tests inject `MockPassesService` instead of reading the real Wallet. This keeps the status logic testable without depending on a physical device or actual payment cards.

Current test coverage includes:

- no customer cards
- active card already installed on the current device
- deactivated card available for local provisioning
- active card available for paired Apple Watch provisioning
- performance under the 100-millisecond requirement
- several customer cards and several installed passes
- duplicate suffixes are processed once
- early stop once both local and remote availability are found
- performance with many installed passes

Additional useful scenarios to add:

- duplicate installed pass suffixes
- missing primary account identifiers
- suspended passes
- activating passes
- requires-activation passes
- no installed passes with customer cards
- Watch eligibility returning `false`

Run tests from Xcode using an iOS test destination. Because the production adapter uses iOS PassKit APIs, a plain macOS `swift test` build may require additional platform availability work or a cleaner separation between pure logic and the PassKit adapter.

## Current integration notes

Before publishing this package for external consumers, consider these cleanups:

1. Rename `ProvisioningStaus` to `ProvisioningStatus` or `ProvisioningStatusService`.
2. Make `paymentPasses` private inside `ProvisioningStaus`.
3. Decide whether `PaymentPasses` should stay internal or become a public adapter.
4. Remove the unused `paymentPassesOnPairedDevice()` method if it is not needed by the framework.
5. Improve duplicate-suffix handling. Last digits alone cannot reliably distinguish two different cards with the same suffix.
6. Consider indexing installed passes by suffix if the input list can become large.
7. Remove unused imports such as `Foundation` or `PassKit` from files that do not need them.
8. Add documentation comments to public APIs.

## Security and data limitations

- Do not store or log full card numbers, CVVs, passwords, provisioning certificates, activation data, or cryptographic material.
- The framework only receives card suffixes and cannot reliably distinguish two different cards that share the same last digits.
- PassKit does not provide unrestricted access to every card in Wallet. Visibility depends on Apple’s issuer and application configuration.
- Real provisioning must be implemented by an approved issuer using Apple’s required entitlement and backend integration.

