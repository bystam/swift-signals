//
//  Copyright © 2018 Fredrik Bystam. All rights reserved.
//

import Foundation

extension Signal {

    func replay(count: Int) -> Signal<Element> {
        return OperandSignal(upstream: self, op: Replay(count: count))
    }
}

private final class Replay<Element>: SignalOperator {

    let count: Int
    private var buffer: [Element] = []

    private let mutex = DispatchQueue(label: "Replay.mutex", attributes: .concurrent)

    init(count: Int) {
        self.count = count
    }

    func onCreate(_ upstream: Signal<Element>) -> SignalToken? {
        return upstream.listen(with: self, { this, element in
            this.mutex.async(flags: .barrier) {
                this.buffer.append(element)
                if this.buffer.count > this.count {
                    this.buffer.removeFirst()
                }
            }
        })
    }

    func lift(_ handler: @escaping (Element) -> Void) -> (Element) -> Void {
        mutex.sync {
            buffer.forEach { handler($0) }
        }
        return handler
    }
}
