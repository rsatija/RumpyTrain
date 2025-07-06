//
//  RumpyTrainWidgetBundle.swift
//  RumpyTrainWidget
//
//  Created by Rahul Satija on 7/6/25.
//

import WidgetKit
import SwiftUI

@main
struct RumpyTrainWidgetBundle: WidgetBundle {
    var body: some Widget {
        RumpyTrainWidget()
        RumpyTrainWidgetControl()
        RumpyTrainWidgetLiveActivity()
    }
}
