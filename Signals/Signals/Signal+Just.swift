//
//  Copyright © 2018 Fredrik Bystam. All rights reserved.
//

import Foundation

extension Signal {

    static func just(_ element: Element) -> Signal<Element> {
        return Just(element: element)
    }
}

private final class Just<Element>: Signal<Element> {

    private let element: Element

    init(element: Element) {
        self.element = element
    }

    override func listen(_ handler: @escaping (Element) -> Void) -> SignalToken {
        handler(element)
        return JustToken.shared
    }
}

private final class JustToken: SignalToken {
    static let shared = JustToken()
}
