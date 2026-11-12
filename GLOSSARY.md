# LocationProvider

Turns the device's stream of location updates into one named location, or one error the user can act on.

## Language

**Location acquisition**:
One request for the device's location, from the first update until it yields a location or an error.
_Avoid_: Location request, fetch

**Acquisition window**:
The span a location acquisition may run before it times out. A permission prompt opens a new one.
_Avoid_: Timeout window, timer

**Grace period**:
How long updates may keep reporting the location as unavailable before the acquisition fails.
_Avoid_: Retry window, unavailable timeout

**Transient error**:
An error that may resolve without user action, such as no GPS signal.
_Avoid_: Soft error, recoverable error

**Permission prompt**:
The system asking the user for location access while an acquisition is underway.
_Avoid_: Authorization request
