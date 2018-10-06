//
//  Copyright © 2018 Fredrik Bystam. All rights reserved.
//

import Foundation

final class SignalToken {
    
    private let unsubscribe: () -> Void
    
    fileprivate init(_ unsubscribe: @escaping () -> Void) {
        self.unsubscribe = unsubscribe
    }
    
    deinit {
        unsubscribe()
    }

    func bindLifetime(to bag: SignalTokenBag) {
        bag.tokens.append(self)
    }
}

final class SignalTokenBag {
    fileprivate var tokens: [SignalToken] = []
}

class Signal<Element> {

    fileprivate init() {}

    func addListener<L: AnyObject>(_ listener: L, handler: @escaping (L, Element) -> Void) -> SignalToken {
        fatalError()
    }
}

final class Source<Element>: Signal<Element> {

    private typealias Handler = (Element) -> Void

    private var listeners: [UUID: Handler] = [:]

    override init() {}

    override func addListener<L>(_ listener: L, handler: @escaping (L, Element) -> Void) -> SignalToken where L : AnyObject {
        let id = UUID()

        listeners[id] = { [weak self, weak listener] element in
            guard let listener = listener else {
                self?.listeners[id] = nil
                return
            }
            handler(listener, element)
        }

        return SignalToken { [weak self] in
            self?.listeners[id] = nil
        }
    }

    func publish(_ element: Element) {
        listeners.values.forEach { $0(element) }
    }
}

extension Signal {
    func map<DownstreamElement>(_ mapper: @escaping (Element) -> DownstreamElement) -> Signal<DownstreamElement> {
        return Transform(upstream: self, mapper: mapper)
    }

    func buffer(count: Int) -> Signal<Element> {
        return Buffer(upstream: self, count: count)
    }
}

extension Signal where Element: Equatable {
    func distinct() -> Signal<Element> {
        return Distinct(upstream: self)
    }
}

private final class Transform<Element, UpstreamElement>: Signal<Element> {

    private let upstream: Signal<UpstreamElement>
    private let mapper: (UpstreamElement) -> Element

    init(upstream: Signal<UpstreamElement>, mapper: @escaping (UpstreamElement) -> Element) {
        self.upstream = upstream
        self.mapper = mapper
        super.init()
    }

    override func addListener<L>(_ listener: L, handler: @escaping (L, Element) -> Void) -> SignalToken where L : AnyObject {
        let mapper = self.mapper
        return upstream.addListener(listener, handler: { (l, element) in
            handler(l, mapper(element))
        })
    }
}

private final class Buffer<Element>: Signal<Element> {

    private let upstream: Signal<Element>
    private let count: Int
    private var buffer: [Element] = []

    private var upstreamToken: SignalToken?

    init(upstream: Signal<Element>, count: Int) {
        self.upstream = upstream
        self.count = count

        super.init()

        upstreamToken = upstream.addListener(self) { this, element in
            this.buffer.append(element)
            if this.buffer.count > this.count {
                this.buffer.removeFirst()
            }
        }
    }

    override func addListener<L>(_ listener: L, handler: @escaping (L, Element) -> Void) -> SignalToken where L : AnyObject {

        buffer.forEach { element in
            handler(listener, element)
        }

        return upstream.addListener(listener, handler: { [weak self] (l, element) in
            guard let self = self else { return }

            self.buffer.append(element)
            if self.buffer.count > self.count {
                self.buffer.removeFirst()
            }

            handler(l, element)
        })
    }
}

private final class Distinct<Element: Equatable>: Signal<Element> {

    private let upstream: Signal<Element>

    init(upstream: Signal<Element>) {
        self.upstream = upstream
        super.init()
    }

    override func addListener<L>(_ listener: L, handler: @escaping (L, Element) -> Void) -> SignalToken where L : AnyObject {
        var previous: Element? = nil
        return upstream.addListener(listener, handler: { (l, element) in
            guard element != previous else {
                return
            }
            previous = element
            handler(l, element)
        })
    }
}
