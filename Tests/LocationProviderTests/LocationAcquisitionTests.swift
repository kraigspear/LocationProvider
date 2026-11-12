import CoreLocation
@testable import LocationProvider
import Testing

private typealias Instant = TestClock.Instant
private typealias Acquisition = LocationAcquisition<Instant>

/// Seconds after the acquisition starts.
private func at(_ seconds: Int) -> Instant {
    Instant(offset: .seconds(seconds))
}

private func makeAcquisition(
    timeout: Duration = .seconds(10),
    gracePeriod: Duration = .seconds(5),
    accuracyRequirement: LocationProvider.AccuracyRequirement = .any) -> Acquisition
{
    Acquisition(
        start: at(0),
        configuration: .init(locationAcquisitionTimeout: timeout, locationUnavailableGracePeriod: gracePeriod),
        accuracyRequirement: accuracyRequirement)
}

struct LocationAcquisitionTests {
    private let location = CLLocation(latitude: 1, longitude: 1)

    @Test("A location succeeds")
    func locationSucceeds() {
        var acquisition = makeAcquisition()

        #expect(acquisition.receive(MockLocationUpdate(location: location), at: at(0)) == .succeed(location))
    }

    @Test("An update with no location and no error continues")
    func neutralUpdateContinues() {
        var acquisition = makeAcquisition()

        #expect(acquisition.receive(MockLocationUpdate(), at: at(0)) == .continue)
    }

    @Test(
        "Permission errors fail at once",
        arguments: [
            (MockLocationUpdate.denied(), GPSLocationError.authorizationDenied),
            (MockLocationUpdate(authorizationDeniedGlobally: true, locationUnavailable: true), .authorizationDenied),
            (MockLocationUpdate.restricted(), .authorizationRestricted),
            (MockLocationUpdate.insufficientlyInUse(), .insufficientlyInUse),
            (MockLocationUpdate.serviceSessionRequired(), .serviceSessionRequired),
        ])
    func permissionErrorsFail(update: MockLocationUpdate, expectedError: GPSLocationError) {
        var acquisition = makeAcquisition()

        #expect(acquisition.receive(update, at: at(0)) == .fail(expectedError))
    }

    @Test("Timing out with no transient error fails with notFound")
    func timeoutWithoutTransientErrorIsNotFound() {
        let acquisition = makeAcquisition(timeout: .seconds(10))

        #expect(acquisition.deadline == at(10))
        #expect(acquisition.deadlineReached(at: at(10)) == .fail(.notFound))
    }

    @Test("Reaching an earlier deadline after the window moved continues")
    func deadlineBeforeCurrentDeadlineContinues() {
        var acquisition = makeAcquisition(timeout: .seconds(10))
        _ = acquisition.receive(MockLocationUpdate.requestInProgress(), at: at(8))

        #expect(acquisition.deadlineReached(at: at(10)) == .continue)
    }

    @Test("The stream ending fails with the last transient error")
    func streamEndedUsesLastTransientError() {
        var acquisition = makeAcquisition()
        _ = acquisition.receive(MockLocationUpdate.locationNotAvailable(), at: at(0))

        #expect(acquisition.streamEnded() == .fail(.locationUnavailable))
    }

    @Test("The stream ending with no transient error fails with notFound")
    func streamEndedWithoutTransientErrorIsNotFound() {
        #expect(makeAcquisition().streamEnded() == .fail(.notFound))
    }

    struct PermissionPrompt {
        private let location = CLLocation(latitude: 1, longitude: 1)

        @Test("A permission prompt restarts the acquisition window")
        func promptRestartsWindow() {
            var acquisition = makeAcquisition(timeout: .seconds(10))

            #expect(acquisition.receive(MockLocationUpdate.requestInProgress(), at: at(8)) == .continue)
            #expect(acquisition.deadline == at(18))
        }

        @Test("A permission prompt wins over the unavailable flag it arrives with")
        func promptWinsOverUnavailable() {
            // Given: requestInProgress() also sets locationUnavailable, with no grace period at all
            var acquisition = makeAcquisition(gracePeriod: .zero)
            _ = acquisition.receive(MockLocationUpdate.locationNotAvailable(), at: at(0))

            // Then: the prompt continues instead of ending the grace period
            #expect(acquisition.receive(MockLocationUpdate.requestInProgress(), at: at(1)) == .continue)
        }

