import SwiftUI
import WidgetKit

@main
struct DiemWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayComplication()
        SessionWidget()
        StartStudyingControl()
    }
}
