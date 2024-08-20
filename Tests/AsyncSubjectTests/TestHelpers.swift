//
//  TestHelpers.swift
//  AsyncSubject
//
//  Created by Brent Mifsud on 2024-08-19.
//

func waitFor(trigger: @Sendable () async -> Bool) async {
    while await !trigger() {
        await Task.yield()
    }
}
