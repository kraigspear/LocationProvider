import Foundation
import Synchronization

/// A clock that moves only when a test calls `advance(by:)`, so timeouts fire exactly when the test says.
final class TestClock: Clock, Sendable {
    struct Instant: InstantProtocol {
        var offset: Duration

        func advanced(by duration: Duration) -> Self {
            Self(offset: offset + duration)
        }

        func duration(to other: Self) -> Duration {
            other.offset - offset
        }

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.offset < rhs.offset
        }
    }

    private struct Sleeper {
        let deadline: Instant
        let continuation: CheckedContinuation<Void, Error>
    }

    private struct RegistrationWaiter {
        let count: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private struct State {
        var now = Instant(offset: .zero)
        var sleepers: [UUID: Sleeper] = [:]
        /// Sleeps cancelled before their continuation was stored; they resume throwing on registration.
        var cancelledBeforeRegistration: Set<UUID> = []
        var registrationWaiters: [RegistrationWaiter] = []

        /// Removes and returns the waiters satisfied by the current sleeper count.
        mutating func takeSatisfiedWaiters() -> [RegistrationWaiter] {
            let satisfied = registrationWaiters.filter { $0.count <= sleepers.count }
            registrationWaiters.removeAll { $0.count <= sleepers.count }
            return satisfied
        }
    }

    private let state = Mutex(State())

    var now: Instant {
        state.withLock { $0.now }
    }

    var minimumResolution: Duration {
        .zero
    }

    func sleep(until deadline: Instant, tolerance _: Duration? = nil) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                enum Registration { case stored([RegistrationWaiter]), due, cancelled }
                let registration = state.withLock { state -> Registration in
                    if state.cancelledBeforeRegistration.remove(id) != nil {
                        return .cancelled
                    }
                    if deadline <= state.now {
                        return .due
                    }
                    state.sleepers[id] = Sleeper(deadline: deadline, continuation: continuation)
                    return .stored(state.takeSatisfiedWaiters())
                }
                switch registration {
                case let .stored(satisfiedWaiters):
                    for waiter in satisfiedWaiters {
                        waiter.continuation.resume()
                    }
                case .due:
                    continuation.resume()
                case .cancelled:
                    continuation.resume(throwing: CancellationError())
                }
            }
        } onCancel: {
            let sleeper = state.withLock { state -> Sleeper? in
                if let sleeper = state.sleepers.removeValue(forKey: id) {
                    return sleeper
                }
                state.cancelledBeforeRegistration.insert(id)
                return nil
            }
            sleeper?.continuation.resume(throwing: CancellationError())
        }
    }

    /// Suspends until at least `count` sleeps are waiting on the clock, so a test can advance or
    /// cancel knowing the sleep is registered.
    func waitForSleepers(_ count: Int = 1) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let isSatisfied = state.withLock { state -> Bool in
                if state.sleepers.count >= count {
                    return true
                }
                state.registrationWaiters.append(RegistrationWaiter(count: count, continuation: continuation))
                return false
            }
            if isSatisfied {
                continuation.resume()
            }
        }
    }

    /// Moves time forward and wakes every sleeper whose deadline has passed.
    func advance(by duration: Duration) {
        let dueSleepers = state.withLock { state -> [Sleeper] in
            state.now = state.now.advanced(by: duration)
            let now = state.now
            let dueIDs = state.sleepers.filter { $0.value.deadline <= now }.map(\.key)
            return dueIDs.compactMap { state.sleepers.removeValue(forKey: $0) }
        }
        for sleeper in dueSleepers {
            sleeper.continuation.resume()
        }
    }
}
