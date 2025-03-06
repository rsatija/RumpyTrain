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
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
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

struct MapView: UIViewRepresentable {
    let location: CLLocation?
    let stations: [Station]
    @Binding var coordinator: Coordinator?
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        var mapView: MKMapView?
        
        init(_ parent: MapView) {
            self.parent = parent
            super.init()
        }
        
        func updateParent(_ newParent: MapView) {
            self.parent = newParent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !annotation.isKind(of: MKUserLocation.self) else { return nil }
            
            let identifier = "Station"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                view?.annotation = annotation
            }
            
            // Configure the marker view
            if let markerView = view as? MKMarkerAnnotationView {
                markerView.displayPriority = .required
                markerView.clusteringIdentifier = nil
                markerView.canShowCallout = true
                markerView.markerTintColor = .red
                markerView.collisionMode = .circle
            }
            
            return view
        }
        
        func resetZoom() {
            guard let mapView = mapView,
                  let location = parent.location else { return }
            
            // Create a list of coordinates including user location and all stations
            var coordinates: [CLLocationCoordinate2D] = [location.coordinate]
            coordinates.append(contentsOf: parent.stations.prefix(5).map { $0.coordinate })
            
            // Create a map rect that includes all coordinates
            let mapRect = coordinates.reduce(MKMapRect.null) { rect, coordinate in
                let point = MKMapPoint(coordinate)
                let pointRect = MKMapRect(x: point.x, y: point.y, width: 0, height: 0)
                return rect.isNull ? pointRect : rect.union(pointRect)
            }
            
            // Expand the rect slightly to ensure all points are visible
            let expandedRect = mapRect.insetBy(dx: -mapRect.size.width * 0.1, dy: -mapRect.size.height * 0.1)
            
            // Add some padding around the region
            let padding = UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50)
            mapView.setVisibleMapRect(expandedRect, edgePadding: padding, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(self)
        DispatchQueue.main.async {
            self.coordinator = coordinator
        }
        return coordinator
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        context.coordinator.mapView = mapView
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update coordinator's parent reference
        context.coordinator.updateParent(self)
        
        // Remove existing annotations
        mapView.removeAnnotations(mapView.annotations)
        
        // Add station annotations
        let annotations = stations.prefix(5).map { station -> StationAnnotation in
            StationAnnotation(station: station)
        }
        mapView.addAnnotations(annotations)
        
        // Set the region to show all annotations and user location
        if let location = location {
            var coordinates: [CLLocationCoordinate2D] = [location.coordinate]
            coordinates.append(contentsOf: stations.prefix(5).map { $0.coordinate })
            
            let mapRect = coordinates.reduce(MKMapRect.null) { rect, coordinate in
                let point = MKMapPoint(coordinate)
                let pointRect = MKMapRect(x: point.x, y: point.y, width: 0, height: 0)
                return rect.isNull ? pointRect : rect.union(pointRect)
            }
            
            // Expand the rect slightly to ensure all points are visible
            let expandedRect = mapRect.insetBy(dx: -mapRect.size.width * 0.1, dy: -mapRect.size.height * 0.1)
            
            let padding = UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50)
            mapView.setVisibleMapRect(expandedRect, edgePadding: padding, animated: true)
        }
    }
}

class StationAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let station: Station
    
    init(station: Station) {
        self.coordinate = station.coordinate
        self.title = station.name
        if let distance = station.distance {
            self.subtitle = String(format: "%.1f meters away", distance)
        } else {
            self.subtitle = nil
        }
        self.station = station
        super.init()
    }
}

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var subwayStationsManager = SubwayStationsManager()
    @State private var mapViewCoordinator: MapView.Coordinator?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ZStack {
                    MapView(location: locationManager.location, 
                           stations: subwayStationsManager.stations,
                           coordinator: $mapViewCoordinator)
                        .frame(height: UIScreen.main.bounds.height / 3)
                    
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                mapViewCoordinator?.resetZoom()
                            }) {
                                Image(systemName: "scope")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.blue)
                                    .padding(12)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            }
                            .padding(.trailing, 16)
                            .padding(.top, 16)
                        }
                        Spacer()
                    }
                }
                
                if let location = locationManager.location {
                    List {
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
                    }
                } else {
                    Spacer()
                    Text("Loading location...")
                    Spacer()
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
