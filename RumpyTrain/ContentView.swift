//
//  ContentView.swift
//  RumpyTrain
//
//  Created by Rahul Satija on 3/5/25.
//

import SwiftUI
import CoreLocation
import MapKit

struct Route: Identifiable {
    let id: String
    let name: String
    let color: Color
    
    init(id: String, name: String, color: String) {
        self.id = id
        self.name = name
        // Convert hex color to SwiftUI Color
        let hex = color.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        self.color = Color(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}

struct Station: Identifiable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    var distance: Double?
    var routes: [Route]
    
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
    private var routes: [String: Route] = [:]
    private var stopToRoutes: [String: Set<String>] = [:] // stopId -> routeIds
    
    private func loadRoutes() {
        guard let path = Bundle.main.path(forResource: "routes", ofType: "txt"),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            print("DEBUG: Failed to load routes.txt")
            return
        }
        
        let lines = content.components(separatedBy: .newlines)
        print("DEBUG: Found \(lines.count) lines in routes.txt")
        
        for line in lines.dropFirst() {
            let components = line.components(separatedBy: ",")
            guard components.count >= 4 else { 
                print("DEBUG: Invalid route line: \(line)")
                continue 
            }
            let routeId = components[1].trimmingCharacters(in: .whitespaces) // route_id is in column 1
            let routeName = components[2].trimmingCharacters(in: .whitespaces) // route_short_name is in column 2
            let routeColor = components[7].trimmingCharacters(in: .whitespaces) // route_color is in column 7
            routes[routeId] = Route(id: routeId, name: routeName, color: routeColor)
        }
        print("DEBUG: Loaded \(routes.count) routes")
        routes.forEach { routeId, route in
            print("DEBUG: Route: \(routeId) -> \(route.name)")
        }
    }
    
    private func loadTrips() -> [String: String] {
        guard let path = Bundle.main.path(forResource: "trips", ofType: "txt"),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            print("DEBUG: Failed to load trips.txt")
            return [:]
        }
        
        var tripRoutes: [String: String] = [:]
        let lines = content.components(separatedBy: .newlines)
        print("DEBUG: Found \(lines.count) lines in trips.txt")
        
        for line in lines.dropFirst() {
            let components = line.components(separatedBy: ",")
            guard components.count >= 2 else {
                print("DEBUG: Invalid trip line: \(line)")
                continue
            }
            let routeId = components[0].trimmingCharacters(in: .whitespaces) // route_id is in column 0
            let tripId = components[1].trimmingCharacters(in: .whitespaces) // trip_id is in column 1
            tripRoutes[tripId] = routeId
        }
        print("DEBUG: Loaded \(tripRoutes.count) trip-route mappings")
        return tripRoutes
    }
    
    private func loadStopTimes(tripRoutes: [String: String]) {
        guard let path = Bundle.main.path(forResource: "stop_times", ofType: "txt"),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            print("DEBUG: Failed to load stop_times.txt")
            return
        }
        
        let lines = content.components(separatedBy: .newlines)
        print("DEBUG: Found \(lines.count) lines in stop_times.txt")
        
        for line in lines.dropFirst() {
            let components = line.components(separatedBy: ",")
            guard components.count >= 3 else {
                print("DEBUG: Invalid stop_time line: \(line)")
                continue
            }
            let tripId = components[0].trimmingCharacters(in: .whitespaces)
            let stopId = components[1].trimmingCharacters(in: .whitespaces)
            
            // Remove the direction suffix (S, N) from the stop ID
            let baseStopId = String(stopId.dropLast())
            
            if let routeId = tripRoutes[tripId] {
                if stopToRoutes[baseStopId] == nil {
                    stopToRoutes[baseStopId] = []
                }
                stopToRoutes[baseStopId]?.insert(routeId)
            }
        }
        print("DEBUG: Created \(stopToRoutes.count) stop-route mappings")
        // Debug print first few stop-route mappings
        for (stopId, routeIds) in stopToRoutes.prefix(5) {
            print("DEBUG: Stop \(stopId) has routes: \(routeIds.joined(separator: ", "))")
        }
    }
    
    func loadStations() {
        print("\nDEBUG: Starting station loading process")
        
        // Load routes first
        loadRoutes()
        
        // Load trips and create trip -> route mapping
        let tripRoutes = loadTrips()
        
        // Load stop times and create stop -> routes mapping
        loadStopTimes(tripRoutes: tripRoutes)
        
        // Load stations
        guard let path = Bundle.main.path(forResource: "stops", ofType: "txt"),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            print("DEBUG: Failed to load stops.txt")
            return
        }
        
        let lines = content.components(separatedBy: .newlines)
        print("DEBUG: Found \(lines.count) lines in stops.txt")
        
        stations = lines.dropFirst().compactMap { line -> Station? in
            let components = line.components(separatedBy: ",")
            guard components.count >= 4,
                  let lat = Double(components[2]),
                  let lon = Double(components[3]) else {
                print("DEBUG: Invalid station line: \(line)")
                return nil
            }
            
            // Only include parent stations (location_type == 1)
            if components[4] == "1" {
                let stationId = components[0]
                let stationRoutes = (stopToRoutes[stationId] ?? [])
                    .compactMap { routes[$0] }
                    .sorted { $0.name < $1.name }
                
                print("DEBUG: Station \(components[1]) (ID: \(stationId)) has \(stationRoutes.count) routes")
                stationRoutes.forEach { route in
                    print("DEBUG: - Route: \(route.name)")
                }
                
                return Station(
                    id: stationId,
                    name: components[1],
                    latitude: lat,
                    longitude: lon,
                    distance: nil,
                    routes: stationRoutes
                )
            }
            return nil
        }
        
        print("DEBUG: Loaded \(stations.count) stations")
    }
    
    func updateDistances(from location: CLLocation) {
        stations = stations.map { station in
            var updatedStation = station
            let stationLocation = CLLocation(latitude: station.latitude, longitude: station.longitude)
            updatedStation.distance = location.distance(from: stationLocation)
            return updatedStation
        }.sorted { ($0.distance ?? Double.infinity) < ($1.distance ?? Double.infinity) }
        
        print("\nDEBUG: Updated distances, first 5 stations:")
        stations.prefix(5).forEach { station in
            print("DEBUG: \(station.name) - \(station.routes.count) routes")
            station.routes.forEach { route in
                print("DEBUG: - \(route.name)")
            }
        }
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
                            VStack(alignment: .leading, spacing: 4) {
                                Text(station.name)
                                    .font(.headline)
                                if let distance = station.distance {
                                    Text(String(format: "%.1f meters away", distance))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                HStack(spacing: 4) {
                                    ForEach(station.routes) { route in
                                        Text(route.name)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(route.color)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.vertical, 4)
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
