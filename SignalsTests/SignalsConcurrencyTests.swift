//
//  Copyright © 2018 Fredrik Bystam. All rights reserved.
//

import XCTest
@testable import Signals

class SignalsConcurrencyTests: XCTestCase {

    private let bag = SignalTokenBag()

    func testSource_threadSafety1() {
        let source = Source<Int>()
        var values: [Int] = []

        let exp = expectation(description: "lol")
        exp.expectedFulfillmentCount = 1000 * 100

        DispatchQueue.concurrentPerform(iterations: 1000) { i in
            source.listen { int in
                DispatchQueue.main.async {
                    values.append(int)
                    exp.fulfill()
                }
            }.bindLifetime(to: self.bag)
        }

        DispatchQueue.concurrentPerform(iterations: 100) { i in
            source.publish(i)
        }

        wait(for: [exp], timeout: 5.0)
        XCTAssertEqual(values.count, 1000 * 100)
    }

    func testSource_threadSafety2() {
        let source = Source<Int>()
        var values: [Int] = []

        let exp = expectation(description: "lol")
        exp.expectedFulfillmentCount = 1000

        source.listen { int in
            DispatchQueue.main.async {
                values.append(int)
                exp.fulfill()
            }
        }.bindLifetime(to: self.bag)

        DispatchQueue.concurrentPerform(iterations: 1000) { i in
            source.listen { _ in

            }.bindLifetime(to: self.bag)

            source.publish(i)
        }

        wait(for: [exp], timeout: 5.0)
        XCTAssertEqual(values.count, 1000)
    }

    func testReplay_threadSafety1() {
        let source = Source<Int>()
        let signal = source.replay(count: 1000)
        var values: [Int] = []

        DispatchQueue.concurrentPerform(iterations: 1000) { i in
            source.publish(i)
        }

        signal.listen { int in
            values.append(int)
        }.bindLifetime(to: self.bag)

        XCTAssertEqual(values.count, 1000)
    }

    func testCombine_threadSafety1() {
        let source1 = Source<Int>()
        let source2 = Source<Int>()
        let source3 = Source<Int>()
        let signal = Source<Int>.combine(source1, source2, source3) { a, b, c -> Int in
            return max(a, b, c)
        }
        var values: [Int] = []

        let exp = expectation(description: "lol")
        exp.expectedFulfillmentCount = 801

        signal.listen { int in
            DispatchQueue.main.async {
                values.append(int)
                exp.fulfill()
            }
        }.bindLifetime(to: self.bag)

        source2.publish(-1)
        source1.publish(-1)
        source3.publish(-1)

        DispatchQueue.concurrentPerform(iterations: 800) { i in
            signal.listen { _ in
            }.bindLifetime(to: self.bag)

            switch Int.random(in: 0...2) {
            case 0: source1.publish(i)
            case 1: source2.publish(i)
            case 2: source3.publish(i)
            default: fatalError()
            }
        }

        wait(for: [exp], timeout: 5.0)
        XCTAssertEqual(values.count, 801)
    }


    func testZip_threadSafety1() {
        let source1 = Source<Int>()
        let source2 = Source<Int>()
        let source3 = Source<Int>()
        let source4 = Source<Int>()
        let signal = Source<Int>.zip(source1, source2, source3, source4) { a, b, c, d -> Int in
            return max(a, b, c, d)
        }
        var values: [Int] = []

        let exp = expectation(description: "lol")
        exp.expectedFulfillmentCount = 1000

        signal.listen { int in
            DispatchQueue.main.async {
                values.append(int)
                exp.fulfill()
            }
        }.bindLifetime(to: self.bag)

        (0..<1000).forEach { outerInt in
            DispatchQueue.concurrentPerform(iterations: 4) { i in
                switch i % 4 {
                case 0: source1.publish(outerInt)
                case 1: source2.publish(outerInt)
                case 2: source3.publish(outerInt)
                case 3: source4.publish(outerInt)
                default: fatalError()
                }
            }
        }

        wait(for: [exp], timeout: 5.0)
        XCTAssertEqual(values.count, 1000)
    }
}
