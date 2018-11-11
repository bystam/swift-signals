//
//  Copyright © 2018 Fredrik Bystam. All rights reserved.
//

import Foundation

// MARK: - Signal

class Signal<Element> {

    init() {}

    func addListener<L: AnyObject>(_ listener: L, handler: @escaping (L, Element) -> Void) -> SignalToken {
        fatalError()
    }
}

enum SourceOption {
    case publishOnlyToLatestListener
}

final class Source<Element>: Signal<Element> {

    private typealias Handler = (Element) -> Bool

    private let options: Set<SourceOption>
    private var order: [UUID] = []
    private var handlers: [UUID: Handler] = [:]

    init(options: Set<SourceOption> = []) {
        self.options = options
    }

    override func addListener<L>(_ listener: L, handler: @escaping (L, Element) -> Void) -> SignalToken where L : AnyObject {
        let id = UUID()

        order.append(id)
        handlers[id] = { [weak self, weak listener] element in
            guard let listener = listener else {
                self?.removeListener(withID: id)
                return false
            }
            handler(listener, element)
            return true
        }

        return SourceToken { [weak self] in
            self?.removeListener(withID: id)
        }
    }

    func publish(_ element: Element) {
        for id in order.reversed() {
            let isHandled = handlers[id]?(element) ?? false
            if isHandled && options.contains(.publishOnlyToLatestListener) {
                break
            }
        }
    }

    private func removeListener(withID id: UUID) {
        handlers[id] = nil
        order.removeAll(where: { $0 == id })
    }
}

// MARK: - Subscriber tokens

protocol SignalToken: AnyObject {}

extension SignalToken {
    func bindLifetime(to bag: SignalTokenBag) {
        bag.tokens.append(self)
    }
}

final class SignalTokenBag: SignalToken {
    fileprivate var tokens: [SignalToken]

    init() {
        self.tokens = []
    }

    init(tokens: [SignalToken]) {
        self.tokens = tokens
    }
}

private final class SourceToken: SignalToken {
    
    private let unsubscribe: () -> Void
    
    fileprivate init(_ unsubscribe: @escaping () -> Void) {
        self.unsubscribe = unsubscribe
    }
    
    deinit {
        unsubscribe()
    }
}
