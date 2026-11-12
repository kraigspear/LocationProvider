import Testing

/// The provider tests rely on `TestClock` resuming each sleep exactly once, so its handoffs get their own tests.
/// A broken resume path hangs these tests rather than failing them; `test.sh` turns that hang into a failure.
@Suite(.timeLimit(.minutes(1)))
struct TestClockTests {
    @Test("A sleep whose deadline has already passed returns immediately")
    func pastDeadlineReturnsImmediately() async throws {
        let clock = TestClock()
        clock.advance(by: .seconds(5))

        try await clock.sleep(until: .init(offset: .seconds(5)))
    }

    @Test("Advancing to the deadline resumes a registered sleep")
    func advanceResumesRegisteredSleep() async throws {
        let clock = TestClock()
        let sleepTask = Task { try await clock.sleep(until: .init(offset: .seconds(5))) }
        await clock.waitForSleepers()

        clock.advance(by: .seconds(5))

        try await sleepTask.value
    }

    @Test("Advancing short of the deadline leaves the sleep waiting")
    func advanceShortOfDeadlineKeepsSleeping() async throws {
        let clock = TestClock()
        let sleepTask = Task { try await clock.sleep(until: .init(offset: .seconds(5))) }
        await clock.waitForSleepers()

        clock.advance(by: .seconds(4))
        // Still registered, so waiting for one sleeper returns at once
        await clock.waitForSleepers()
        clock.advance(by: .seconds(1))

        try await sleepTask.value
    }

    @Test("Cancelling a registered sleep throws CancellationError")
    func cancelAfterRegistrationThrows() async {
        let clock = TestClock()
        let sleepTask = Task { try await clock.sleep(until: .init(offset: .seconds(5))) }
        await clock.waitForSleepers()

        sleepTask.cancel()

        await #expect(throws: CancellationError.self) { try await sleepTask.value }
        // The cancelled sleep must be gone, or this advance would resume it a second time
        clock.advance(by: .seconds(5))
    }

    @Test("A sleep started in an already-cancelled task throws CancellationError")
    func cancelBeforeRegistrationThrows() async {
        let clock = TestClock()
        let sleepTask = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await clock.sleep(until: .init(offset: .seconds(5)))
        }

        await #expect(throws: CancellationError.self) { try await sleepTask.value }
    }

    @Test("Cancel racing advance resumes the sleep exactly once", arguments: 0 ..< 200)
    func cancelRacingAdvanceResumesOnce(iteration _: Int) async {
        // Given: a registered sleep
        let clock = TestClock()
        let sleepTask = Task { try await clock.sleep(until: .init(offset: .seconds(5))) }
        await clock.waitForSleepers()

        // When: cancellation and the deadline arrive together
        async let cancel: Void = sleepTask.cancel()
        async let advance: Void = clock.advance(by: .seconds(5))
        _ = await (cancel, advance)

        // Then: it finishes once, either way; a double resume traps the checked continuation
        let result = await sleepTask.result
        switch result {
        case .success:
            break
        case let .failure(error):
            #expect(error is CancellationError)
        }
    }

    @Test("Cancelling a registered wait for sleepers returns it without a sleeper")
    func cancelRegisteredWaitForSleepersReturns() async {
        let clock = TestClock()
        let waitTask = Task { await clock.waitForSleepers() }
        await waitForRegistration(on: clock)

        waitTask.cancel()

        await waitTask.value
    }

    @Test("A wait for sleepers started in an already-cancelled task returns without a sleeper")
    func cancelBeforeRegistrationWaitForSleepersReturns() async {
        let clock = TestClock()
        let waitTask = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            await clock.waitForSleepers()
        }

        await waitTask.value
    }

    @Test("Cancel racing a new sleeper resumes the wait exactly once", arguments: 0 ..< 200)
    func cancelRacingSleeperResumesWaitOnce(iteration _: Int) async {
        // Given: a registered wait for one sleeper
        let clock = TestClock()
        let waitTask = Task { await clock.waitForSleepers() }
        await waitForRegistration(on: clock)

        // When: cancellation and the satisfying sleep arrive together
        let sleepTask = Task { try await clock.sleep(until: .init(offset: .seconds(5))) }
        Task { waitTask.cancel() }

        // Then: it finishes once, either way, and later sleepers don't resume it again;
        // a double resume traps the checked continuation
        await waitTask.value
        let secondSleepTask = Task { try await clock.sleep(until: .init(offset: .seconds(5))) }
        await clock.waitForSleepers(2)
        sleepTask.cancel()
        secondSleepTask.cancel()
    }

    /// Suspends until `clock` holds a `waitForSleepers` waiter, so a test can cancel one known to be registered.
    private func waitForRegistration(on clock: TestClock) async {
        while clock.registrationWaiterCount == 0 {
            await Task.yield()
        }
    }
}
