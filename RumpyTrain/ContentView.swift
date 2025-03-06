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
    var arrivalTimes: [String: [(Date, String)]]? // Add arrival times storage
    
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
    private let gtfsRealtimeManager = GTFSRealtimeManager()
    
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
                return nil
            }
            
            // Only include parent stations (location_type == 1)
            if components[4] == "1" {
                let stationId = components[0]
                let stationRoutes = (stopToRoutes[stationId] ?? [])
                    .compactMap { routes[$0] }
                    .sorted { $0.name < $1.name }
                
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
    
    func updateDistances(from location: CLLocation, direction: Direction = .all) {
        stations = stations.map { station in
            var updatedStation = station
            let stationLocation = CLLocation(latitude: station.latitude, longitude: station.longitude)
            updatedStation.distance = location.distance(from: stationLocation)
            return updatedStation
        }.sorted { ($0.distance ?? Double.infinity) < ($1.distance ?? Double.infinity) }
        
        // Fetch real-time arrival times for the 6 nearest stations
        Task {
            var updatedStations = stations
            for (index, station) in stations.prefix(6).enumerated() {
                do {
                    let arrivalTimes = try await gtfsRealtimeManager.fetchArrivalTimes(for: station.id, direction: direction)
                    // Update the station with arrival times
                    DispatchQueue.main.async {
                        updatedStations[index].arrivalTimes = arrivalTimes
                        self.stations = updatedStations
                    }
                } catch {
                    print("DEBUG: Failed to fetch arrival times for \(station.name): \(error)")
                }
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
            coordinates.append(contentsOf: parent.stations.prefix(6).map { $0.coordinate })
            
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
        let annotations = stations.prefix(6).map { station -> StationAnnotation in
            StationAnnotation(station: station)
        }
        mapView.addAnnotations(annotations)
        
        // Set the region to show all annotations and user location
        if let location = location {
            var coordinates: [CLLocationCoordinate2D] = [location.coordinate]
            coordinates.append(contentsOf: stations.prefix(6).map { $0.coordinate })
            
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

struct StationCard: View {
    let station: Station
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    func minutesUntil(_ date: Date) -> Int {
        return Int(date.timeIntervalSince(Date()) / 60)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(station.name)
                .font(.headline)
                .fontWeight(.bold)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.bottom, 4)
            
            // Arrival times
            if let arrivalTimes = station.arrivalTimes {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(arrivalTimes.keys).sorted(), id: \.self) { routeId in
                        if let times = arrivalTimes[routeId], !times.isEmpty {
                            let displayTimes = Array(times.prefix(3))
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(routeId)
                                        .font(.system(size: 14, weight: .bold))
                                        .frame(width: 24, height: 24)
                                        .background(station.routes.first(where: { $0.id == routeId })?.color ?? .gray)
                                        .foregroundColor(.white)
                                        .clipShape(Circle())
                                    
                                    if !displayTimes.isEmpty {
                                        Text(displayTimes[0].1)  // Show direction
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                HStack(spacing: 6) {
                                    ForEach(Array(displayTimes.enumerated()), id: \.offset) { _, arrival in
                                        Text("\(minutesUntil(arrival.0))m")
                                            .font(.system(size: 13))
                                            .foregroundColor(.primary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(6)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            } else {
                Text("Loading arrivals...")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1, x: 0, y: 1)
    }
}

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var subwayStationsManager = SubwayStationsManager()
    @State private var mapViewCoordinator: MapView.Coordinator?
    @State private var selectedDirection: Direction = .uptown
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Title
                Text("RumpyTrain")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                
                ZStack {
                    MapView(location: locationManager.location, 
                           stations: subwayStationsManager.stations,
                           coordinator: $mapViewCoordinator)
                        .frame(height: UIScreen.main.bounds.height / 4)
                    
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
                .padding(.bottom, 8)
                
                // Direction Toggle
                Picker("Direction", selection: $selectedDirection) {
                    Text("All").tag(Direction.all)
                    Text("Uptown").tag(Direction.uptown)
                    Text("Downtown").tag(Direction.downtown)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if let location = locationManager.location {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 16) {
                            ForEach(subwayStationsManager.stations.prefix(6)) { station in
                                StationCard(station: station)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                } else {
                    Spacer()
                    Text("Loading location...")
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                subwayStationsManager.loadStations()
                locationManager.requestLocation()
            }
            .onChange(of: locationManager.location) { newLocation in
                if let location = newLocation {
                    subwayStationsManager.updateDistances(from: location, direction: selectedDirection)
                }
            }
            .onChange(of: selectedDirection) { _ in
                // Refresh arrival times when direction changes
                if let location = locationManager.location {
                    subwayStationsManager.updateDistances(from: location, direction: selectedDirection)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
