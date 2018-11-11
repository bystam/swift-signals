//
//  Copyright © 2018 Fredrik Bystam. All rights reserved.
//

import Foundation

extension Signal {

    func debounce(delay: TimeInterval) -> Signal<Element> {
        return OperandSignal(upstream: self, op: Debounce(delay: delay))
    }
}

private struct Debounce<Element>: SignalOperator {

    let delay: TimeInterval

    func lift(_ handler: @escaping (Element) -> Void) -> (Element) -> Void {
        var current: DispatchWorkItem?
        return { element in
            current?.cancel()
            current = DispatchWorkItem {
                handler(element)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + self.delay, execute: current!)
        }
    }
}
