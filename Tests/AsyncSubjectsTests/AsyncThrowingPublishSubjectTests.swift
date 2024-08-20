//
//  AsyncThrowingPublishSubjectTests.swift
//  AsyncSubject
//
//  Created by Brent Mifsud on 2024-08-20.
//

import AsyncAlgorithms
import Foundation
import Testing

@testable import AsyncSubject

@Suite("Throwing Publish Subject Tests")
struct AsyncThrowingPublishSubjectTests {
    @Test(
        "(Single subscriber) Test throwing error",
        arguments: [
            (
                valuesToSend: [1, 2, 3, 4, 5],
                expectedValues: [1, 2, 3],
                expectedFailure: NSError(domain: "Test", code: 999)
            )
        ]
    )
    func valuesAreValidAfterThrow(arguments: ([Int], [Int], NSError)) async throws {
        let (values, expected, failure) = arguments
        let storage = AsyncThrowingPublishSubject<Int>._Storage()
        let subject = AsyncThrowingPublishSubject<Int>(storage: storage)

        await storage.validateInitialState()

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                var emittedValues = [Int]()

                do {
                    for try await value in subject {
                        emittedValues.append(value)
                    }
                } catch {
                    #expect(emittedValues == expected)
                    #expect((error as NSError) == failure)
                    return
                }
            }

            group.addTask {
                await waitFor { await !storage.continuations.isEmpty }

                for value in values {
                    if value == 4 {
                        await subject.finish(throwing: failure)
                        return
                    } else {
                        await subject.yield(value: value)
                    }
                }
            }

            await group.waitForAll()
        }

        await storage.validateEndState()
    }

    @Test(
        "(Multiple subscribers) Test throwing error",
        arguments: [
            (
                valuesToSend: [1, 2, 3, 4, 5],
                expectedValues: [1, 2, 3],
                expectedFailure: NSError(domain: "Test", code: 999)
            )
        ]
    )
    func valuesAreValidAfterThrowMultipleSubscribers(arguments: ([Int], [Int], NSError)) async throws {
        let (values, expected, failure) = arguments
        let storage = AsyncThrowingPublishSubject<Int>._Storage()
        let subject = AsyncThrowingPublishSubject<Int>(storage: storage)

        await storage.validateInitialState()

        await withTaskGroup(of: Void.self) { group in
            let createSubscriber = { @Sendable () async in
                var emittedValues = [Int]()

                do {
                    for try await value in subject {
                        emittedValues.append(value)
                    }
                } catch {
                    #expect(emittedValues == expected)
                    #expect((error as NSError) == failure)
                }

                #expect(emittedValues == expected)
            }

            for _ in 0..<3 {
                group.addTask {
                    await createSubscriber()
                }
            }

            group.addTask {
                // wait for all subscribers to connect before sending values
                await waitFor { await storage.continuations.count == 3 }
                for value in values {
                    if value == 4 {
                        await subject.finish(throwing: failure)
                        return
                    } else {
                        await subject.yield(value: value)
                    }
                }

                await subject.finish()
            }

            await group.waitForAll()

            await storage.validateEndState()
        }
    }

    @Test(
        "(Multiple subscribers) Test staggered subscribers failure",
        arguments: [
            (
                valuesToSend: [1, 2, 3, 4, 5],
                expectedValues: [1, 2, 3],
                failure: NSError(domain: "Test", code: 999)
            )
        ]
    )
    func failedSubscriberDoesNotreceiveCurrentValue(arguments: ([Int], [Int], NSError)) async throws {
        let (values, expectedValues, failure) = arguments
        let storage = AsyncThrowingPublishSubject<Int>._Storage()
        let subject = AsyncThrowingPublishSubject<Int>(storage: storage)

        await storage.validateInitialState()

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                var recievedValues = [Int]()
                do {
                    for try await value in subject {
                        print("Value: \(value)")
                        recievedValues.append(value)
                    }
                } catch {
                    #expect((error as NSError) == failure)
                }

                #expect(recievedValues == expectedValues)
            }

            let trigger = AsyncChannel<Void>()

            group.addTask {
                // wait for failure before subscribing
                await waitFor { await storage.failure != nil }

                var recievedValues = [Int]()

                do {
                    for try await value in subject {
                        recievedValues.append(value)
                    }
                } catch {
                    #expect((error as NSError) == failure)
                }

                // The above async for loop should fail immediately because
                // the subject has already emitted a failure at this point
                await trigger.send(())

                #expect(recievedValues.isEmpty)
            }

            group.addTask {
                // Wait for the first subscriber before sending values
                await waitFor { await !storage.continuations.isEmpty }

                for value in values {
                    await subject.yield(value: value)
                    if value == 3 {
                        await subject.finish(throwing: failure)
                        // wait for the second subscriber to attempt subscribing before continuing
                        await waitFor {
                            for await _ in trigger {
                                return true
                            }

                            return false
                        }
                    }
                }
            }

            await group.waitForAll()
        }

        await storage.validateEndState()
    }
}

extension AsyncThrowingPublishSubject._Storage {
    func validateInitialState() {
        #expect(!finished, "Initial state should not be finished")
        #expect(failure == nil, "Initial state should not have an error")
        #expect(continuations.isEmpty, "Initial state should not have continuations")
    }

    func validateEndState() {
        #expect(finished, "Final state should be finished")
        #expect(failure != nil, "Final state should have an error")
        #expect(continuations.isEmpty, "Final state should not have any continuations")
    }
}
