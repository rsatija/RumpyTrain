import Foundation
import SwiftProtobuf

enum Direction {
    case uptown
    case downtown
    
    var description: String {
        switch self {
        case .uptown: return "uptown"
        case .downtown: return "downtown"
        }
    }
}

enum MTAFeed {
    case bdfm
    case ace
    case numbers   // 1,2,3,4,5,6,7,S
    case nqrw
    case jz
    case l
    case g
    
    var url: String {
        switch self {
        case .bdfm:
            return "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-bdfm"
        case .ace:
            return "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-ace"
        case .numbers:
            return "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs"
        case .nqrw:
            return "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-nqrw"
        case .jz:
            return "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-jz"
        case .l:
            return "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-l"
        case .g:
            return "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-g"
        }
    }
    
    var routes: Set<String> {
        switch self {
        case .bdfm:
            return ["B", "D", "F", "M"]
        case .ace:
            return ["A", "C", "E"]
        case .numbers:
            return ["1", "2", "3", "4", "5", "6", "6X", "7", "S"]
        case .nqrw:
            return ["N", "Q", "R", "W"]
        case .jz:
            return ["J", "Z"]
        case .l:
            return ["L"]
        case .g:
            return ["G"]
        }
    }
}

class GTFSRealtimeManager {
    private let feeds: [MTAFeed] = [.bdfm, .ace, .numbers, .nqrw, .jz, .l, .g]
    
    func fetchArrivalTimes(for stationId: String, direction: Direction) async throws -> [String: [(Date, String, Bool)]] {
        var allArrivalTimes: [String: [(Date, String, Bool)]] = [:]
        
        // Fetch from all feeds concurrently
        try await withThrowingTaskGroup(of: [String: [(Date, String, Bool)]].self) { group in
            for feed in feeds {
                group.addTask {
                    try await self.fetchArrivalTimesForFeed(feed, stationId: stationId, direction: direction)
                }
            }
            
            // Combine results from all feeds
            for try await feedTimes in group {
                for (route, times) in feedTimes {
                    if allArrivalTimes[route] == nil {
                        allArrivalTimes[route] = []
                    }
                    allArrivalTimes[route]?.append(contentsOf: times)
                }
            }
        }
        
        // Sort arrival times for each route
        for route in allArrivalTimes.keys {
            allArrivalTimes[route]?.sort { $0.0 < $1.0 }
        }
        
        return allArrivalTimes
    }
    
    private func fetchArrivalTimesForFeed(_ feed: MTAFeed, stationId: String, direction: Direction) async throws -> [String: [(Date, String, Bool)]] {
        do {
            guard let url = URL(string: feed.url) else {
                print("ERROR: Invalid URL for feed: \(feed)")
                throw URLError(.badURL)
            }
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("ERROR: Invalid response type for feed: \(feed)")
                throw URLError(.badServerResponse)
            }
            
            let feedMessage = try TransitRealtime_FeedMessage(serializedData: data)
            
            if feedMessage.entity.isEmpty {
                print("WARNING: Feed message contains no entities for feed: \(feed)")
                return [:]
            }
            
            var arrivalTimes: [String: [(Date, String, Bool)]] = [:]
            
            for entity in feedMessage.entity {
                if !entity.hasTripUpdate { continue }
                let tripUpdate = entity.tripUpdate
                
                for stopTimeUpdate in tripUpdate.stopTimeUpdate {
                    // Only strip N/S suffix if present
                    let stopIdBase = stopTimeUpdate.stopID.hasSuffix("N") || stopTimeUpdate.stopID.hasSuffix("S") 
                        ? String(stopTimeUpdate.stopID.prefix(stopTimeUpdate.stopID.count - 1))
                        : stopTimeUpdate.stopID
                    let stationIdBase = stationId.hasSuffix("N") || stationId.hasSuffix("S")
                        ? String(stationId.prefix(stationId.count - 1))
                        : stationId
                    
                    if stopIdBase == stationIdBase {
                        let routeId = tripUpdate.trip.routeID
                        
                        if feed.routes.contains(routeId) {
                            let stopDirection = stopTimeUpdate.stopID.hasSuffix("N") ? Direction.uptown : Direction.downtown
                            
                            // Filter by direction
                            if stopDirection != direction {
                                continue
                            }
                            
                            if arrivalTimes[routeId] == nil {
                                arrivalTimes[routeId] = []
                            }
                            
                            if stopTimeUpdate.arrival.hasTime {
                                let date = Date(timeIntervalSince1970: TimeInterval(stopTimeUpdate.arrival.time))
                                let direction = stopDirection.description
                                // Check if this is real-time data
                                let isRealTime = tripUpdate.trip.scheduleRelationship == .scheduled
                                // Only add future times
                                if date > Date() {
                                    arrivalTimes[routeId]?.append((date, direction, isRealTime))
                                }
                            }
                        }
                    }
                }
            }
            
            return arrivalTimes
        } catch {
            print("ERROR: Failed to fetch times for feed \(feed): \(error.localizedDescription)")
            throw error
        }
    }
    
    func formatArrivalTimes(_ times: [String: [(Date, String, Bool)]], stationName: String) -> String {
        var output = "\nNext arrivals for \(stationName):\n"
        
        // Sort routes alphabetically with numbers first
        let sortedRoutes = times.keys.sorted { route1, route2 in
            let isNum1 = Int(route1) != nil
            let isNum2 = Int(route2) != nil
            if isNum1 && !isNum2 { return true }
            if !isNum1 && isNum2 { return false }
            return route1 < route2
        }
        
        for routeId in sortedRoutes {
            guard let arrivals = times[routeId] else { continue }
            let nextTen = arrivals.prefix(10)
            let timeStrings = nextTen.map { arrival -> String in
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                let timeString = formatter.string(from: arrival.0)
                let minutes = Int(arrival.0.timeIntervalSince(Date()) / 60)
                let statusIndicator = arrival.2 ? "(real-time)" : "(scheduled)"
                return "\(timeString) (\(minutes) min) \(arrival.1) \(statusIndicator)"
            }
            output += "\(routeId) train: \(timeStrings.joined(separator: ", "))\n"
        }
        
        return output
    }
    
    // Keep the old method for backward compatibility
    func formatArrivalTimes(_ times: [String: [(Date, String, Bool)]]) -> String {
        return formatArrivalTimes(times, stationName: "nearest station")
    }
} 
