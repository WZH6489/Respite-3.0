import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Study Momentum" }
    static var description: IntentDescription { "Configuration for the Study Momentum widget." }
}
