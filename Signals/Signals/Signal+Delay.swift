//
//  Copyright © 2018 Fredrik Bystam. All rights reserved.
//

import Foundation

extension Signal where Element == Void {

    static func delay(_ time: TimeInterval) -> Signal<Void> {
        let task = Task<Void>()
        DispatchQueue.main.asyncAfter(deadline: .now() + time) {
            task.finish(())
        }
        return task
    }
}
