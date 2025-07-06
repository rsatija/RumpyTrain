import Foundation
import ActivityKit

public struct ArrivalTime: Identifiable, Equatable, Codable, Hashable {
    public let id: UUID
    public let time: Date
    public let direction: String
    public let isRealTime: Bool

    public init(id: UUID = UUID(), time: Date, direction: String, isRealTime: Bool) {
        self.id = id
        self.time = time
        self.direction = direction
        self.isRealTime = isRealTime
    }
}

public struct RumpyTrainWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        public var nextArrivalTime: Date
        public var routeId: String
        public var direction: String
        public var stationName: String
        public var allArrivalTimes: [String: [ArrivalTime]]
        
        public init(nextArrivalTime: Date, routeId: String, direction: String, stationName: String, allArrivalTimes: [String: [ArrivalTime]]) {
            self.nextArrivalTime = nextArrivalTime
            self.routeId = routeId
            self.direction = direction
            self.stationName = stationName
            self.allArrivalTimes = allArrivalTimes
        }

        public static func == (lhs: ContentState, rhs: ContentState) -> Bool {
            return lhs.nextArrivalTime == rhs.nextArrivalTime &&
                lhs.routeId == rhs.routeId &&
                lhs.direction == rhs.direction &&
                lhs.stationName == rhs.stationName &&
                lhs.allArrivalTimes == rhs.allArrivalTimes
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(nextArrivalTime)
            hasher.combine(routeId)
            hasher.combine(direction)
            hasher.combine(stationName)
            for key in allArrivalTimes.keys.sorted() {
                hasher.combine(key)
                hasher.combine(allArrivalTimes[key])
            }
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