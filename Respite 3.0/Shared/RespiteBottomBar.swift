import SwiftUI
import Combine

/// The tabs surfaced by the Respite bottom bar. Raw values control
/// left-to-right layout inside the expanded bar.
enum RespiteTab: Int, CaseIterable, Identifiable {
    case dashboard
    case study
    case wellness
    case reflections
    case settings

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .dashboard:   return "Dashboard"
        case .study:       return "Study"
        case .wellness:    return "Wellness"
        case .reflections: return "Reflections"
        case .settings:    return "Settings"
        }
    }

    var systemIcon: String {
        switch self {
        case .dashboard:   return "chart.bar.fill"
        case .study:       return "clock.badge.checkmark.fill"
        case .wellness:    return "heart.text.square.fill"
        case .reflections: return "book.closed.fill"
        case .settings:    return "gearshape.fill"
        }
    }
}

// MARK: - Shared state

/// Observable state that drives the bottom bar's collapse/expand behavior.
///
/// The bar is collapsed by default so only the floating Respite logo is
/// visible. Tapping the logo expands the bar (and hides the logo); tapping
/// any tab button or scrolling the active tab collapses it again (and the
/// logo returns). Logo and bar are mutually exclusive.
@MainActor
final class RespiteBottomBarState: ObservableObject {
    @Published var isExpanded: Bool = false

    /// Ignore scroll-driven collapse requests until this time. Set briefly
    /// after the user taps the logo so their explicit action isn't
    /// immediately undone by an in-flight scroll event.
    private var ignoreCollapseUntil: Date = .distantPast

    private let collapseThreshold: CGFloat = 28

    /// Reports the current vertical scroll offset (positive = scrolled down
    /// from the top) for the active tab. Scrolling the active tab only ever
    /// collapses the bar — it never auto-expands it, since the logo is the
    /// only intentional way to re-open the bar.
    func reportScrollOffset(_ offset: CGFloat) {
        guard offset > collapseThreshold else { return }
        guard Date() >= ignoreCollapseUntil else { return }
        guard isExpanded else { return }
        withAnimation(.easeInOut(duration: 0.28)) {
            isExpanded = false
        }
    }

    /// Expand the bar as a direct user gesture (tapping the floating logo).
    func expandFromLogoTap() {
        ignoreCollapseUntil = Date().addingTimeInterval(0.6)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            isExpanded = true
        }
    }

    /// Collapse the bar as a direct user gesture (tapping a tab button).
    /// Called after the tab switch so the transition feels like the bar
    /// "slides away" once you've made your selection.
    func collapseFromTabTap() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            isExpanded = false
        }
    }

    /// Reset to the default (collapsed) state — used when switching tabs.
    func resetForNewTab() {
        guard isExpanded else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            isExpanded = false
        }
    }
}

// MARK: - Scroll tracking

/// View modifier that forwards a scroll view's vertical content offset into
/// the shared `RespiteBottomBarState`. Attach to any top-level `ScrollView`
/// inside a tab so that tab participates in the collapse-on-scroll
/// behavior.
private struct RespiteBottomBarScrollTracker: ViewModifier {
    @EnvironmentObject private var state: RespiteBottomBarState

    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top
        } action: { _, newValue in
            state.reportScrollOffset(newValue)
        }
    }
}

extension View {
    /// Forwards vertical scroll offset into `RespiteBottomBarState`, driving
    /// the collapse-on-scroll behavior of the Respite bottom bar.
    func respiteTrackBottomBarScroll() -> some View {
        modifier(RespiteBottomBarScrollTracker())
    }
}

// MARK: - Bottom bar view

/// The custom Respite bottom navigation bar.
///
/// The bar and the floating logo are mutually exclusive: by default only
/// the circular Respite logo is shown at the bottom of the screen. Tapping
/// the logo expands the glass pill of tab buttons (and hides the logo).
/// Tapping a tab switches to it and collapses the bar, bringing the logo
/// back.
struct RespiteBottomBar: View {
    @Binding var selected: RespiteTab
    @ObservedObject var state: RespiteBottomBarState
    @Environment(\.colorScheme) private var colorScheme

    private let barHeight: CGFloat = 64
    private let logoSize: CGFloat = 62

    var body: some View {
        ZStack {
            if state.isExpanded {
                tabBarPill
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
            } else {
                logoButton
                    .transition(.scale(scale: 0.82).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 6)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: state.isExpanded)
    }

    // MARK: Tab pill

    private var tabBarPill: some View {
        HStack(spacing: 2) {
            ForEach(RespiteTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: barHeight)
        .frame(maxWidth: .infinity)
        .background(glassBackground)
        .overlay(
            Capsule()
                .stroke(borderStroke, lineWidth: 1)
        )
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.18), radius: 22, y: 10)
    }

    /// Authentic iOS 26 Liquid Glass treatment for the pill. Falls back to a
    /// tinted ultra-thin material on earlier releases.
    @ViewBuilder
    private var glassBackground: some View {
        if #available(iOS 26.0, *) {
            Capsule()
                .fill(.clear)
                .glassEffect(
                    .regular.interactive(),
                    in: .capsule
                )
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .fill(primaryTint.opacity(colorScheme == .dark ? 0.10 : 0.06))
                )
        }
    }

    private func tabButton(_ tab: RespiteTab) -> some View {
        let isActive = (selected == tab)
        return Button {
            InteractionFeedback.tap()
            if selected != tab {
                selected = tab
            }
            state.collapseFromTabTap()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.systemIcon)
                    .font(.system(size: 18, weight: isActive ? .semibold : .regular))
                    .symbolRenderingMode(.hierarchical)
                Text(tab.title)
                    .font(.system(size: 10, weight: isActive ? .semibold : .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(isActive ? primaryTint : secondaryTint)
            .frame(maxWidth: .infinity)
            .frame(height: barHeight - 10)
            .background(
                Capsule()
                    .fill(activeTabFill)
                    .opacity(isActive ? 1 : 0)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    // MARK: Logo button

    private var logoButton: some View {
        Button {
            InteractionFeedback.tap()
            state.expandFromLogoTap()
        } label: {
            // Clip the raw logo image itself to a circle so its own
            // white/dark backing fills the full disc — avoids the
            // "small glyph floating in an oversized white circle" look
            // that results from stacking the image on top of a separate
            // `Circle().fill()`.
            Image("RespiteLogo")
                .resizable()
                .scaledToFill()
                .frame(width: logoSize, height: logoSize)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(logoStroke, lineWidth: 1.25)
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.55 : 0.25), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show tab bar")
    }

    // MARK: Colors

    private var primaryTint: Color {
        colorScheme == .dark ? Color.white : Color.black
    }

    private var secondaryTint: Color {
        primaryTint.opacity(0.52)
    }

    private var activeTabFill: Color {
        (colorScheme == .dark ? Color.white : Color.black).opacity(colorScheme == .dark ? 0.16 : 0.10)
    }

    private var borderStroke: Color {
        primaryTint.opacity(colorScheme == .dark ? 0.22 : 0.14)
    }

    private var logoStroke: Color {
        primaryTint.opacity(colorScheme == .dark ? 0.28 : 0.16)
    }
}
