//
//  Copyright © 2018 Fredrik Bystam. All rights reserved.
//

import Foundation

extension Signal where Element: Equatable {

    func distinct() -> Signal<Element> {
        return OperandSignal(upstream: self, op: Distinct())
    }
}

private struct Distinct<Element: Equatable>: SignalOperator {

    func lift(_ handler: @escaping (Element) -> Void) -> (Element) -> Void {
        var previous: Element? = nil
        return { element in
            guard element != previous else { return }
            previous = element
            handler(element)
        }
    }
}
