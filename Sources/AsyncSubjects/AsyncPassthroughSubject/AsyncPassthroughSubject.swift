//
//  AsyncPassthroughSubject.swift
//  AsyncSubject
//
//  Created by Brent Mifsud on 2024-08-19.
//

import Foundation

/// A shared `AsyncSequence` that yields value changes to its subscribers
public struct AsyncPassthroughSubject<Element: Sendable>: AsyncSequence, Sendable {
    public typealias Element = Element
    public typealias AsyncIterator = AsyncStream<Element>.AsyncIterator
    typealias Continuation = AsyncStream<Element>.Continuation

    private let storage: _Storage

    /// A shared `AsyncSequence` that yields value changes to its subscribers
    public init() {
        storage = _Storage()
    }

    init(storage: _Storage) {
        self.storage = storage
    }

    /// Yield a new value to subscribers
    /// - Parameter value: `Element`
    public func yield(value: Element) async {
        await storage.yield(value: value)
    }

    /// Finish the subject
    public func finish() async {
        await storage.finish()
    }

    public func makeAsyncIterator() -> AsyncIterator {
        return storage.makeAsyncIterator()
    }
}

extension AsyncPassthroughSubject {
    actor _Storage {
        private(set) var finished: Bool = false
        private(set) var continuations: [UUID: AsyncStream<Element>.Continuation] = [:]

        deinit {
            for id in continuations.keys {
                continuations[id]?.finish()
            }
        }

        nonisolated func makeAsyncIterator() -> AsyncIterator {
            let id = UUID()
            let (stream, continuation) = AsyncStream<Element>.makeStream()

            Task {
                await addContinuation(id: id, continuation: continuation)
            }

            return stream.makeAsyncIterator()
        }

        func yield(value: Element) {
            for id in continuations.keys {
                continuations[id]?.yield(value)
            }
        }

        func finish() {
            guard !finished else {
                return
            }

            finished = true

            for id in continuations.keys {
                continuations[id]?.finish()
                continuations[id] = nil
            }
        }

        private func addContinuation(id: UUID, continuation: Continuation) {
            guard !finished else {
                return
            }

            continuation.onTermination = { _ in
                Task { [weak self] in
                    await self?.removeContinuation(id: id)
                }
            }

            continuations[id] = continuation
        }

        private func removeContinuation(id: UUID) {
            continuations[id]?.finish()
            continuations[id] = nil
        }
    }
}
