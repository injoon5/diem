import AppIntents
import SwiftUI
import WidgetKit

/// The Control behind the Action Button. Same intent as everything else.
struct StartStudyingControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "app.diem.control.start") {
            ControlWidgetButton(action: StartSessionIntent()) {
                Label("Study", systemImage: "book.fill")
            }
        }
        .displayName("Start Studying")
        .description("Start a study session.")
    }
}
