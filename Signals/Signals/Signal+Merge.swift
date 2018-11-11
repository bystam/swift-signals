//
//  Copyright © 2018 Fredrik Bystam. All rights reserved.
//

import Foundation

extension Signal {

    static func merge(_ upstreams: [Signal<Element>]) -> Signal<Element> {
        return Merge(upstreams: upstreams)
    }
}

private final class Merge<Element>: Signal<Element> {

    private let upstreams: [Signal<Element>]

    init(upstreams: [Signal<Element>]) {
        self.upstreams = upstreams
    }

    override func listen(_ handler: @escaping (Element) -> Void) -> SignalToken {
        let tokens = upstreams.map { upstream in
            return upstream.listen(handler)
        }
        return SignalTokenBag(tokens: tokens)
    }
}
