// LocationManager.swift
// Barbershop Booking App
// Singleton לניהול מיקום המשתמש

import Foundation
import CoreLocation

class LocationManager: NSObject, CLLocationManagerDelegate {

    static let shared = LocationManager()

    private let manager = CLLocationManager()
    private var completion: ((CLLocation?) -> Void)?

    /// המיקום האחרון שנשמר (אם כבר נשלף)
    private(set) var lastLocation: CLLocation?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // MARK: - Public

    /// מבקש מיקום חד-פעמי. קורא ל-completion על main thread.
    func requestLocation(completion: @escaping (CLLocation?) -> Void) {
        if let cached = lastLocation {
            completion(cached)
            return
        }
        self.completion = completion
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            completion(nil)
        }
    }

    /// מחשב מרחק בק"מ בין שני זוגות קו רוחב/אורך
    static func distanceKm(from userLocation: CLLocation,
                           toLat lat: Double, lon: Double) -> Double {
        let target = CLLocation(latitude: lat, longitude: lon)
        return userLocation.distance(from: target) / 1000.0
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        lastLocation = loc
        DispatchQueue.main.async { [weak self] in
            self?.completion?(loc)
            self?.completion = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 Location error: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in
            self?.completion?(nil)
            self?.completion = nil
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if completion != nil { manager.requestLocation() }
        case .denied, .restricted:
            DispatchQueue.main.async { [weak self] in
                self?.completion?(nil)
                self?.completion = nil
            }
        default: break
        }
    }
}