        @Test("A permission prompt clears the last transient error, which predates it")
        func promptClearsTransientError() {
            var acquisition = makeAcquisition(timeout: .seconds(10))
            _ = acquisition.receive(MockLocationUpdate.locationNotAvailable(), at: at(0))
            _ = acquisition.receive(MockLocationUpdate.requestInProgress(), at: at(2))

            #expect(acquisition.deadlineReached(at: at(12)) == .fail(.notFound))
        }

        @Test("A permission prompt restarts the grace period")
        func promptRestartsGracePeriod() {
            // Given: unavailable at 0s and 6s with a prompt between them, in a 5s grace period
            var acquisition = makeAcquisition(timeout: .seconds(60))
            _ = acquisition.receive(MockLocationUpdate.locationNotAvailable(), at: at(0))
            _ = acquisition.receive(MockLocationUpdate.requestInProgress(), at: at(3))

            // Then: 6s is a new grace period, not 6s into the old one
            #expect(acquisition.receive(MockLocationUpdate.locationNotAvailable(), at: at(6)) == .continue)
        }

        @Test("A location after a permission prompt succeeds")
        func locationAfterPromptSucceeds() {
            var acquisition = makeAcquisition()
            _ = acquisition.receive(MockLocationUpdate.requestInProgress(), at: at(0))

            #expect(acquisition.receive(MockLocationUpdate(location: location), at: at(1)) == .succeed(location))
        }
    }

    struct Accuracy {
        private let location = CLLocation(latitude: 1, longitude: 1)

        @Test("Reduced accuracy succeeds when any accuracy is accepted")
        func reducedAccuracyAccepted() {
            var acquisition = makeAcquisition(accuracyRequirement: .any)
            let update = MockLocationUpdate(location: location, accuracyLimited: true)

            #expect(acquisition.receive(update, at: at(0)) == .succeed(location))
        }

        @Test("Reduced accuracy continues when precise is required")
        func reducedAccuracyRejected() {
            var acquisition = makeAcquisition(accuracyRequirement: .precise)
            let update = MockLocationUpdate(location: location, accuracyLimited: true)

            #expect(acquisition.receive(update, at: at(0)) == .continue)
        }

        @Test("Timing out after reduced-accuracy fixes fails with preciseLocationRequired")
        func rejectedReducedAccuracyIsTimeoutError() {
            var acquisition = makeAcquisition(timeout: .seconds(10), accuracyRequirement: .precise)
            _ = acquisition.receive(MockLocationUpdate(location: location, accuracyLimited: true), at: at(0))

            #expect(acquisition.deadlineReached(at: at(10)) == .fail(.preciseLocationRequired))
            #expect(acquisition.streamEnded() == .fail(.preciseLocationRequired))
        }

        @Test("A precise location succeeds when precise is required")
        func preciseLocationAccepted() {
            var acquisition = makeAcquisition(accuracyRequirement: .precise)

            #expect(acquisition.receive(MockLocationUpdate(location: location), at: at(0)) == .succeed(location))
        }
    }

    struct GracePeriod {
        private let location = CLLocation(latitude: 1, longitude: 1)

        @Test("Location unavailable within the grace period continues, then a location succeeds")
        func unavailableWithinGracePeriodRecovers() {
            var acquisition = makeAcquisition(gracePeriod: .seconds(5))

            #expect(acquisition.receive(MockLocationUpdate.locationNotAvailable(), at: at(0)) == .continue)
            #expect(acquisition.receive(MockLocationUpdate.locationNotAvailable(), at: at(4)) == .continue)
            #expect(acquisition.receive(MockLocationUpdate(location: location), at: at(4)) == .succeed(location))
        }

