import Foundation
import CoreLocation
import SwiftData

/// Manages geofencing and location-based triggers
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    
    static let shared = LocationManager()
    
    private let manager = CLLocationManager()
    
    var currentLocation: CLLocation?
    var isAuthorized = false
    var currentRegionEvent: RegionEvent?
    
    struct RegionEvent {
        let locationName: String
        let locationType: String
        let isEntering: Bool
        let timestamp: Date
    }
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = true
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        manager.requestAlwaysAuthorization()
    }
    
    // MARK: - Geofencing
    
    func registerGeofence(for location: SavedLocation) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
            radius: min(location.radiusMeters, manager.maximumRegionMonitoringDistance),
            identifier: location.id.uuidString
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        manager.startMonitoring(for: region)
    }
    
    func removeGeofence(for locationId: UUID) {
        for region in manager.monitoredRegions {
            if region.identifier == locationId.uuidString {
                manager.stopMonitoring(for: region)
            }
        }
    }
    
    func removeAllGeofences() {
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
    }
    
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
        case .authorizedAlways:
            isAuthorized = true
            manager.startUpdatingLocation()
        case .authorizedWhenInUse:
            isAuthorized = true
            manager.startUpdatingLocation()
        default:
            isAuthorized = false
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        handleRegionEvent(region: region, isEntering: true)
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        handleRegionEvent(region: region, isEntering: false)
    }
    
    private func handleRegionEvent(region: CLRegion, isEntering: Bool) {
        // This will be connected to notification/workout triggers
        currentRegionEvent = RegionEvent(
            locationName: region.identifier, // Will be resolved to actual name
            locationType: "unknown",
            isEntering: isEntering,
            timestamp: .now
        )
        
        if isEntering {
            NotificationCenter.default.post(
                name: .didEnterSavedRegion,
                object: nil,
                userInfo: ["regionId": region.identifier]
            )
        } else {
            NotificationCenter.default.post(
                name: .didExitSavedRegion,
                object: nil,
                userInfo: ["regionId": region.identifier]
            )
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let didEnterSavedRegion = Notification.Name("pulse.didEnterSavedRegion")
    static let didExitSavedRegion = Notification.Name("pulse.didExitSavedRegion")
}
