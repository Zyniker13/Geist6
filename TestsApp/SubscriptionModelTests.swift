// SubscriptionModelTests.swift — TestsApp
// Subscription model behavior: decode of the stripe-mock response shape and
// the display helpers the subscription screens use. All values are obviously
// fake (`sub_123`, `si_123`, `price_123`, `cus_123`).

import XCTest
@testable import Geist6
import GeistData
import StripeModels

final class SubscriptionModelTests: XCTestCase {
  private let decoder = JSONDecoder()

  private func decodeSubscription() throws -> Subscription {
    try decoder.decode(Subscription.self, from: Data(subscriptionWriteFixtureJSON.utf8))
  }

  /// Decodes a copy of the fixture JSON with a top-level key removed, so
  /// tests can exercise the missing-key path without a second fixture.
  private func decodeSubscriptionWithout(_ key: String) throws -> Subscription {
    var dict = subscriptionWriteFixture
    dict.removeValue(forKey: key)
    let data = try JSONSerialization.data(withJSONObject: dict)
    return try decoder.decode(Subscription.self, from: data)
  }

  // MARK: - Decode

  func testSubscriptionDecodesStripeMockShape() throws {
    let subscription = try decodeSubscription()
    XCTAssertEqual(subscription.id, "sub_123")
    XCTAssertEqual(subscription.status, .active)
    XCTAssertEqual(subscription.currency, "usd")
    XCTAssertEqual(subscription.cancelAtPeriodEnd, true)
    XCTAssertEqual(subscription.collectionMethod, .chargeAutomatically)
    XCTAssertEqual(subscription.items.data.count, 1)
    XCTAssertEqual(subscription.items.data.first?.id, "si_123")
    XCTAssertEqual(subscription.items.data.first?.quantity, 1)
    XCTAssertEqual(subscription.items.data.first?.price.id, "price_123")
    XCTAssertEqual(subscription.metadata, [:])
  }

  /// stripe-mock omits `plan` on subscription items even though the pinned
  /// spec marks it required; the generated model keeps decoding the rest.
  func testSubscriptionItemWithoutPlanKeyDecodes() throws {
    var item = subscriptionItemFixture
    item.removeValue(forKey: "plan")
    let decoded = try decoder.decode(SubscriptionItem.self, from: try JSONSerialization.data(withJSONObject: item))
    XCTAssertEqual(decoded.id, "si_123")
    XCTAssertEqual(decoded.price.id, "price_123")
  }

  func testSubscriptionWithoutOptionalKeysDecodes() throws {
    let withoutPause = try decodeSubscriptionWithout("pause_collection")
    XCTAssertNil(withoutPause.pauseCollection.valueOrNil)
    let withoutDescription = try decodeSubscriptionWithout("description")
    XCTAssertNil(withoutDescription.description.valueOrNil)
    let withoutTrialEnd = try decodeSubscriptionWithout("trial_end")
    XCTAssertNil(withoutTrialEnd.trialEnd.valueOrNil)
  }

  // MARK: - Status display

  func testStatusDisplayLabel() {
    XCTAssertEqual(SubscriptionStatus.active.displayString, "Active")
    XCTAssertEqual(SubscriptionStatus.canceled.displayString, "Canceled")
    XCTAssertEqual(SubscriptionStatus.incomplete.displayString, "Incomplete")
    XCTAssertEqual(SubscriptionStatus.incompleteExpired.displayString, "Incomplete expired")
    XCTAssertEqual(SubscriptionStatus.pastDue.displayString, "Past due")
    XCTAssertEqual(SubscriptionStatus.paused.displayString, "Paused")
    XCTAssertEqual(SubscriptionStatus.trialing.displayString, "Trialing")
    XCTAssertEqual(SubscriptionStatus.unpaid.displayString, "Unpaid")
    XCTAssertEqual(SubscriptionStatus(rawValue: "new_state").displayString, "new_state")
  }

  // MARK: - Customer label

  func testCustomerLabelForExpandableForm() throws {
    let subscription = try decodeSubscription()
    XCTAssertEqual(subscription.customer, .string("cus_123"))
  }

  func testCustomerLabelForDeletedCustomer() throws {
    var dict = subscriptionWriteFixture
    dict["customer"] = ["id": "cus_123", "deleted": true, "object": "customer"]
    let decoded = try decoder.decode(Subscription.self, from: try JSONSerialization.data(withJSONObject: dict))
    guard case .deletedCustomer = decoded.customer else {
      return XCTFail("expected a deleted customer")
    }
  }
}
