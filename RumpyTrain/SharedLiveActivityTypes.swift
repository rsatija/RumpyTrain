import Foundation
import ActivityKit

public struct RumpyTrainWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        public var nextArrivalTime: Date
        public var routeId: String
        public var direction: String
        public var stationName: String
        
        public init(nextArrivalTime: Date, routeId: String, direction: String, stationName: String) {
            self.nextArrivalTime = nextArrivalTime
            self.routeId = routeId
            self.direction = direction
            self.stationName = stationName
        }
    }

    // Fixed non-changing properties about your activity go here!
    public var stationName: String
    public var routeId: String
    
    public init(stationName: String, routeId: String) {
        self.stationName = stationName
        self.routeId = routeId
    }
} 