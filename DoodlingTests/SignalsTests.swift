//
//  Copyright © 2018 Fredrik Bystam. All rights reserved.
//

import XCTest
@testable import Doodling

class SignalsTests: XCTestCase {

    private let source = Source<Int>()
    private var values: [Int] = []
    private var bag = SignalTokenBag()

    private let placeInValues: (SignalsTests, Int) -> Void = { test, element in
        test.values.append(element)
    }

    override func setUp() {
        values = []
        bag = SignalTokenBag()
    }

    func testSource_value_afterAddListener() {
        let stream = source

        stream
            .addListener(self, handler: placeInValues)
            .bindLifetime(to: bag)

        source.publish(1337)

        XCTAssertEqual(values, [1337])
    }

    func testSource_noValue_beforeAddListener() {
        let stream = source
        source.publish(1337)

        stream
            .addListener(self, handler: placeInValues)
            .bindLifetime(to: bag)

        XCTAssertEqual(values, [])
    }

    func testMap() {
        let stream = source
            .map { int in String(int) }
            .map { string in string.count }

        stream
            .addListener(self, handler: placeInValues)
            .bindLifetime(to: bag)

        source.publish(1)
        source.publish(13)
        source.publish(133)
        source.publish(1337)

        XCTAssertEqual(values, [1, 2, 3, 4])
    }

    func testBuffer_0() {
        let stream = source.buffer(count: 0)
        source.publish(1337)
        source.publish(1338)
        source.publish(1339)
        source.publish(1340)

        stream
            .addListener(self, handler: placeInValues)
            .bindLifetime(to: bag)

        XCTAssertEqual(values, [])
    }

    func testBuffer_1() {
        let stream = source.buffer(count: 1)
        source.publish(1337)
        source.publish(1338)
        source.publish(1339)
        source.publish(1340)

        stream
            .addListener(self, handler: placeInValues)
            .bindLifetime(to: bag)

        XCTAssertEqual(values, [1340])
    }

    func testBuffer_3() {
        let stream = source.buffer(count: 3)
        source.publish(1337)
        source.publish(1338)
        source.publish(1339)
        source.publish(1340)

        stream
            .addListener(self, handler: placeInValues)
            .bindLifetime(to: bag)

        XCTAssertEqual(values, [1338, 1339, 1340])
    }

    func testBuffer_beforeAndAfter() {
        let stream = source.buffer(count: 1)
        source.publish(1337)
        source.publish(1338)
        source.publish(1339)

        stream
            .addListener(self, handler: placeInValues)
            .bindLifetime(to: bag)

        source.publish(1340)

        XCTAssertEqual(values, [1339, 1340])
    }

    func testBuffer_twoSubscribers() {
        let stream = source.buffer(count: 2)
        var values1: [Int] = []
        var values2: [Int] = []

        source.publish(1337)
        source.publish(1338)

        stream
            .addListener(self, handler: { _, e in values1.append(e) })
            .bindLifetime(to: bag)

        source.publish(1339)

        stream
            .addListener(self, handler: { _, e in values2.append(e) })
            .bindLifetime(to: bag)

        source.publish(1340)

        XCTAssertEqual(values1, [1337, 1338, 1339, 1340])
        XCTAssertEqual(values2, [1338, 1339, 1340])
    }

    func testDistinct_same_onlyOne() {
        let stream = source.distinct()

        stream
            .addListener(self, handler: placeInValues)
            .bindLifetime(to: bag)

        source.publish(1337)
        source.publish(1337)
        source.publish(1337)

        XCTAssertEqual(values, [1337])
    }

    func testDistinct_differentDependingOnListener() {
        let stream = source.distinct()
        var values1: [Int] = []
        var values2: [Int] = []

        stream
            .addListener(self, handler: { _, e in values1.append(e) })
            .bindLifetime(to: bag)

        source.publish(1337)

        stream
            .addListener(self, handler: { _, e in values2.append(e) })
            .bindLifetime(to: bag)

        source.publish(1337)

        XCTAssertEqual(values1, [1337])
        XCTAssertEqual(values2, [1337])
    }

    func testDistinct_alternating_propagates() {
        let stream = source.distinct()

        stream
            .addListener(self, handler: placeInValues)
            .bindLifetime(to: bag)

        source.publish(1337)
        source.publish(1337)
        source.publish(1338)
        source.publish(1338)
        source.publish(1338)
        source.publish(1337)

        XCTAssertEqual(values, [1337, 1338, 1337])
    }

    func testUnsubscribe() {
        let stream = source

        var token: SignalToken?
        autoreleasepool {
            token = stream
                .addListener(self, handler: placeInValues)

            source.publish(1337)

            _ = token
            token = nil
        }
        source.publish(1338)

        XCTAssertEqual(values, [1337])
    }

    func testUnsubscribe_Buffer() {
        let stream = source.buffer(count: 3)
        source.publish(1337)

        var token: SignalToken?
        autoreleasepool {
            token = stream
                .addListener(self, handler: placeInValues)

            source.publish(1338)

            _ = token
            token = nil
        }
        source.publish(1339)

        XCTAssertEqual(values, [1337, 1338])
    }
}
