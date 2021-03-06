//
//  Copyright © 2018 Fredrik Bystam. All rights reserved.
//

import XCTest
@testable import Signals

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
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)

        source.publish(1337)

        XCTAssertEqual(values, [1337])
    }

    func testSource_noValue_beforeAddListener() {
        let signal = source
        source.publish(1337)

        signal
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)

        XCTAssertEqual(values, [])
    }

    func testSource_orderOfListenersIsBackwards() {
        let signal = source

        signal
            .listen(with: self, { this, val in this.values.append(val + 1) })
            .bindLifetime(to: bag)
        signal
            .listen(with: self, { this, val in this.values.append(val + 2) })
            .bindLifetime(to: bag)

        source.publish(1337)

        XCTAssertEqual(values, [1339, 1338])
    }

    func testSource_publishOnlyToLatestListener() {
        let signal = Source<Int>(options: [.publishOnlyToLatestListener])

        signal
            .listen(with: self, { this, val in this.values.append(val + 1) })
            .bindLifetime(to: bag)
        signal
            .listen(with: self, { this, val in this.values.append(val + 2) })
            .bindLifetime(to: bag)

        signal.publish(1337)

        XCTAssertEqual(values, [1339])
    }

    func testTask_synchronous() {
        let signal = Task<Int>()

        signal
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)
        signal
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)

        signal.finish(1337)

        XCTAssertEqual(values, [1337, 1337])
    }

    func testJust_one() {
        let signal = Signal<Int>.just(5)

        signal
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)

        XCTAssertEqual(values, [5])
    }

    func testJust_repeating() {
        let signal = Signal<Int>.just(5)

        signal
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)
        signal
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)

        XCTAssertEqual(values, [5, 5])
    }

    func testDelay() {
        let signal = Signal<Void>.delay(0.1)
        let exp = expectation(description: "")

        signal
            .listen { exp.fulfill() }
            .bindLifetime(to: bag)

        waitForExpectations(timeout: 0.3) { error in
            XCTAssertNil(error)
        }
    }

    func testDebounce() {
        let signal = source
            .debounce(delay: 0.1)

        var values: [Int] = []
        let exp = expectation(description: "")

        signal
            .listen { int in
                values.append(int)
                exp.fulfill()
            }
            .bindLifetime(to: bag)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03, execute: { self.source.publish(1) })
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: { self.source.publish(2) })
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09, execute: { self.source.publish(3) })

        XCTAssertEqual(values, [])
        waitForExpectations(timeout: 0.3) { error in
            XCTAssertNil(error)
            XCTAssertEqual(values, [3])
        }
    }

    func testFilter() {
        let signal = source
            .filter { $0 < 5 }

        signal
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)

        source.publish(1)
        source.publish(3)
        source.publish(5)
        source.publish(4)

        XCTAssertEqual(values, [1, 3, 4])
    }

    func testMap() {
        let signal = source
            .map { int in String(int) }
            .map { string in string.count }

        signal
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)

        source.publish(1)
        source.publish(13)
        source.publish(133)
        source.publish(1337)

        XCTAssertEqual(values, [1, 2, 3, 4])
    }

    func testReplay_0() {
        let signal = source.replay(count: 0)
        source.publish(1337)
        source.publish(1338)
        source.publish(1339)
        source.publish(1340)

        signal
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)

        XCTAssertEqual(values, [])
    }

    func testReplay_1() {
        let signal = source.replay(count: 1)
        source.publish(1337)
        source.publish(1338)
        source.publish(1339)
        source.publish(1340)

        signal
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)

        XCTAssertEqual(values, [1340])
    }

    func testReplay_3() {
        let signal = source.replay(count: 3)
        source.publish(1337)
        source.publish(1338)
        source.publish(1339)
        source.publish(1340)

        signal
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)

        XCTAssertEqual(values, [1338, 1339, 1340])
    }

    func testReplay_beforeAndAfter() {
        let signal = source.replay(count: 1)
        source.publish(1337)
        source.publish(1338)
        source.publish(1339)

        signal
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)

        source.publish(1340)

        XCTAssertEqual(values, [1339, 1340])
    }

    func testReplay_twoSubscribers() {
        let signal = source.replay(count: 2)
        var values1: [Int] = []
        var values2: [Int] = []

        source.publish(1337)
        source.publish(1338)

        signal
            .listen(with: self, { _, e in values1.append(e) })
            .bindLifetime(to: bag)

        source.publish(1339)

        signal
            .listen(with: self, { _, e in values2.append(e) })
            .bindLifetime(to: bag)

        source.publish(1340)

        XCTAssertEqual(values1, [1337, 1338, 1339, 1340])
        XCTAssertEqual(values2, [1338, 1339, 1340])
    }

    func testDistinct_same_onlyOne() {
        let signal = source.distinct()

        signal
            .listen(with: self, placeInValues)
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
            .listen(with: self, { _, e in values1.append(e) })
            .bindLifetime(to: bag)

        source.publish(1337)

        signal
            .listen(with: self, { _, e in values2.append(e) })
            .bindLifetime(to: bag)

        source.publish(1337)

        XCTAssertEqual(values1, [1337])
        XCTAssertEqual(values2, [1337])
    }

    func testDistinct_alternating_propagates() {
        let signal = source.distinct()

        signal
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)

        source.publish(1337)
        source.publish(1337)
        source.publish(1338)
        source.publish(1338)
        source.publish(1338)
        source.publish(1337)

        XCTAssertEqual(values, [1337, 1338, 1337])
    }

    func testMergeMap_simple() {
        let signal = source
            .mergeMap { int in Signal.just(int * 10) }

        signal
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)

        source.publish(1)
        source.publish(2)
        source.publish(3)

        XCTAssertEqual(values, [10, 20, 30])
    }

    func testMergeMap_doubleAsync() {
        let secondSource = Source<Int>()
        let signal = source
            .mergeMap { _ in secondSource }

        signal
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)

        secondSource.publish(1)
        XCTAssertEqual(values, [])
        source.publish(2)
        XCTAssertEqual(values, [])
        secondSource.publish(3)
        secondSource.publish(4)
        secondSource.publish(5)
        XCTAssertEqual(values, [3, 4, 5])
    }

    func testMergeMap_withDelay() {
        let signal = source
            .mergeMap { int in Signal<Void>.delay(0.1).map { _ in int } }

        var values: [Int] = []
        let exp = expectation(description: "")
        exp.expectedFulfillmentCount = 3

        signal
            .listen { int in
                values.append(int)
                exp.fulfill()
            }
            .bindLifetime(to: bag)

        source.publish(1)
        source.publish(2)
        source.publish(3)

        XCTAssertEqual(values, [])
        waitForExpectations(timeout: 0.3) { error in
            XCTAssertNil(error)
            XCTAssertEqual(values, [1, 2, 3])
        }
    }

    func testMerge_noElements_beforeListening() {
        let source1 = Source<Int>()
        let source2 = Source<Int>()
        let signal = Signal<Int>.merge([source1, source2])

        source1.publish(1)
        source2.publish(2)
        source1.publish(3)

        signal
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)

        XCTAssertEqual(values, [])
    }

    func testMerge_someElements_afterListening() {
        let source1 = Source<Int>()
        let source2 = Source<Int>()
        let signal = Signal<Int>.merge([source1, source2])

        signal
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)

        source1.publish(1)
        source2.publish(2)
        source1.publish(3)

        XCTAssertEqual(values, [1, 2, 3])
    }

    func testCombine_noElement_beforeAll() {
        let source1 = Source<Int>()
        let source2 = Source<Int>()
        let signal = Signal<Int>.combine(source1, source2, with: +)

        signal
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)

        source1.publish(1)

        XCTAssertEqual(values, [])
    }

    func testCombine_oneElement_afterBoth() {
        let source1 = Source<Int>()
        let source2 = Source<Int>()
        let signal = Signal<Int>.combine(source1, source2, with: +)

        signal
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)

        source1.publish(1)
        source2.publish(2)

        XCTAssertEqual(values, [3])
    }

    func testCombine_oneElement_afterBothDespiteLateListening() {
        let source1 = Source<Int>()
        let source2 = Source<Int>()
        let signal = Signal<Int>.combine(source1, source2, with: +)

        source1.publish(1)

        signal
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)

        source2.publish(2)

        XCTAssertEqual(values, [3])
    }

    func testCombine_threeElements_afterTwoEach() {
        let source1 = Source<Int>()
        let source2 = Source<Int>()
        let signal = Signal<Int>.combine(source1, source2, with: +)

        signal
            .listen(with: self, placeInValues)
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
        let signal = Signal<Int>.combine(Signal<Int>.combine(source1, source2, with: +),
                                           Signal<Int>.combine(source3, source4, with: +),
                                           with: +)

        signal
            .listen(with: self, placeInValues)
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
        let signal = Signal<Int>.combine(Signal<Int>.combine(source1, source2, with: +),
                                           Signal<Int>.combine(source3, source4, with: +),
                                           with: +)

        signal
            .listen(with: self, placeInValues)
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
        let signal = Signal<Int>.combine(Signal<Int>.combine(source1, source2, with: +),
                                           Signal<Int>.combine(source3, source4, with: +),
                                           with: +)

        signal
            .listen(with: self, placeInValues)
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

    func testCombine_oneElement_afterBothWithTwoListeners() {
        let source1 = Source<Int>()
        let source2 = Source<Int>()
        let signal = Signal<Int>.combine(source1, source2, with: +)

        var values1: [Int] = []
        var values2: [Int] = []

        signal
            .listen(with: self, { _, e in values1.append(e) })
            .bindLifetime(to: bag)

        signal
            .listen(with: self, { _, e in values2.append(e) })
            .bindLifetime(to: bag)

        source1.publish(1)
        source1.publish(2)
        source2.publish(2)
        source2.publish(3)

        XCTAssertEqual(values1, [4, 5])
        XCTAssertEqual(values2, [4, 5])
    }

    func testZip_noElement_beforeAll() {
        let source1 = Source<Int>()
        let source2 = Source<Int>()
        let signal = Signal<Int>.zip(source1, source2, with: +)

        signal
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)

        source1.publish(1)

        XCTAssertEqual(values, [])
    }

    func testZip_noElement_ifProducedBeforeListening() {
        let source1 = Source<Int>()
        let source2 = Source<Int>()
        let signal = Signal<Int>.zip(source1, source2, with: +)

        source1.publish(1)
        source2.publish(1)

        signal
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)

        source1.publish(1)

        XCTAssertEqual(values, [])
    }

    func testZip_oneElement_afterBoth() {
        let source1 = Source<Int>()
        let source2 = Source<Int>()
        let signal = Signal<Int>.zip(source1, source2, with: +)

        signal
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)

        source1.publish(1)
        source2.publish(2)

        XCTAssertEqual(values, [3])
    }

    func testZip_oneElement_afterOneAndTwo() {
        let source1 = Source<Int>()
        let source2 = Source<Int>()
        let signal = Signal<Int>.zip(source1, source2, with: +)

        signal
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)

        source1.publish(1)
        source2.publish(2)
        source1.publish(3)

        XCTAssertEqual(values, [3])
    }

    func testZip_twoElements_afterTwoEach() {
        let source1 = Source<Int>()
        let source2 = Source<Int>()
        let signal = Signal<Int>.zip(source1, source2, with: +)

        signal
            .listen(with: self, placeInValues)
            .bindLifetime(to: bag)

        source1.publish(1)
        source2.publish(2)
        source1.publish(3)
        source2.publish(4)

        XCTAssertEqual(values, [3, 7])
    }

    func testZip_oneElement_afterBothWithTwoListeners() {
        let source1 = Source<Int>()
        let source2 = Source<Int>()
        let signal = Signal<Int>.zip(source1, source2, with: +)

        var values1: [Int] = []
        var values2: [Int] = []

        signal
            .listen(with: self, { _, e in values1.append(e) })
            .bindLifetime(to: bag)

        signal
            .listen(with: self, { _, e in values2.append(e) })
            .bindLifetime(to: bag)

        source1.publish(1)
        source2.publish(2)

        XCTAssertEqual(values1, [3])
        XCTAssertEqual(values2, [3])
    }

    func testComplex() {
        let source1 = Source<String>()
        let source2 = Source<String>()
        let source3 = Source<String>()
        let signal = Signal<String>
            .combine(source1, source2, source3, with: { min($0, $1, $2) })
            .distinct()
            .replay(count: 2)
            .map { $0.uppercased() }

        var values: [String] = []

        source1.publish("lemon")
        source2.publish("apple")
        source3.publish("banana")
        source1.publish("apple")
        source3.publish("ace")

        signal
            .listen(with: self, { values.append($1) })
            .bindLifetime(to: bag)

        source2.publish("aaa")

        XCTAssertEqual(values, [ "APPLE", "ACE", "AAA" ])
    }

    func testUnsubscribe() {
        let signal = source

        var token: SignalToken?
        autoreleasepool {
            token = signal
                .listen(with: self, placeInValues)

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
            .combine(source1, source2, source3, with: { min($0, $1, $2) })
            .distinct()
            .replay(count: 2)
            .map { $0.count }

        var token: SignalToken?
        autoreleasepool {
            token = signal
                .listen(with: self, placeInValues)

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
        let signal = source.replay(count: 3)
        source.publish(1337)

        var token: SignalToken?
        autoreleasepool {
            token = signal
                .listen(with: self, placeInValues)

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
        let signal = Signal<Int>.combine(source1, source2, with: +)

        var token: SignalToken?
        autoreleasepool {
            token = signal
                .listen(with: self, placeInValues)

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
        let signal = Signal<Int>.combine(Signal<Int>.combine(source1, source2, with: +),
                                           Signal<Int>.combine(source3, source4, with: +),
                                           with: +)

        var token: SignalToken?
        autoreleasepool {
            token = signal
                .listen(with: self, placeInValues)

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
                .listen(with: listener!, { self.values.append($1) })
                .bindLifetime(to: bag)

            source.publish(1337)
            listener = nil
        }
        source.publish(1338)

        XCTAssertEqual(values, [1337])
    }
}
