//
//  Copyright © 2018 Fredrik Bystam. All rights reserved.
//

import Foundation

extension Signal {
    func filter(_ predicate: @escaping (Element) -> Bool) -> Signal<Element> {
        return Filter(upstream: self, predicate: predicate)
    }

    func map<DownstreamElement>(_ mapper: @escaping (Element) -> DownstreamElement) -> Signal<DownstreamElement> {
        return Transform(upstream: self, mapper: mapper)
    }

    func replay(count: Int) -> Signal<Element> {
        return Buffer(upstream: self, count: count)
    }

    func mapAndMerge<DownstreamElement>(_ transform: @escaping (Element) -> Signal<DownstreamElement>) -> Signal<DownstreamElement> {
        fatalError()
    }
}

extension Signal where Element: Equatable {
    func distinct() -> Signal<Element> {
        return Distinct(upstream: self)
    }
}

extension Signal {

    static func merge(_ upstreams: [Signal<Element>]) -> Signal<Element> {
        return Merge(upstreams: upstreams)
    }

    static func combine<A, B>(_ a: Signal<A>, _ b: Signal<B>, with transform: @escaping (A, B) -> Element) -> Signal<Element> {
        let upstreams = [ a.typeErase(), b.typeErase() ]
        return Combinator<Element>(upstreams: upstreams, type: .combine, transform: { values in
            return transform(values[0] as! A, values[1] as! B)
        })
    }

    static func combine<A, B, C>(_ a: Signal<A>, _ b: Signal<B>, _ c: Signal<C>, with transform: @escaping (A, B, C) -> Element) -> Signal<Element> {
        let upstreams = [ a.typeErase(), b.typeErase(), c.typeErase() ]
        return Combinator<Element>(upstreams: upstreams, type: .combine, transform: { values in
            return transform(values[0] as! A, values[1] as! B, values[2] as! C)
        })
    }

    static func combine<A, B, C, D>(_ a: Signal<A>, _ b: Signal<B>, _ c: Signal<C>, _ d: Signal<D>, with transform: @escaping (A, B, C, D) -> Element) -> Signal<Element> {
        let upstreams = [ a.typeErase(), b.typeErase(), c.typeErase(), d.typeErase() ]
        return Combinator<Element>(upstreams: upstreams, type: .combine, transform: { values in
            return transform(values[0] as! A, values[1] as! B, values[2] as! C, values[3] as! D)
        })
    }

    static func zip<A, B>(_ a: Signal<A>, _ b: Signal<B>, with transform: @escaping (A, B) -> Element) -> Signal<Element> {
        let upstreams = [ a.typeErase(), b.typeErase() ]
        return Combinator<Element>(upstreams: upstreams, type: .zip, transform: { values in
            return transform(values[0] as! A, values[1] as! B)
        })
    }

    static func zip<A, B, C>(_ a: Signal<A>, _ b: Signal<B>, _ c: Signal<C>, with transform: @escaping (A, B, C) -> Element) -> Signal<Element> {
        let upstreams = [ a.typeErase(), b.typeErase(), c.typeErase() ]
        return Combinator<Element>(upstreams: upstreams, type: .zip, transform: { values in
            return transform(values[0] as! A, values[1] as! B, values[2] as! C)
        })
    }

    static func zip<A, B, C, D>(_ a: Signal<A>, _ b: Signal<B>, _ c: Signal<C>, _ d: Signal<D>, with transform: @escaping (A, B, C, D) -> Element) -> Signal<Element> {
        let upstreams = [ a.typeErase(), b.typeErase(), c.typeErase(), d.typeErase() ]
        return Combinator<Element>(upstreams: upstreams, type: .zip, transform: { values in
            return transform(values[0] as! A, values[1] as! B, values[2] as! C, values[3] as! D)
        })
    }
}

private extension Signal {
    func typeErase() -> Signal<Any> {
        return map { $0 as Any }
    }
}

private final class Filter<Element>: Signal<Element> {

    private let upstream: Signal<Element>
    private let predicate: (Element) -> Bool

    init(upstream: Signal<Element>, predicate: @escaping (Element) -> Bool) {
        self.upstream = upstream
        self.predicate = predicate
    }

    override func addListener<L>(_ listener: L, handler: @escaping (L, Element) -> Void) -> SignalToken where L : AnyObject {
        let predicate = self.predicate
        return upstream.addListener(listener, handler: { (l, element) in
            if predicate(element) {
                handler(l, element)
            }
        })
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
        return upstream.addListener(listener, handler: { l, element in
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

private final class Merge<Element>: Signal<Element> {

    private let upstreams: [Signal<Element>]

    init(upstreams: [Signal<Element>]) {
        self.upstreams = upstreams
    }

    override func addListener<L>(_ listener: L, handler: @escaping (L, Element) -> Void) -> SignalToken where L : AnyObject {
        let tokens = upstreams.map { upstream in
            return upstream.addListener(listener, handler: handler)
        }
        return SignalTokenBag(tokens: tokens)
    }
}

private final class Combinator<Element>: Signal<Element> {

    enum FrequencyType {
        case zip, combine
    }

    private let upstreams: [Signal<Any>]
    private let type: FrequencyType
    private let transform: ([Any]) -> Element

    private var preListeningElements: [Any?]
    private var upstreamToken: SignalToken?

    init(upstreams: [Signal<Any>], type: FrequencyType, transform: @escaping ([Any]) -> Element) {
        self.upstreams = upstreams
        self.type = type
        self.transform = transform
        self.preListeningElements = Array(repeating: nil, count: upstreams.count)

        super.init()

        let tokens = upstreams.enumerated().map { index, upstream in
            return upstream.addListener(self, handler: { [weak self] l, element in
                guard let self = self else { return }
                _ = self.generateValueIfFilled(inserting: element, at: index, in: &self.preListeningElements)
            })
        }

        upstreamToken = SignalTokenBag(tokens: tokens)
    }

    override func addListener<L>(_ listener: L, handler: @escaping (L, Element) -> Void) -> SignalToken where L : AnyObject {
        var elements: [Any?] = preListeningElements

        let tokens = upstreams.enumerated().map { index, upstream in
            return upstream.addListener(listener, handler: { [weak self] l, element in
                guard let element = self?.generateValueIfFilled(inserting: element, at: index, in: &elements) else { return }
                handler(l, element)
            })
        }

        return SignalTokenBag(tokens: tokens)
    }

    private func generateValueIfFilled(inserting value: Any, at index: Int, in elements: inout [Any?]) -> Element? {
        elements[index] = value
        let existingElements = elements.filter { $0 != nil }.map { $0! }
        if existingElements.count == upstreams.count {
            if type == .zip {
                elements = Array(repeating: nil, count: upstreams.count)
            }
            return transform(existingElements)
        }
        return nil
    }
}
