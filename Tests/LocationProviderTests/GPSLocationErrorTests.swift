@testable import LocationProvider
import Testing

struct GPSLocationErrorTests {
    @Test(
        "Each error names what the user can do about it",
        arguments: [
            (GPSLocationError.notFound, GPSLocationError.Recovery.retry),
            (.locationUnavailable, .retry),
            (.authorizationDenied, .openSettings),
            (.insufficientlyInUse, .openSettings),
            (.preciseLocationRequired, .openSettings),
            (.authorizationRestricted, .none),
            (.serviceSessionRequired, .none),
        ])
    func recovery(error: GPSLocationError, expectedRecovery: GPSLocationError.Recovery) {
        #expect(error.recovery == expectedRecovery)
    }
}
