//
//  Copyright © 2018 Fredrik Bystam. All rights reserved.
//

import Foundation

extension Signal {

    static func combine<A, B>(_ a: Signal<A>, _ b: Signal<B>, with transform: @escaping (A, B) -> Element) -> Signal<Element> {
        let upstreams = [ a.typeErase(), b.typeErase() ]
        return Combinator<Element>(upstreams: upstreams, resetOnGenerate: false, transform: { values in
            return transform(values[0] as! A, values[1] as! B)
        })
    }

    static func combine<A, B, C>(_ a: Signal<A>, _ b: Signal<B>, _ c: Signal<C>, with transform: @escaping (A, B, C) -> Element) -> Signal<Element> {
        let upstreams = [ a.typeErase(), b.typeErase(), c.typeErase() ]
        return Combinator<Element>(upstreams: upstreams, resetOnGenerate: false, transform: { values in
            return transform(values[0] as! A, values[1] as! B, values[2] as! C)
        })
    }

    static func combine<A, B, C, D>(_ a: Signal<A>, _ b: Signal<B>, _ c: Signal<C>, _ d: Signal<D>, with transform: @escaping (A, B, C, D) -> Element) -> Signal<Element> {
        let upstreams = [ a.typeErase(), b.typeErase(), c.typeErase(), d.typeErase() ]
        return Combinator<Element>(upstreams: upstreams, resetOnGenerate: false, transform: { values in
            return transform(values[0] as! A, values[1] as! B, values[2] as! C, values[3] as! D)
        })
    }

    static func zip<A, B>(_ a: Signal<A>, _ b: Signal<B>, with transform: @escaping (A, B) -> Element) -> Signal<Element> {
        let upstreams = [ a.typeErase(), b.typeErase() ]
        return Combinator<Element>(upstreams: upstreams, resetOnGenerate: true, transform: { values in
            return transform(values[0] as! A, values[1] as! B)
        })
    }

    static func zip<A, B, C>(_ a: Signal<A>, _ b: Signal<B>, _ c: Signal<C>, with transform: @escaping (A, B, C) -> Element) -> Signal<Element> {
        let upstreams = [ a.typeErase(), b.typeErase(), c.typeErase() ]
        return Combinator<Element>(upstreams: upstreams, resetOnGenerate: true, transform: { values in
            return transform(values[0] as! A, values[1] as! B, values[2] as! C)
        })
    }

    static func zip<A, B, C, D>(_ a: Signal<A>, _ b: Signal<B>, _ c: Signal<C>, _ d: Signal<D>, with transform: @escaping (A, B, C, D) -> Element) -> Signal<Element> {
        let upstreams = [ a.typeErase(), b.typeErase(), c.typeErase(), d.typeErase() ]
        return Combinator<Element>(upstreams: upstreams, resetOnGenerate: true, transform: { values in
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
    private let resetOnGenerate: Bool
    private let transform: ([Any]) -> Element

    private let preListeningElements: Elements
//    private var preListeningElements: [Any?]
    private var upstreamToken: SignalToken?

    init(upstreams: [Signal<Any>], resetOnGenerate: Bool, transform: @escaping ([Any]) -> Element) {
        self.upstreams = upstreams
        self.resetOnGenerate = resetOnGenerate
        self.transform = transform
        self.preListeningElements = Elements(array: Array(repeating: nil, count: upstreams.count))

        super.init()

        let tokens = upstreams.enumerated().map { index, upstream in
            return upstream.listen(with: self, { this, element in
                _ = this.preListeningElements.insert(value: element, at: index, resetOnGenerate: resetOnGenerate)
//                _ = this.generateValueIfFilled(inserting: element, at: index, in: &this.preListeningElements)
            })
        }

        upstreamToken = SignalTokenBag(tokens: tokens)
    }

    override func listen(_ handler: @escaping (Element) -> Void) -> SignalToken {
        let elements = preListeningElements.clone()

        let tokens = upstreams.enumerated().map { index, upstream in
            return upstream.listen(with: self, { this, element in
                let generated = elements.insert(value: element, at: index, resetOnGenerate: this.resetOnGenerate)
                generated.map(this.transform).map(handler)
            })
        }

        return SignalTokenBag(tokens: tokens)
    }
//
//    private func generateValueIfFilled(inserting value: Any, at index: Int, in elements: inout [Any?]) -> Element? {
//        elements[index] = value
//        let existingElements = elements.filter { $0 != nil }.map { $0! }
//        if existingElements.count == upstreams.count {
//            if type == .zip {
//                elements = Array(repeating: nil, count: upstreams.count)
//            }
//            return transform(existingElements)
//        }
//        return nil
//    }
}

private final class Elements {

    private var array: [Any?]
    private let mutex = DispatchQueue(label: "Combinator.Elements.mutex", attributes: .concurrent)

    init(array: [Any?]) {
        self.array = array
    }

    func insert(value: Any, at index: Int, resetOnGenerate: Bool) -> [Any]? {
        return mutex.sync(flags: .barrier) {
            array[index] = value
            let existingElements = array.filter { $0 != nil }.map { $0! }
            if existingElements.count == array.count {
                if resetOnGenerate {
                    array = Array(repeating: nil, count: array.count)
                }
                return existingElements
            }
            return nil
        }
    }

    func clone() -> Elements {
        return mutex.sync(flags: .barrier) {
            return Elements(array: array)
        }
    }
}
