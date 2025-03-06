//
//  ContentView.swift
//  RumpyTrain
//
//  Created by Rahul Satija on 3/5/25.
//

import SwiftUI
import CoreLocation
import MapKit

struct Station: Identifiable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    var distance: Double?
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() {
        locationManager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}

class SubwayStationsManager: ObservableObject {
    @Published var stations: [Station] = []
    
    func loadStations() {
        guard let path = Bundle.main.path(forResource: "stops", ofType: "txt"),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            print("Error loading stops.txt")
            return
        }
        
        let lines = content.components(separatedBy: .newlines)
        let headers = lines[0].components(separatedBy: ",")
        
        stations = lines.dropFirst().compactMap { line -> Station? in
            let components = line.components(separatedBy: ",")
            guard components.count >= 4,
                  let lat = Double(components[2]),
                  let lon = Double(components[3]) else {
                return nil
            }
            
            // Only include parent stations (location_type == 1)
            if components[4] == "1" {
                return Station(
                    id: components[0],
                    name: components[1],
                    latitude: lat,
                    longitude: lon
                )
            }
            return nil
        }
    }
    
    func updateDistances(from location: CLLocation) {
        stations = stations.map { station in
            var updatedStation = station
            let stationLocation = CLLocation(latitude: station.latitude, longitude: station.longitude)
            updatedStation.distance = location.distance(from: stationLocation)
            return updatedStation
        }.sorted { ($0.distance ?? Double.infinity) < ($1.distance ?? Double.infinity) }
    }
}

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var subwayStationsManager = SubwayStationsManager()
    
    var body: some View {
        NavigationView {
            List {
                if let location = locationManager.location {
                    ForEach(subwayStationsManager.stations.prefix(5)) { station in
                        VStack(alignment: .leading) {
                            Text(station.name)
                                .font(.headline)
                            if let distance = station.distance {
                                Text(String(format: "%.1f meters away", distance))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } else {
                    Text("Loading location...")
                }
            }
            .navigationTitle("Nearest Subway Stations")
            .onAppear {
                subwayStationsManager.loadStations()
                locationManager.requestLocation()
            }
            .onChange(of: locationManager.location) { newLocation in
                if let location = newLocation {
                    subwayStationsManager.updateDistances(from: location)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
