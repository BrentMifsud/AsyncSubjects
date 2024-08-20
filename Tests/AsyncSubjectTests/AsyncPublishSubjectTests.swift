//
//  AsyncPublishSubjectTests.swift
//  AsyncSubject
//
//  Created by Brent Mifsud on 2024-08-20.
//

import Testing
import Foundation
import AsyncAlgorithms
@testable import AsyncSubject

@Suite("Publish Subject Tests")
struct AsyncPublishSubjectTests {
    @Test("(Single subscriber) Test emitted Values", arguments: [[1, 2, 3]])
    func valuesAreValid(expectedValues: [Int]) async throws {
        let storage = AsyncPublishSubject<Int>._Storage()
        let subject = AsyncPublishSubject<Int>(storage: storage)

        await storage.validateInitialState()

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                var emittedValues = [Int]()

                for await value in subject {
                    emittedValues.append(value)
                }

                #expect(emittedValues == expectedValues)
            }

            group.addTask {
                // wait for the first subscriber before emitting values
                await waitFor { await !storage.continuations.isEmpty }

                for value in expectedValues {
                    await subject.yield(value: value)
                }

                await subject.finish()
            }

            await group.waitForAll()
        }

        await storage.validateEndState()
    }

    @Test("(Multiple subscribers) Test emitted values", arguments: [[1, 2, 3]])
    func valuesAreValidWithMultipleSubscribers(expectedValues: [Int]) async throws {
        let storage = AsyncPublishSubject<Int>._Storage()
        let subject = AsyncPublishSubject<Int>(storage: storage)

        await storage.validateInitialState()

        await withTaskGroup(of: Void.self) { group in
            let createSubscriber = { @Sendable () async in
                var emittedValues = [Int]()

                for await value in subject {
                    emittedValues.append(value)
                }

                #expect(emittedValues == expectedValues)
            }

            for _ in 0 ..< 3 {
                group.addTask {
                    await createSubscriber()
                }
            }

            group.addTask {
                // wait for all subscribers to connect before starting to emit values
                await waitFor { await storage.continuations.count == 3 }
                for value in expectedValues {
                    await subject.yield(value: value)
                }

                await subject.finish()
            }

            await group.waitForAll()
        }

        await storage.validateEndState()
    }

    @Test(
        "(Multiple subscribers) Test staggered subscribers",
        arguments: [(
            valuesToSend: [1, 2, 3, 4 ,5],
            expectedValues: [3, 4, 5]
        )]
    )
    func valuesAreValidStaggedSubscribers(arguments: ([Int], [Int])) async throws {
        let (values, expectedValues) = arguments
        let storage = AsyncPublishSubject<Int>._Storage()
        let subject = AsyncPublishSubject<Int>(storage: storage)

        await storage.validateInitialState()

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                var recievedValues = [Int]()
                for await value in subject {
                    recievedValues.append(value)
                }

                #expect(recievedValues == values)
            }

            let trigger = AsyncChannel<Void>()

            group.addTask {
                // Wait for the third value before subscribing
                await waitFor {
                    for await _ in trigger {
                        return true
                    }

                    return false
                }

                var recievedValues = [Int]()
                for await value in subject {
                    recievedValues.append(value)
                }

                #expect(recievedValues == expectedValues)
            }

            group.addTask {
                // Wait for the first subscriber before sending values
                await waitFor { await !storage.continuations.isEmpty }

                for value in values {
                    await subject.yield(value: value)
                    if value == 2 {
                        await trigger.send(())
                        // after the second value, wait for second subscriber before continuting
                        await waitFor { await storage.continuations.count > 1 }
                    }
                }

                await subject.finish()
            }

            await group.waitForAll()
        }

        await storage.validateEndState()
    }
}

extension AsyncPublishSubject._Storage {
    func validateInitialState() {
        #expect(!finished, "Initial state should not be finished")
        #expect(continuations.isEmpty, "Initial state should not have continuations")
    }

    func validateEndState() {
        #expect(finished, "Final state should be finished")
        #expect(continuations.isEmpty, "Final state should not have any continuations")
    }
}
