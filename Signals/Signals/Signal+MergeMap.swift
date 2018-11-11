//
//  Copyright © 2018 Fredrik Bystam. All rights reserved.
//

import Foundation


extension Signal {
    func mergeMap<DownstreamElement>(_ transform: @escaping (Element) -> Signal<DownstreamElement>) -> Signal<DownstreamElement> {
        fatalError()
    }
}

