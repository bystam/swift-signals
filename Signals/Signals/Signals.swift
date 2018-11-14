//
//  Copyright © 2018 Fredrik Bystam. All rights reserved.
//

import Foundation

// MARK: - Signal

class Signal<Element> {

    init() {}

    func listen(_ handler: @escaping (Element) -> Void) -> SignalToken {
        fatalError()
    }

    final func listen<L: AnyObject>(with guarded: L, _ handler: @escaping (L, Element) -> Void) -> SignalToken {
        return listen { [weak guarded] element in
            guard let guarded = guarded else { return }
            handler(guarded, element)
        }
    }
}


// MARK: - Source

enum SourceOption {
    case publishOnlyToLatestListener
}

final class Source<Element>: Signal<Element> {

    private typealias Handler = (Element) -> Void

    private let options: Set<SourceOption>
    private var order: [UUID] = []
    private var handlers: [UUID: Handler] = [:]

    private let mutex = DispatchQueue(label: "Source.mutex", attributes: .concurrent)

    init(options: Set<SourceOption> = []) {
        self.options = options
    }

    override func listen(_ handler: @escaping (Element) -> Void) -> SignalToken {
        let id = UUID()
        mutate(id: id, set: handler)

        return SourceToken { [weak self] in
            self?.mutate(id: id, set: nil)
        }
    }

    func publish(_ element: Element) {
        var handlers: [Handler] = []
        mutex.sync {
            if self.options.contains(.publishOnlyToLatestListener) {
                if let handler = self.order.last.flatMap({ self.handlers[$0] }) {
                    handlers.append(handler)
                }
            } else {
                handlers = self.order.reversed()
                    .compactMap { self.handlers[$0] }
//                    .forEach { $0(element) }
            }
        }
        handlers.forEach { $0(element) }
    }

    private func mutate(id: UUID, set handler: Handler?) {
        mutex.async(flags: .barrier) {
            if let handler = handler {
                self.order.append(id)
                self.handlers[id] = handler
            } else {
                self.handlers[id] = nil
                self.order.removeAll(where: { $0 == id })
            }
        }
    }
}


// MARK: - Task

private let kDummyToken: SignalToken = SignalTokenBag()

final class Task<Element>: Signal<Element> {

    private typealias Handler = (Element) -> Void

    private var order: [UUID] = []
    private var handlers: [UUID: Handler] = [:]

    private var element: Element? = nil

    override func listen(_ handler: @escaping (Element) -> Void) -> SignalToken {
        if let element = element {
            handler(element)
            return kDummyToken
        }

        let id = UUID()
        order.append(id)
        handlers[id] = handler

        return SourceToken { [weak self] in
            self?.removeListener(withID: id)
        }
    }

    func finish(_ element: Element) {
        precondition(self.element == nil, "Can't finish Tasks twice")
        self.element = element
        order.reversed()
            .compactMap { handlers[$0] }
            .forEach { $0(element) }
    }

    private func removeListener(withID id: UUID) {
        handlers[id] = nil
        order.removeAll(where: { $0 == id })
    }
}


// MARK: - Operators

protocol SignalOperator {
    associatedtype Input
    associatedtype Output

    func onCreate(_ upstream: Signal<Input>) -> SignalToken?
    func lift(_ handler: @escaping (Output) -> Void) -> (Input) -> Void
}

extension SignalOperator {
    func onCreate(_ upstream: Signal<Input>) -> SignalToken? {
        return nil
    }
}

final class OperandSignal<Operator: SignalOperator>: Signal<Operator.Output> {

    private let upstream: Signal<Operator.Input>
    private let op: Operator
    private var upstreamToken: SignalToken?

    init(upstream: Signal<Operator.Input>, op: Operator) {
        self.upstream = upstream
        self.op = op
        super.init()
        self.upstreamToken = op.onCreate(upstream)
    }

    override func listen(_ handler: @escaping (Operator.Output) -> Void) -> SignalToken {
        return upstream.listen(op.lift(handler))
    }
}


// MARK: - Tokens

protocol SignalToken: AnyObject {}

extension SignalToken {
    func bindLifetime(to bag: SignalTokenBag) {
        bag.append(self)
    }
}

final class SignalTokenBag: SignalToken {

    private let mutex = DispatchQueue(label: "Source.mutex", attributes: .concurrent)
    private var tokens: [SignalToken]

    init() {
        self.tokens = []
    }

    init(tokens: [SignalToken]) {
        self.tokens = tokens
    }

    fileprivate func append(_ token: SignalToken) {
        mutex.async(flags: .barrier) {
            self.tokens.append(token)
        }
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
