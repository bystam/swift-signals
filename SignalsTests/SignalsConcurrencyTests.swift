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
}
