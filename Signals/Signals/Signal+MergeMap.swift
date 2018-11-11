//
//  Copyright © 2018 Fredrik Bystam. All rights reserved.
//

import Foundation

extension Signal {

    func mergeMap<DownstreamElement>(_ mapper: @escaping (Element) -> Signal<DownstreamElement>) -> Signal<DownstreamElement> {
        return OperandSignal(upstream: self, op: MergeMap(mapper: mapper))
    }
}

private struct MergeMap<Input, Output>: SignalOperator {

    let mapper: (Input) -> Signal<Output>

    func lift(_ handler: @escaping (Output) -> Void) -> (Input) -> Void {
        let mapper = self.mapper
        let bag = SignalTokenBag()

        return { inElement in
            let newSignal = mapper(inElement)
            newSignal.listen { outElement in
                handler(outElement)
            }.bindLifetime(to: bag)
        }
    }
}
