import Foundation
import SwiftProtobuf

class GTFSRealtimeManager {
    private let feedURL = "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-bdfm"
    
    func fetchArrivalTimes(for stationId: String) async throws -> [String: [(Date, String)]] {
        do {
            guard let url = URL(string: feedURL) else {
                print("ERROR: Invalid URL")
                throw URLError(.badURL)
            }
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("ERROR: Invalid response type")
                throw URLError(.badServerResponse)
            }
            
            let feedMessage = try TransitRealtime_FeedMessage(serializedData: data)
            
            if feedMessage.entity.isEmpty {
                print("WARNING: Feed message contains no entities")
                return [:]
            }
            
            var arrivalTimes: [String: [(Date, String)]] = [:]
            
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
                        
                        if ["B", "D", "F", "M"].contains(routeId) {
                            if arrivalTimes[routeId] == nil {
                                arrivalTimes[routeId] = []
                            }
                            
                            if stopTimeUpdate.arrival.hasTime {
                                let date = Date(timeIntervalSince1970: TimeInterval(stopTimeUpdate.arrival.time))
                                let direction = stopTimeUpdate.stopID.hasSuffix("N") ? "uptown" : "downtown"
                                // Only add future times
                                if date > Date() {
                                    arrivalTimes[routeId]?.append((date, direction))
                                }
                            }
                        }
                    }
                }
            }
            
            // Sort arrival times for each route
            for routeId in arrivalTimes.keys {
                arrivalTimes[routeId]?.sort { $0.0 < $1.0 }
            }
            
            return arrivalTimes
        } catch {
            print("ERROR: An error occurred: \(error)")
            print("ERROR: Error description: \(error.localizedDescription)")
            throw error
        }
    }
    
    func formatArrivalTimes(_ times: [String: [(Date, String)]]) -> String {
        var output = "\nNext arrivals for nearest station:\n"
        
        for (routeId, arrivals) in times {
            let nextTen = arrivals.prefix(10)
            let timeStrings = nextTen.map { arrival -> String in
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                let timeString = formatter.string(from: arrival.0)
                let minutes = Int(arrival.0.timeIntervalSince(Date()) / 60)
                return "\(timeString) (\(minutes) min) \(arrival.1)"
            }
            output += "\(routeId) train: \(timeStrings.joined(separator: ", "))\n"
        }
        
        return output
    }
} 
