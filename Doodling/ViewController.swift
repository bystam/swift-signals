//
//  Copyright © 2018 Fredrik Bystam. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
}

protocol Session {
    var id: String { get }

    var refreshed: Signal<String> { get }
    var ended: Signal<Void> { get }
}

private final class AppSession: Session {

    private(set) var id: String

    private let _refreshed = Source<String>()
    private let _ended = Source<Date>()

    let refreshed: Signal<String>
    let ended: Signal<Void>

    init(id: String) {
        self.id = id

        refreshed = _refreshed.buffer(count: 3)
        ended = _ended.map { _ in () }
    }
}
