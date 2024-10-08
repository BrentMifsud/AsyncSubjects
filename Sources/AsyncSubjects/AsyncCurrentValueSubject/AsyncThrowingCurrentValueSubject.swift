//
//  AsyncThrowingCurrentValueSubject.swift
//  AsyncSubject
//
//  Created by Brent Mifsud on 2024-08-19.
//

import Foundation

/// A shared `AsyncSequence` that yields its current value and value changes to its subscribers or fails
public struct AsyncThrowingCurrentValueSubject<Element: Sendable>: AsyncSequence, Sendable {
    public typealias Element = Element
    public typealias AsyncIterator = AsyncThrowingStream<Element, any Error>.AsyncIterator
    typealias Continuation = AsyncThrowingStream<Element, any Error>.Continuation

    private let storage: _Storage

    /// A shared `AsyncSequence` that yields value changes to its subscribers
    /// - Parameter value: the initial value
    public init(initialValue value: Element) {
        storage = _Storage(initialValue: value)
    }

    init(storage: _Storage) {
        self.storage = storage
    }

    /// Yield a new value to subscribers
    /// - Parameter value: `Element`
    public func yield(value: Element) async {
        await storage.yield(value: value)
    }

    /// Finish the subject gracefully or with an error
    /// - Parameter error: error to end the subject with. Send nil to end gracefully
    public func finish(throwing error: (any Error)? = nil) async {
        await storage.finish(throwing: error)
    }

    public func makeAsyncIterator() -> AsyncIterator {
        return storage.makeAsyncIterator()
    }
}

extension AsyncThrowingCurrentValueSubject {
    actor _Storage {
        private(set) var currentValue: Element?
        private(set) var finished: Bool = false
        private(set) var failure: (any Error)?
        private(set) var continuations: [UUID: AsyncThrowingStream<Element, any Error>.Continuation] = [:]

        init(initialValue: Element) {
            currentValue = initialValue
        }

        deinit {
            for id in continuations.keys {
                continuations[id]?.finish()
            }
        }

        nonisolated func makeAsyncIterator() -> AsyncIterator {
            let id = UUID()
            let (stream, continuation) = AsyncThrowingStream<Element, any Error>.makeStream()

            Task {
                await addContinuation(id: id, continuation: continuation)
            }

            return stream.makeAsyncIterator()
        }

        func yield(value: Element) {
            currentValue = value
            for id in continuations.keys {
                continuations[id]?.yield(value)
            }
        }

        func finish(throwing error: (any Error)? = nil) {
            guard !finished else {
                return
            }

            finished = true
            failure = error

            for id in continuations.keys {
                continuations[id]?.finish(throwing: error)
                continuations[id] = nil
            }
        }

        private func addContinuation(id: UUID, continuation: Continuation) {
            guard !finished else {
                continuation.finish(throwing: failure)
                return
            }

            continuation.onTermination = { _ in
                Task { [weak self] in
                    await self?.removeContinuation(id: id)
                }
            }

            continuations[id] = continuation

            if let currentValue {
                continuation.yield(currentValue)
            }
        }

        private func removeContinuation(id: UUID) {
            continuations[id]?.finish()
            continuations[id] = nil
        }
    }
}
