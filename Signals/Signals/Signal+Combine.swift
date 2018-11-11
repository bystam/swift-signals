//
//  Copyright © 2018 Fredrik Bystam. All rights reserved.
//

import Foundation

extension Signal {

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

    private func typeErase() -> Signal<Any> {
        return map { $0 as Any }
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
            return upstream.listen(with: self, { this, element in
                _ = this.generateValueIfFilled(inserting: element, at: index, in: &this.preListeningElements)
            })
        }

        upstreamToken = SignalTokenBag(tokens: tokens)
    }

    override func listen(_ handler: @escaping (Element) -> Void) -> SignalToken {
        var elements: [Any?] = preListeningElements

        let tokens = upstreams.enumerated().map { index, upstream in
            return upstream.listen(with: self, { this, element in
                guard let element = this.generateValueIfFilled(inserting: element, at: index, in: &elements) else { return }
                handler(element)
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
