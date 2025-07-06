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
            VStack(alignment: .leading, spacing: 8) {
                Text(context.attributes.stationName)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(1)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next Train")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        let minutesUntil = Int(context.state.nextArrivalTime.timeIntervalSince(Date()) / 60)
                        Text("\(minutesUntil)m")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(context.state.direction)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        SubwayLineIcon(routeId: context.state.routeId, size: 32)
                    }
                }
            }
            .padding()
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
                        
                        let minutesUntil = Int(context.state.nextArrivalTime.timeIntervalSince(Date()) / 60)
                        Text("\(minutesUntil)m")
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
                let minutesUntil = Int(context.state.nextArrivalTime.timeIntervalSince(Date()) / 60)
                Text("\(minutesUntil)m")
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
}

extension RumpyTrainWidgetAttributes {
    fileprivate static var preview: RumpyTrainWidgetAttributes {
        RumpyTrainWidgetAttributes(stationName: "Times Square-42 St", routeId: "1")
    }
}

extension RumpyTrainWidgetAttributes.ContentState {
    fileprivate static var sample: RumpyTrainWidgetAttributes.ContentState {
        RumpyTrainWidgetAttributes.ContentState(
            nextArrivalTime: Date().addingTimeInterval(300), // 5 minutes from now
            routeId: "1",
            direction: "uptown",
            stationName: "Times Square-42 St"
        )
     }
     
     fileprivate static var sample2: RumpyTrainWidgetAttributes.ContentState {
         RumpyTrainWidgetAttributes.ContentState(
             nextArrivalTime: Date().addingTimeInterval(180), // 3 minutes from now
             routeId: "A",
             direction: "downtown",
             stationName: "Times Square-42 St"
         )
     }
}

#Preview("Notification", as: .content, using: RumpyTrainWidgetAttributes.preview) {
   RumpyTrainWidgetLiveActivity()
} contentStates: {
    RumpyTrainWidgetAttributes.ContentState.sample
    RumpyTrainWidgetAttributes.ContentState.sample2
}
