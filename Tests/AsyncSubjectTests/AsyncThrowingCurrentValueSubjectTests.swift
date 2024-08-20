//
//  AsyncThrowingCurrentValueSubjectTests.swift
//  AsyncSubject
//
//  Created by Brent Mifsud on 2024-08-20.
//

import Foundation
import Testing

@testable import AsyncSubject

@Suite("Throwing current Value Subject Tests")
struct ThrowingCurrentValueSubjectTests {
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
        let storage = AsyncThrowingCurrentValueSubject<Int>._Storage()
        let subject = AsyncThrowingCurrentValueSubject<Int>(storage: storage)

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
                        #expect(await storage.currentValue == value)
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
        let storage = AsyncThrowingCurrentValueSubject<Int>._Storage()
        let subject = AsyncThrowingCurrentValueSubject<Int>(storage: storage)

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
                        #expect(await storage.currentValue == value)
                    }
                }
            }

            await group.waitForAll()
        }

        await storage.validateEndState()
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
        let storage = AsyncThrowingCurrentValueSubject<Int>._Storage()
        let subject = AsyncThrowingCurrentValueSubject<Int>(storage: storage)

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

            group.addTask {
                // Wait for the third value before subscribing
                await waitFor { await storage.failure != nil }

                var recievedValues = [Int]()
                do {
                    for try await value in subject {
                        recievedValues.append(value)
                    }
                } catch {
                    #expect((error as NSError) == failure)
                }

                #expect(recievedValues.isEmpty)
            }

            group.addTask {
                // Wait for the first subscriber before sending values
                await waitFor { await !storage.continuations.isEmpty }

                for value in values {
                    await subject.yield(value: value)
                    if value == 3 {
                        await waitFor { await storage.currentValue == 3 }
                        await subject.finish(throwing: failure)
                    }
                }
            }

            await group.waitForAll()
        }

        await storage.validateEndState()
    }
}

extension AsyncThrowingCurrentValueSubject._Storage {
    func validateInitialState() {
        #expect(currentValue == nil)
        #expect(!finished, "Initial state should not be finished")
        #expect(failure == nil, "Initial state should not have an error")
        #expect(continuations.isEmpty, "Initial state should not have continuations")
    }

    func validateEndState() {
        #expect(currentValue != nil)
        #expect(finished, "Final state should be finished")
        #expect(failure != nil, "Final state should have an error")
        #expect(continuations.isEmpty, "Final state should not have any continuations")
    }
}
