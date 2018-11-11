//
//  Copyright © 2018 Fredrik Bystam. All rights reserved.
//

import Foundation

extension Signal {

    func filter(_ predicate: @escaping (Element) -> Bool) -> Signal<Element> {
        return OperandSignal(upstream: self, op: Filter(predicate: predicate))
    }
}

private struct Filter<Element>: SignalOperator {

    let predicate: (Element) -> Bool

    func lift(_ handler: @escaping (Element) -> Void) -> (Element) -> Void {
        let predicate = self.predicate
        return { element in
            if predicate(element) {
                handler(element)
            }
        }
    }
}
