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
        let signal = source

        signal
            .addListener(self, handler: placeInValues)
            .bindLifetime(to: bag)

        source.publish(1337)

        XCTAssertEqual(values, [1337])
    }

    func testSource_noValue_beforeAddListener() {
        let signal = source
        source.publish(1337)

        signal
            .addListener(self, handler: placeInValues)
            .bindLifetime(to: bag)

        XCTAssertEqual(values, [])
    }

    func testMap() {
        let signal = source
            .map { int in String(int) }
            .map { string in string.count }

        signal
            .addListener(self, handler: placeInValues)
            .bindLifetime(to: bag)

        source.publish(1)
        source.publish(13)
        source.publish(133)
        source.publish(1337)

        XCTAssertEqual(values, [1, 2, 3, 4])
    }

    func testBuffer_0() {
        let signal = source.buffer(count: 0)
        source.publish(1337)
        source.publish(1338)
        source.publish(1339)
        source.publish(1340)

        signal
            .addListener(self, handler: placeInValues)
            .bindLifetime(to: bag)

        XCTAssertEqual(values, [])
    }

    func testBuffer_1() {
        let signal = source.buffer(count: 1)
        source.publish(1337)
        source.publish(1338)
        source.publish(1339)
        source.publish(1340)

        signal
            .addListener(self, handler: placeInValues)
            .bindLifetime(to: bag)

        XCTAssertEqual(values, [1340])
    }

    func testBuffer_3() {
        let signal = source.buffer(count: 3)
        source.publish(1337)
        source.publish(1338)
        source.publish(1339)
        source.publish(1340)

        signal
            .addListener(self, handler: placeInValues)
            .bindLifetime(to: bag)

        XCTAssertEqual(values, [1338, 1339, 1340])
    }

    func testBuffer_beforeAndAfter() {
        let signal = source.buffer(count: 1)
        source.publish(1337)
        source.publish(1338)
        source.publish(1339)

        signal
            .addListener(self, handler: placeInValues)
            .bindLifetime(to: bag)

        source.publish(1340)

        XCTAssertEqual(values, [1339, 1340])
    }

    func testBuffer_twoSubscribers() {
        let signal = source.buffer(count: 2)
        var values1: [Int] = []
        var values2: [Int] = []

        source.publish(1337)
        source.publish(1338)

        signal
            .addListener(self, handler: { _, e in values1.append(e) })
            .bindLifetime(to: bag)

        source.publish(1339)

        signal
            .addListener(self, handler: { _, e in values2.append(e) })
            .bindLifetime(to: bag)

        source.publish(1340)

        XCTAssertEqual(values1, [1337, 1338, 1339, 1340])
        XCTAssertEqual(values2, [1338, 1339, 1340])
    }

    func testDistinct_same_onlyOne() {
        let signal = source.distinct()

        signal
            .addListener(self, handler: placeInValues)
            .bindLifetime(to: bag)

        source.publish(1337)
        source.publish(1337)
        source.publish(1337)

        XCTAssertEqual(values, [1337])
    }

    func testDistinct_differentDependingOnListener() {
        let signal = source.distinct()
        var values1: [Int] = []
        var values2: [Int] = []

        signal
            .addListener(self, handler: { _, e in values1.append(e) })
            .bindLifetime(to: bag)

        source.publish(1337)

        signal
            .addListener(self, handler: { _, e in values2.append(e) })
            .bindLifetime(to: bag)

        source.publish(1337)

        XCTAssertEqual(values1, [1337])
        XCTAssertEqual(values2, [1337])
    }

    func testDistinct_alternating_propagates() {
        let signal = source.distinct()

        signal
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

    func testCombine_noElement_beforeAll() {
        let source1 = Source<Int>()
        let source2 = Source<Int>()
        let signal = Signal<Int>.combining(source1, source2, with: +)

        signal
            .addListener(self, handler: placeInValues)
            .bindLifetime(to: bag)

        source1.publish(1)

        XCTAssertEqual(values, [])
    }

    func testCombine_oneElement_afterBoth() {
        let source1 = Source<Int>()
        let source2 = Source<Int>()
        let signal = Signal<Int>.combining(source1, source2, with: +)

        signal
            .addListener(self, handler: placeInValues)
            .bindLifetime(to: bag)

        source1.publish(1)
        source2.publish(2)

        XCTAssertEqual(values, [3])
    }

    func testCombine_threeElements_afterTwoEach() {
        let source1 = Source<Int>()
        let source2 = Source<Int>()
        let signal = Signal<Int>.combining(source1, source2, with: +)

        signal
            .addListener(self, handler: placeInValues)
            .bindLifetime(to: bag)

        source1.publish(1)
        source2.publish(2)
        source1.publish(3)
        source2.publish(4)

        XCTAssertEqual(values, [3, 5, 7])
    }

    func testCombineDeep_noElement_beforeAll() {
        let source1 = Source<Int>()
        let source2 = Source<Int>()
        let source3 = Source<Int>()
        let source4 = Source<Int>()
        let signal = Signal<Int>.combining(Signal<Int>.combining(source1, source2, with: +),
                                           Signal<Int>.combining(source3, source4, with: +),
                                           with: +)

        signal
            .addListener(self, handler: placeInValues)
            .bindLifetime(to: bag)

        source1.publish(1)
        source2.publish(1)
        source3.publish(1)

        XCTAssertEqual(values, [])
    }

    func testCombineDeep_oneElement_afterAll() {
        let source1 = Source<Int>()
        let source2 = Source<Int>()
        let source3 = Source<Int>()
        let source4 = Source<Int>()
        let signal = Signal<Int>.combining(Signal<Int>.combining(source1, source2, with: +),
                                           Signal<Int>.combining(source3, source4, with: +),
                                           with: +)

        signal
            .addListener(self, handler: placeInValues)
            .bindLifetime(to: bag)

        source1.publish(1)
        source2.publish(2)
        source3.publish(3)
        source4.publish(4)

        XCTAssertEqual(values, [10])
    }

    func testCombineDeep_fiveElements_afterTwoEach() {
        let source1 = Source<Int>()
        let source2 = Source<Int>()
        let source3 = Source<Int>()
        let source4 = Source<Int>()
        let signal = Signal<Int>.combining(Signal<Int>.combining(source1, source2, with: +),
                                           Signal<Int>.combining(source3, source4, with: +),
                                           with: +)

        signal
            .addListener(self, handler: placeInValues)
            .bindLifetime(to: bag)

        source1.publish(1)
        source2.publish(2)
        source3.publish(3)
        source4.publish(4)
        source1.publish(5)
        source2.publish(6)
        source3.publish(7)
        source4.publish(8)

        XCTAssertEqual(values, [10, 14, 18, 22, 26])
    }

    func testComplex() {
        let source1 = Source<String>()
        let source2 = Source<String>()
        let source3 = Source<String>()
        let signal = Signal<String>
            .combining(source1, source2, source3, with: { min($0, $1, $2) })
            .distinct()
            .buffer(count: 2)
            .map { $0.uppercased() }

        var values: [String] = []

        source1.publish("lemon")
        source2.publish("apple")
        source3.publish("banana")
        source1.publish("apple")
        source3.publish("ace")

        signal
            .addListener(self, handler: { values.append($1) })
            .bindLifetime(to: bag)

        source2.publish("aaa")

        XCTAssertEqual(values, [ "APPLE", "ACE", "AAA" ])
    }

    func testUnsubscribe() {
        let signal = source

        var token: SignalToken?
        autoreleasepool {
            token = signal
                .addListener(self, handler: placeInValues)

            source.publish(1337)

            _ = token
            token = nil
        }
        source.publish(1338)

        XCTAssertEqual(values, [1337])
    }

    func testUnsubscribe_complex() {
        let source1 = Source<String>()
        let source2 = Source<String>()
        let source3 = Source<String>()
        let signal = Signal<String>
            .combining(source1, source2, source3, with: { min($0, $1, $2) })
            .distinct()
            .buffer(count: 2)
            .map { $0.count }

        var token: SignalToken?
        autoreleasepool {
            token = signal
                .addListener(self, handler: placeInValues)

            source1.publish("lemon")
            source2.publish("apple")
            source3.publish("banana")

            _ = token
            token = nil
        }
        source1.publish("lemon2")

        XCTAssertEqual(values, [ "apple".count ])
    }

    func testUnsubscribe_buffer() {
        let signal = source.buffer(count: 3)
        source.publish(1337)

        var token: SignalToken?
        autoreleasepool {
            token = signal
                .addListener(self, handler: placeInValues)

            source.publish(1338)

            _ = token
            token = nil
        }
        source.publish(1339)

        XCTAssertEqual(values, [1337, 1338])
    }

    func testUnsubscribe_combination() {
        let source1 = Source<Int>()
        let source2 = Source<Int>()
        let signal = Signal<Int>.combining(source1, source2, with: +)

        var token: SignalToken?
        autoreleasepool {
            token = signal
                .addListener(self, handler: placeInValues)

            source1.publish(2)
            source2.publish(3)

            _ = token
            token = nil
        }
        source1.publish(4)
        source2.publish(5)

        XCTAssertEqual(values, [5])
    }

    func testUnsubscribe_deep() {
        let source1 = Source<Int>()
        let source2 = Source<Int>()
        let source3 = Source<Int>()
        let source4 = Source<Int>()
        let signal = Signal<Int>.combining(Signal<Int>.combining(source1, source2, with: +),
                                           Signal<Int>.combining(source3, source4, with: +),
                                           with: +)

        var token: SignalToken?
        autoreleasepool {
            token = signal
                .addListener(self, handler: placeInValues)

            source1.publish(2)
            source2.publish(3)
            source3.publish(4)
            source4.publish(5)

            _ = token
            token = nil
        }
        source1.publish(4)

        XCTAssertEqual(values, [14])
    }

    func testDeallocatedListener() {
        let signal = source

        var listener: NSObject? = nil
        autoreleasepool {
            listener = NSObject()
            signal
                .addListener(listener!, handler: { self.values.append($1) })
                .bindLifetime(to: bag)

            source.publish(1337)
            listener = nil
        }
        source.publish(1338)

        XCTAssertEqual(values, [1337])
    }
}
