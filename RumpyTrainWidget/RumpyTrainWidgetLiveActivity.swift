//
//  RumpyTrainWidgetLiveActivity.swift
//  RumpyTrainWidget
//
//  Created by Rahul Satija on 7/6/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct SubwayLineIcon: View {
    let routeId: String
    let size: CGFloat
    
    private var backgroundColor: Color {
        switch routeId {
        case "1", "2", "3":
            return Color(red: 0.937, green: 0.251, blue: 0.251)  // #EF4040 - Red
        case "4", "5", "6", "6X":
            return Color(red: 0, green: 0.569, blue: 0.369)      // #009159 - Green
        case "7", "7X":
            return Color(red: 0.753, green: 0.361, blue: 0.753)  // #B25AB2 - Purple
        case "A", "C", "E":
            return Color(red: 0, green: 0.349, blue: 0.647)      // #0059A5 - Blue
        case "B", "D", "F", "M":
            return Color(red: 1, green: 0.647, blue: 0)          // #FF9B00 - Orange
        case "G":
            return Color(red: 0.435, green: 0.808, blue: 0.275)  // #6FCE46 - Light Green
        case "J", "Z":
            return Color(red: 0.647, green: 0.455, blue: 0.192)  // #A57431 - Brown
        case "L":
            return Color(red: 0.667, green: 0.667, blue: 0.667)  // #AAAAAA - Gray
        case "N", "Q", "R", "W":
            return Color(red: 1, green: 0.851, blue: 0.263)      // #FFD943 - Yellow
        case "S", "H":
            return Color(red: 0.506, green: 0.506, blue: 0.506)  // #818181 - Dark Gray
        default:
            return .gray
        }
    }
    
    private var textColor: Color {
        // Yellow background lines need black text for contrast
        switch routeId {
        case "N", "Q", "R", "W":
            return .black
        default:
            return .white
        }
    }
    
    var body: some View {
        Text(routeId)
            .font(.system(size: size * 0.7, weight: .bold))
            .frame(width: size, height: size)
            .foregroundColor(textColor)
            .background(backgroundColor)
            .clipShape(Circle())
    }
}

struct RumpyTrainWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RumpyTrainWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack(alignment: .leading, spacing: 12) {
                // Station name header
                Text(context.attributes.stationName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                // Show arrival times for multiple routes
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(Array(context.state.allArrivalTimes.keys).sorted(), id: \.self) { routeId in
                        if let times = context.state.allArrivalTimes[routeId], !times.isEmpty {
                            let displayTimes = Array(times.prefix(2)) // Show next 2 trains
                            VStack(alignment: .leading, spacing: 6) {
                                // Route header with icon and direction
                                HStack(spacing: 8) {
                                    SubwayLineIcon(routeId: routeId, size: 24)
                                    
                                    if !displayTimes.isEmpty {
                                        Text(displayTimes[0].direction.capitalized)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.secondary)
                                            .textCase(.uppercase)
                                    }
                                }
                                
                                // Arrival times
                                HStack(spacing: 6) {
                                    ForEach(displayTimes, id: \.id) { arrival in
                                        VStack(spacing: 1) {
                                            Text(formatTime(arrival.time))
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.primary)
                                            Text("arrival")
                                                .font(.system(size: 9, weight: .medium))
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(minWidth: 40)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.gray.opacity(0.15))
                                        )
                                    }
                                }
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.gray.opacity(0.08))
                            )
                        }
                    }
                }
                
                // Last update timestamp
                HStack {
                    Spacer()
                    Text("Updated \(Date(), style: .time)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .activityBackgroundTint(Color(.systemBackground))
            .activitySystemActionForegroundColor(Color.primary)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text("Next Train")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatTime(context.state.nextArrivalTime))
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text(context.state.direction)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        SubwayLineIcon(routeId: context.state.routeId, size: 28)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.stationName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } compactLeading: {
                Text(formatTime(context.state.nextArrivalTime))
                    .font(.caption)
                    .fontWeight(.bold)
            } compactTrailing: {
                SubwayLineIcon(routeId: context.state.routeId, size: 20)
            } minimal: {
                SubwayLineIcon(routeId: context.state.routeId, size: 16)
            }
            .widgetURL(URL(string: "rumpytrain://station/\(context.attributes.stationName)"))
            .keylineTint(Color.blue)
        }
    }
    
    // Helper function to format time as HH:MM
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

extension RumpyTrainWidgetAttributes {
    fileprivate static var preview: RumpyTrainWidgetAttributes {
        RumpyTrainWidgetAttributes(stationName: "Times Square-42 St", routeId: "1")
    }
}

extension RumpyTrainWidgetAttributes.ContentState {
    fileprivate static var sample: RumpyTrainWidgetAttributes.ContentState {
        let sampleArrival1 = ArrivalTime(time: Date().addingTimeInterval(300), direction: "uptown", isRealTime: true)
        let sampleArrival2 = ArrivalTime(time: Date().addingTimeInterval(420), direction: "uptown", isRealTime: false)
        let sampleArrivalTimes = ["1": [sampleArrival1, sampleArrival2]]
        
        return RumpyTrainWidgetAttributes.ContentState(
            nextArrivalTime: Date().addingTimeInterval(300), // 5 minutes from now
            routeId: "1",
            direction: "uptown",
            stationName: "Times Square-42 St",
            allArrivalTimes: sampleArrivalTimes
        )
     }
     
     fileprivate static var sample2: RumpyTrainWidgetAttributes.ContentState {
        let sampleArrival1 = ArrivalTime(time: Date().addingTimeInterval(180), direction: "downtown", isRealTime: true)
        let sampleArrival2 = ArrivalTime(time: Date().addingTimeInterval(300), direction: "downtown", isRealTime: false)
        let sampleArrivalTimes = ["A": [sampleArrival1, sampleArrival2]]
        
        return RumpyTrainWidgetAttributes.ContentState(
            nextArrivalTime: Date().addingTimeInterval(180), // 3 minutes from now
            routeId: "A",
            direction: "downtown",
            stationName: "Times Square-42 St",
            allArrivalTimes: sampleArrivalTimes
        )
     }
}

#Preview("Notification", as: .content, using: RumpyTrainWidgetAttributes.preview) {
   RumpyTrainWidgetLiveActivity()
} contentStates: {
    RumpyTrainWidgetAttributes.ContentState.sample
    RumpyTrainWidgetAttributes.ContentState.sample2
}
