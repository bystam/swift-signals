//
//  Copyright © 2018 Fredrik Bystam. All rights reserved.
//

import Foundation

protocol SignalToken {}

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

    fileprivate init(tokens: [SignalToken]) {
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

        return SourceToken { [weak self] in
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

extension Signal {
    static func combining<A, B>(_ a: Signal<A>, _ b: Signal<B>, with transform: @escaping (A, B) -> Element) -> Signal<Element> {
        return Combination<(A, B)>.two(a, b).map(transform)
    }

    static func combining<A, B, C>(_ a: Signal<A>, _ b: Signal<B>, _ c: Signal<C>, with transform: @escaping (A, B, C) -> Element) -> Signal<Element> {
        return Combination<(A, B, C)>.three(a, b, c).map(transform)
    }

    static func combining<A, B, C, D>(_ a: Signal<A>, _ b: Signal<B>, _ c: Signal<C>, _ d: Signal<D>, with transform: @escaping (A, B, C, D) -> Element) -> Signal<Element> {
        return Combination<(A, B, C, D)>.four(a, b, c, d).map(transform)
    }
}

private extension Signal {
    func typeErase() -> Signal<Any> {
        return map { $0 as Any }
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
        self.count = max(count, 0)

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
        return upstream.addListener(listener, handler: handler)
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

private final class Combination<Tuple>: Signal<Tuple> {

    private let upstreams: [Signal<Any>]
    private let transform: ([Any]) -> Tuple
    private var elements: [Any?]

    private init(upstreams: [Signal<Any>], transform: @escaping ([Any]) -> Tuple) {
        self.upstreams = upstreams
        self.transform = transform
        self.elements = Array(repeating: nil, count: upstreams.count)
    }

    static func two<A, B>(_ a: Signal<A>, _ b: Signal<B>) -> Signal<(A, B)> {
        let upstreams = [ a.typeErase(), b.typeErase() ]
        return Combination<(A, B)>(upstreams: upstreams, transform: { values in
            return (values[0] as! A, values[1] as! B)
        })
    }

    static func three<A, B, C>(_ a: Signal<A>, _ b: Signal<B>, _ c: Signal<C>) -> Signal<(A, B, C)> {
        let upstreams = [ a.typeErase(), b.typeErase(), c.typeErase() ]
        return Combination<(A, B, C)>(upstreams: upstreams, transform: { values in
            return (values[0] as! A, values[1] as! B, values[2] as! C)
        })
    }

    static func four<A, B, C, D>(_ a: Signal<A>, _ b: Signal<B>, _ c: Signal<C>, _ d: Signal<D>) -> Signal<(A, B, C, D)> {
        let upstreams = [ a.typeErase(), b.typeErase(), c.typeErase(), d.typeErase() ]
        return Combination<(A, B, C, D)>(upstreams: upstreams, transform: { values in
            return (values[0] as! A, values[1] as! B, values[2] as! C, values[3] as! D)
        })
    }

    override func addListener<L>(_ listener: L, handler: @escaping (L, Tuple) -> Void) -> SignalToken where L : AnyObject {
        let tokens = upstreams.enumerated().map { index, upstream in
            return upstream.addListener(listener, handler: { [weak self] l, element in
                guard let tuple = self?.mapValueIfAllPresent(element, at: index) else { return }
                handler(l, tuple)
            })
        }

        return SignalTokenBag(tokens: tokens)
    }

    private func mapValueIfAllPresent(_ value: Any, at index: Int) -> Tuple? {
        elements[index] = value
        let existingElements = elements.filter { $0 != nil }.map { $0! }
        if existingElements.count == upstreams.count {
            return transform(existingElements)
        }
        return nil
    }
}
