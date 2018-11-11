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

    private typealias Handler = (Element) -> Void

    private let options: Set<SourceOption>
    private var handlers: [UUID: Handler] = [:]

    init(options: Set<SourceOption> = []) {
        self.options = options
    }

    override func addListener<L>(_ listener: L, handler: @escaping (L, Element) -> Void) -> SignalToken where L : AnyObject {
        let id = UUID()

        handlers[id] = { [weak self, weak listener] element in
            guard let listener = listener else {
                self?.handlers[id] = nil
                return
            }
            handler(listener, element)
        }

        return SourceToken { [weak self] in
            self?.handlers[id] = nil
        }
    }

    func publish(_ element: Element) {
        handlers.values.forEach { $0(element) }
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
