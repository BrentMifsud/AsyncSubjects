# AsyncSubjects

A set of AsyncSequences that behave like Combine's PassthroughSubject and CurrentValueSubject

## Usage

### AsyncCurrentValueSubject

An async subject that emits its current value immediately, and then any yielded values to awaiting for-await loops

```swift
let subject = AsyncCurrentValueSubject<Int>(initialValue: 1)

let observation1 = Task {
    for await value in subject {
        /*
        Prints:
        "subscriber1 value: 1"
        ... 2 seconds later
        "subscriber1 value: 2"
        */
        print("subscriber1 value: \(value)")
    }
}

let observation2 = Task {
    for await value in subject {
        /*
        Prints:
        "subscriber2 value: 1"
        ... 2 seconds later
        "subscriber2 value: 2"
        */
        print("subscriber2 value: \(value)")
    }
}

let sendTask = Task {
    try await Task.sleep(for: .seconds(2)
    await subject.yield(value: 2)
    await subject.finish() // any values yielded after this will not be emitted by the subject
}

try? await sendTask.value
```

### AsyncPassthroughSubject

An async subject that emits any yielded values to any currently awaiting for-await loops.

```swift
let subject = AsyncPassthroughSubject<Int>()

let observation1 = Task {
    for await value in subject {
        /*
        Prints:
        "subscriber1 value: 1"
        */
        print("subscriber1 value: \(value)")
    }
}

let observation2 = Task {
    for await value in subject {
        /*
        Prints:
        "subscriber2 value: 1"
        */
        print("subscriber2 value: \(value)")
    }
}

let sendTask = Task {
    try await Task.sleep(for: .seconds(2)
    await subject.yield(value: 2)
    await subject.finish() // any values yielded after this will not be emitted by the subject
}

try? await sendTask.value
```

### AsyncThrowingCurrentValueSubject

An async subject that emits its current value immediately, and then any yielded values to awaiting for-await loops. The subject finishes when an error is thrown.

```swift
let subject = AsyncThrowingCurrentValueSubject<Int>(initialValue: 1)

let observation1 = Task {
    do {
        for try await value in subject {
            /*
            Prints:
            "subscriber1 value: 1"
            ... 2 seconds later
            "subscriber1 value: 2"
            */
            print("subscriber1 value: \(value)")
        }
    } catch {
        print("subscriber1 failed: \(error)")
    }
}

let observation2 = Task {
    do {
        for try await value in subject {
            /*
            Prints:
            "subscriber2 value: 1"
            ... 2 seconds later
            "subscriber2 value: 2"
            */
            print("subscriber2 value: \(value)")
        }
    } catch {
        print("subscriber2 failed: \(error)")
    }
}

let sendTask = Task {
    try await Task.sleep(for: .seconds(2)
    await subject.yield(value: 2)
    await subject.finish(throwing: NSError(domain: "some error", code: 1234)) // any values yielded after this will not be emitted by the subject
}
```

### AsyncThrowingPassthroughSubject

An async subject that emits any yielded values to awaiting for-await loops. The subject finishes when an error is thrown.

```swift
let subject = AsyncThrowingPassthroughSubject<Int>()

let observation1 = Task {
    do {
        for try await value in subject {
            /*
            Prints:
            "subscriber1 value: 1"
            */
            print("subscriber1 value: \(value)")
        }
    } catch {
        print("subscriber1 failed: \(error)")
    }
}

let observation2 = Task {
    do {
        for try await value in subject {
            /*
            Prints:
            "subscriber2 value: 1"
            */
            print("subscriber2 value: \(value)")
        }
    } catch {
        print("subscriber2 failed: \(error)")
    }
}

let sendTask = Task {
    try await Task.sleep(for: .seconds(2)
    await subject.yield(value: 1)
    await subject.finish(throwing: NSError(domain: "some error", code: 1234)) // any values yielded after this will not be emitted by the subject
}
```
