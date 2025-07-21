//
//  AsyncChannel+ToStream.swift
//  FoundationToolkit
//
//  Created by Lukasz Zajdel on 24/06/2025.
//

import AsyncAlgorithms

public extension AsyncSequence where Self: Sendable, Element: Sendable {
    /// Convert any AsyncSequence to AsyncStream
    func toAsyncStream() -> AsyncStream<Element> {
        AsyncStream { continuation in
            Task {
                do {
                    for try await element in self {
                        try Task.checkCancellation()
                        continuation.yield(element)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }
        }
    }
}

public extension AsyncStream where Element: Sendable {
    /// Adapts an `AsyncStream` into an `AsyncChannel`, preserving all values.
    /// - Returns: A channel that receives all elements from the stream.
    func toAsyncChannel(
    ) -> AsyncChannel<Element> {
        let channel = AsyncChannel<Element>()

        Task {
            do {
                for try await value in self {
                    try Task.checkCancellation()
                    await channel.send(value)
                }
                channel.finish()
            } catch {
                channel.finish()
            }
        }

        return channel
    }
}
