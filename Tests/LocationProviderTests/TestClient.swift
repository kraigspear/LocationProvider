import CoreLocation
@testable import LocationProvider
import Synchronization

/// One step of a scripted location stream.
enum UpdateStep: Sendable {
    /// Yields this update.
    case update(any LocationUpdate)
    /// Advances the clock before the next step. The stream runs it when the provider asks for its
    /// next element, so every earlier update has already been handled.
    case advance(Duration)
    /// Suspends until the stream is cancelled, without finishing.
    case stall
}

extension LocationProvider.Client {
    /// A client whose update stream plays `steps` in order, then finishes.
    static func test(
        _ steps: [UpdateStep],
        clock: TestClock,
        reverseGeocodeLocation: Result<String?, Error> = .success(nil)) -> Self
    {
        Self(
            updates: { _ in
                let remainingSteps = Mutex(steps[...])
                return AsyncThrowingStream(unfolding: {
                    while let step = remainingSteps.withLock({ $0.popFirst() }) {
                        switch step {
                        case let .update(update):
                            return update
                        case let .advance(duration):
                            clock.advance(by: duration)
                        case .stall:
                            try await clock.sleep(until: .init(offset: .seconds(Int64.max / 2)))
                        }
                    }
                    return nil
                })
            },
            reverseGeocodeLocation: { _ in
                try reverseGeocodeLocation.get()
            })
    }
}
