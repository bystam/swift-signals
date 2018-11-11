//
//  Copyright © 2018 Fredrik Bystam. All rights reserved.
//

import Foundation

extension Signal {

    func map<DownstreamElement>(_ mapper: @escaping (Element) -> DownstreamElement) -> Signal<DownstreamElement> {
        return OperandSignal(upstream: self, op: Map(mapper: mapper))
    }
}

private struct Map<Input, Output>: SignalOperator {

    let mapper: (Input) -> Output

    func lift(_ handler: @escaping (Output) -> Void) -> (Input) -> Void {
        let mapper = self.mapper
        return { inElement in handler(mapper(inElement)) }
    }
}