        @Test("Location unavailable for the whole grace period fails with locationUnavailable")
        func unavailableForGracePeriodFails() {
            var acquisition = makeAcquisition(gracePeriod: .seconds(5))
            _ = acquisition.receive(MockLocationUpdate.locationNotAvailable(), at: at(0))

            #expect(acquisition
                .receive(MockLocationUpdate.locationNotAvailable(), at: at(5)) == .fail(.locationUnavailable))
        }

        @Test("An update without the unavailable flag restarts the grace period")
        func neutralUpdateRestartsGracePeriod() {
            // Given: unavailable at 0s and 8s, with a neutral update between them, in a 5s grace period
            var acquisition = makeAcquisition(timeout: .seconds(60), gracePeriod: .seconds(5))
            _ = acquisition.receive(MockLocationUpdate.locationNotAvailable(), at: at(0))
            _ = acquisition.receive(MockLocationUpdate(), at: at(4))

            // Then: 8s starts a new grace period instead of measuring 8s
            #expect(acquisition.receive(MockLocationUpdate.locationNotAvailable(), at: at(8)) == .continue)
        }

        @Test("An update without the unavailable flag keeps the last transient error")
        func neutralUpdateKeepsTransientError() {
            var acquisition = makeAcquisition(timeout: .seconds(10))
            _ = acquisition.receive(MockLocationUpdate.locationNotAvailable(), at: at(0))
            _ = acquisition.receive(MockLocationUpdate(), at: at(1))

            #expect(acquisition.deadlineReached(at: at(10)) == .fail(.locationUnavailable))
        }

        @Test("Timing out inside the grace period fails with locationUnavailable")
        func timeoutDuringGracePeriodIsLocationUnavailable() {
            var acquisition = makeAcquisition(timeout: .milliseconds(200), gracePeriod: .seconds(5))
            _ = acquisition.receive(MockLocationUpdate.locationNotAvailable(), at: at(0))

            #expect(acquisition.deadlineReached(at: Instant(offset: .milliseconds(200))) == .fail(.locationUnavailable))
        }
    }

    struct StreamFailure {
        @Test(
            "A stream error maps to its location error",
            arguments: [
                (CLError(.denied) as any Error, GPSLocationError.authorizationDenied),
                (CLError(.promptDeclined), .preciseLocationRequired),
                (CLError(.locationUnknown), .locationUnavailable),
                (CLError(.network), .locationUnavailable),
                (CLError(.deferredAccuracyTooLow), .locationUnavailable),
                (CLError(.deferredDistanceFiltered), .locationUnavailable),
                (CLError(.deferredCanceled), .locationUnavailable),
                (CLError(.deferredFailed), .locationUnavailable),
                (CLError(.headingFailure), .locationUnavailable),
                (GPSLocationError.serviceSessionRequired, .serviceSessionRequired),
            ])
        func streamErrorMaps(error: any Error, expectedError: GPSLocationError) {
            #expect(makeAcquisition().streamFailed(error) == .fail(expectedError))
        }

        @Test(
            "A stream error with no mapping and no transient error fails with notFound",
            arguments: [
                CancellationError() as any Error,
                CLError(.rangingUnavailable),
                URLError(.timedOut),
            ])
        func unmappedStreamErrorIsNotFound(error: any Error) {
            #expect(makeAcquisition().streamFailed(error) == .fail(.notFound))
        }

        @Test("A stream error with no mapping fails with the last transient error")
        func unmappedStreamErrorUsesTransientError() {
            var acquisition = makeAcquisition(accuracyRequirement: .precise)
            let update = MockLocationUpdate(location: CLLocation(latitude: 1, longitude: 1), accuracyLimited: true)
            _ = acquisition.receive(update, at: at(0))

            #expect(acquisition.streamFailed(CancellationError()) == .fail(.preciseLocationRequired))
        }

        @Test("A thrown locationUnknown fails at once, because the stream that threw it has ended")
        func thrownLocationUnknownSkipsGracePeriod() {
            var acquisition = makeAcquisition(gracePeriod: .seconds(5))
            _ = acquisition.receive(MockLocationUpdate.locationNotAvailable(), at: at(0))

            #expect(acquisition.streamFailed(CLError(.locationUnknown)) == .fail(.locationUnavailable))
        }
    }
}
