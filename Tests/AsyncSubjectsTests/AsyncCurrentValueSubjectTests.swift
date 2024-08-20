//
//  AsyncCurrentValueSubjectTests.swift
//  AsyncSubject
//
//  Created by Brent Mifsud on 2024-08-20.
//

import Foundation
import Testing

@testable import AsyncSubjects

@Suite("Current Value Subject Tests")
struct AsyncCurrentValueSubjectTests {
    @Test("Initial value", arguments: [1])
    func initialValue(expectedValue: Int) async throws {
        let storage = AsyncCurrentValueSubject<Int>._Storage(initialValue: expectedValue)
        let subject = AsyncCurrentValueSubject(storage: storage)

        await storage.validateInitialState()

        let task = Task {
            var recievedValues = [Int]()
            for await value in subject {
                recievedValues.append(value)
            }
            #expect(recievedValues == [expectedValue])
        }

        await waitFor { await !storage.continuations.isEmpty }
        await subject.finish()
        await task.value
        await storage.validateEndState()
    }

    @Test("(Single subscriber) Test emitted Values", arguments: [[1, 2, 3]])
    func valuesAreValid(expectedValues: [Int]) async throws {
        let storage = AsyncCurrentValueSubject<Int>._Storage(initialValue: 0)
        let subject = AsyncCurrentValueSubject<Int>(storage: storage)

        await storage.validateInitialState()

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                var emittedValues = [Int]()

                for await value in subject {
                    emittedValues.append(value)
                }

                #expect(emittedValues == [0] + expectedValues)
            }

            group.addTask {
                // wait for the first subscriber before emitting values
                await waitFor { await !storage.continuations.isEmpty }

                for value in expectedValues {
                    await subject.yield(value: value)
                    #expect(await storage.currentValue == value)
                }

                await subject.finish()
            }

            await group.waitForAll()

            #expect(await storage.finished)
        }

        await storage.validateEndState()
    }

    @Test("(Multiple subscribers) Test emitted values", arguments: [[1, 2, 3]])
    func valuesAreValidWithMultipleSubscribers(expectedValues: [Int]) async throws {
        let storage = AsyncCurrentValueSubject<Int>._Storage(initialValue: 0)
        let subject = AsyncCurrentValueSubject<Int>(storage: storage)

        await storage.validateInitialState()

        await withTaskGroup(of: Void.self) { group in
            let createSubscriber = { @Sendable () async in
                var emittedValues = [Int]()

                for await value in subject {
                    emittedValues.append(value)
                }

                #expect(emittedValues == [0] + expectedValues)
            }

            for _ in 0..<3 {
                group.addTask {
                    await createSubscriber()
                }
            }

            group.addTask {
                // wait for all subscribers to connect before starting to emit values
                await waitFor { await storage.continuations.count == 3 }
                for value in expectedValues {
                    await subject.yield(value: value)
                    #expect(await storage.currentValue == value)
                }

                await subject.finish()
            }

            await group.waitForAll()
        }

        await storage.validateEndState()
    }

    @Test(
        "(Multiple subscribers) Test staggered subscribers",
        arguments: [
            (
                valuesToSend: [1, 2, 3, 4, 5],
                expectedValues: [3, 4, 5]
            )
        ]
    )
    func valuesAreValidStaggedSubscribers(arguments: ([Int], [Int])) async throws {
        let (values, expectedValues) = arguments
        let storage = AsyncCurrentValueSubject<Int>._Storage(initialValue: 0)
        let subject = AsyncCurrentValueSubject<Int>(storage: storage)

        await storage.validateInitialState()

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                var recievedValues = [Int]()
                for await value in subject {
                    recievedValues.append(value)
                }

                #expect(recievedValues == [0] + values)
            }

            group.addTask {
                // Wait for the third value before subscribing
                await waitFor { await storage.currentValue == 3 }

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
                    if value == 3 {
                        // after the third value, wait for the second subscriber before continuting
                        await waitFor { await storage.continuations.count > 1 }
                    }
                }

                await subject.finish()
            }

            await group.waitForAll()
        }

        await storage.validateEndState()
    }

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
        let storage = AsyncThrowingCurrentValueSubject<Int>._Storage(initialValue: 0)
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
                    #expect((error as NSError) == failure)
                }

                #expect(emittedValues == [0] + expected)
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
        let storage = AsyncThrowingCurrentValueSubject<Int>._Storage(initialValue: 0)
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
                    #expect((error as NSError) == failure)
                }

                #expect(emittedValues == [0] + expected)
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
        let storage = AsyncThrowingCurrentValueSubject<Int>._Storage(initialValue: 0)
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

                #expect(recievedValues == [0] + expectedValues)
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

extension AsyncCurrentValueSubject._Storage {
    func validateInitialState() {
        #expect(!finished, "Initial state should not be finished")
        #expect(continuations.isEmpty, "Initial state should not have continuations")
    }

    func validateEndState() {
        #expect(finished, "Final state should be finished")
        #expect(continuations.isEmpty, "Final state should not have any continuations")
    }
}
