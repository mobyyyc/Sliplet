import XCTest
@testable import Sliplet

final class ReceiptBulkSplitTests: XCTestCase {
    func testLegacyDecodeAndStableNumbersAfterRemoval() throws {
        let record = SplitFixture.record(amounts: [101])
        let legacy = SplitFixture.plan(record)
        let data = try JSONEncoder().encode(legacy)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("nextPersonNumber"))
        var decoded = try JSONDecoder().decode(ReceiptSplitPlan.self, from: data)
        XCTAssertEqual(decoded, legacy)
        decoded.removePerson(SplitFixture.b)
        let added = try XCTUnwrap(decoded.addPerson())
        XCTAssertEqual(decoded.participants.first(where: { $0.id == added })?.name, "Person 4")
        XCTAssertEqual(decoded.participants.first(where: { $0.id == SplitFixture.c })?.number, 3)
        try decoded.validateStructure()
        XCTAssertEqual(try JSONDecoder().decode(ReceiptSplitPlan.self, from: JSONEncoder().encode(decoded)), decoded)
    }
    func testBatchAddsCoownerAndRemovalNeverStealsOtherMemberships() throws {
        let record = SplitFixture.record(amounts: [101, -31, 0])
        let items = Set(record.current.fields.items.map(\.id))
        var plan = SplitFixture.plan(record, owners: [[SplitFixture.a], [SplitFixture.a], [SplitFixture.a]])
        plan.assign(SplitFixture.b, selected: items, items: items)
        for owners in plan.assignments.values { XCTAssertEqual(Set(owners), [SplitFixture.a, SplitFixture.b]) }
        let result = try ReceiptSplitEngine.compute(record, plan: plan)
        XCTAssertEqual(result.total, 70)
        XCTAssertEqual(result.totals.values.reduce(0, +), 70)
        plan.assign(SplitFixture.a, selected: [], items: items)
        XCTAssertTrue(plan.assignments.values.allSatisfy { $0 == [SplitFixture.b] })
        plan.assign(SplitFixture.b, selected: [], items: items)
        XCTAssertThrowsError(try ReceiptSplitEngine.compute(record, plan: plan))
    }
    func testBatchPolicyReviewAndSnapshotUndo() throws {
        let record = SplitFixture.record(amounts: [101, 201], adjustments: [(.tax, 15)])
        let items = Set(record.current.fields.items.map(\.id))
        let before = SplitFixture.plan(record, owners: [[SplitFixture.a], [SplitFixture.a]])
        var plan = before
        plan.assign(SplitFixture.b, selected: items, items: items)
        XCTAssertFalse(plan.policies[0].accepted)
        XCTAssertThrowsError(try ReceiptSplitEngine.compute(record, plan: plan))
        plan = before
        XCTAssertEqual(try ReceiptSplitEngine.compute(record, plan: plan), try ReceiptSplitEngine.compute(record, plan: before))
    }
    func testAppearanceDoesNotChangeMoneyAndPaletteCanRepeat() throws {
        let record = SplitFixture.record(amounts: [101, 101, 101])
        var plan = SplitFixture.plan(record)
        let before = try ReceiptSplitEngine.compute(record, plan: plan)
        plan.materializeAppearance()
        plan.participants[0].name = "Optional name"; plan.participants[0].color = .rose
        XCTAssertEqual(try ReceiptSplitEngine.compute(record, plan: plan), before)
        for _ in 0..<8 { XCTAssertNotNil(plan.addPerson()) }
        XCTAssertEqual(Set(plan.participants.compactMap(\.number)).count, 11)
        XCTAssertLessThan(Set(plan.participants.compactMap(\.color)).count, 11)
        try plan.validateStructure()
    }
    func testMixedLegacyNumbersAndNewPeopleRequirePolicyReview() throws {
        let record = SplitFixture.record(amounts: [100], adjustments: [(.tax, 5)])
        var plan = SplitFixture.plan(record)
        plan.participants[1].number = 1
        let owners = plan.assignments
        XCTAssertNotNil(plan.addPerson())
        XCTAssertEqual(Set(plan.participants.compactMap(\.number)).count, 4)
        XCTAssertEqual(plan.assignments, owners)
        XCTAssertFalse(plan.policies[0].accepted)
        try plan.validateStructure()
    }
    func testInvalidAppearanceAndUnknownBatchRejected() throws {
        let record = SplitFixture.record(amounts: [100])
        var plan = SplitFixture.plan(record)
        let before = plan
        plan.assign(UUID(), selected: Set(record.current.fields.items.map(\.id)), items: Set(record.current.fields.items.map(\.id)))
        XCTAssertEqual(plan, before)
        plan.participants[0].number = -1
        XCTAssertThrowsError(try plan.validateStructure())
    }
}
