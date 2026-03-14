import Foundation
import CoreLocation

/// Manages geofencing and location-based triggers
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {

    static let shared = LocationManager()

    private let manager = CLLocationManager()

    #if os(iOS)
    private var monitor: CLMonitor?
    private var monitorTask: Task<Void, any Error>?
    #endif

    var currentLocation: CLLocation?
    var isAuthorized = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // MARK: - Authorization

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    // MARK: - Geofencing (iOS only — Watch receives events via WatchConnectivity)

    #if os(iOS)
    func registerGeofence(for location: SavedLocation) {
        Task {
            if monitor == nil {
                monitor = await CLMonitor("pulseGeofences")
                startMonitoringEvents()
            }

            let center = CLLocationCoordinate2D(
                latitude: location.latitude,
                longitude: location.longitude
            )
            let condition = CLMonitor.CircularGeographicCondition(
                center: center,
                radius: location.radiusMeters
            )

            await monitor?.add(condition, identifier: location.id.uuidString)
        }
    }

    func removeGeofence(for locationId: UUID) {
        Task {
            await monitor?.remove(locationId.uuidString)
        }
    }

    func removeAllGeofences() {
        monitorTask?.cancel()
        monitorTask = nil
        monitor = nil
    }

    private func startMonitoringEvents() {
        guard let monitor else { return }

        monitorTask = Task {
            for try await event in await monitor.events {
                await handleMonitorEvent(event)
            }
        }
    }

    @MainActor
    private func handleMonitorEvent(_ event: CLMonitor.Event) {
        let isEntering: Bool
        switch event.state {
        case .satisfied:
            isEntering = true
        case .unsatisfied:
            isEntering = false
        default:
            return
        }

        let identifier = event.identifier

        if isEntering {
            NotificationCenter.default.post(
                name: .didEnterSavedRegion,
                object: nil,
                userInfo: ["regionId": identifier]
            )
        } else {
            NotificationCenter.default.post(
                name: .didExitSavedRegion,
                object: nil,
                userInfo: ["regionId": identifier]
            )
        }
    }
    #endif

    // MARK: - Save Current Location

    func saveCurrentAsLocation(name: String, type: String, radius: Double = 100) -> SavedLocation? {
        guard let location = currentLocation else { return nil }

        return SavedLocation(
            name: name,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            radiusMeters: radius,
            locationType: type
        )
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            isAuthorized = true
            manager.startUpdatingLocation()
        default:
            isAuthorized = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let didEnterSavedRegion = Notification.Name("pulse.didEnterSavedRegion")
    static let didExitSavedRegion = Notification.Name("pulse.didExitSavedRegion")
}
