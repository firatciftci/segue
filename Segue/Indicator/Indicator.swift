import AppKit
import Observation
import SwiftUI

@Observable
private final class IndicatorModel {
    var source: InputSource?
    var label = ""
    var detail: String?
    var isVisible = false
    var alignment = Alignment.topTrailing
}

private final class GlassPanel: NSPanel {
    @objc func hasKeyAppearance() -> Bool { true }
    @objc func hasMainAppearance() -> Bool { true }
}

final class Indicator {
    static let shared = Indicator()

    private static let inset: CGFloat = 28
    private static let margin: CGFloat = 10
    private static let size = NSSize(width: 520, height: 160)

    private let model = IndicatorModel()
    private let panel: NSPanel
    private var hideTask: Task<Void, Never>?

    private init() {
        panel = GlassPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle, .transient]
        panel.contentView = NSHostingView(rootView: IndicatorView(model: model, inset: Self.inset))
    }

    func show(_ source: InputSource, detail: String?) {
        let prefs = Preferences.shared
        let label = prefs.label(for: source)
        let frame = Self.frame(for: prefs.indicatorPosition)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        hideTask?.cancel()
        if !panel.isVisible || panel.frame != frame {
            model.isVisible = false
            model.alignment = Self.alignment(for: prefs.indicatorPosition)
            update(source, label: label, detail: detail)
            panel.setFrame(frame, display: false)
            panel.orderFrontRegardless()
            panel.displayIfNeeded()
        }
        let appearing = !model.isVisible
        let animation: Animation =
            if reduceMotion {
                .easeOut(duration: 0.2)
            } else if appearing {
                .spring(duration: 0.5, bounce: 0.18)
            } else {
                .smooth(duration: 0.32)
            }
        withAnimation(animation) {
            update(source, label: label, detail: detail)
            model.isVisible = true
        }
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled, let self else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.25) : .smooth(duration: 0.5)) {
                self.model.isVisible = false
            } completion: { [weak self] in
                guard let self, !self.model.isVisible else { return }
                self.panel.orderOut(nil)
            }
        }
    }

    private func update(_ source: InputSource, label: String, detail: String?) {
        model.source = source
        model.label = label
        model.detail = detail
    }

    private static func alignment(for position: IndicatorPosition) -> Alignment {
        switch position {
        case .topRight: .topTrailing
        case .center: .center
        case .bottom: .bottom
        }
    }

    private static func frame(for position: IndicatorPosition) -> NSRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return NSRect(origin: .zero, size: size) }
        let offset = inset - margin
        let origin: NSPoint =
            switch position {
            case .topRight: NSPoint(x: visible.maxX - size.width + offset, y: visible.maxY - size.height + offset)
            case .center: NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2)
            case .bottom: NSPoint(x: visible.midX - size.width / 2, y: visible.minY + visible.height * 0.12 - inset)
            }
        return NSRect(origin: origin, size: size).integral
    }
}

private struct IndicatorView: View {
    let model: IndicatorModel
    let inset: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: model.alignment) {
            Color.clear
            GlassEffectContainer {
                if model.isVisible, let source = model.source {
                    card(source)
                        .glassEffectTransition(reduceMotion ? .identity : .materialize)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.9, anchor: anchor).combined(with: .opacity))
                }
            }
        }
        .padding(inset)
    }

    private var anchor: UnitPoint {
        switch model.alignment {
        case .topTrailing: .topTrailing
        case .bottom: .bottom
        default: .center
        }
    }

    private var contentAlignment: Alignment {
        model.alignment == .topTrailing ? .trailing : .center
    }

    private func card(_ source: InputSource) -> some View {
        row(source)
            .hidden()
            .overlay(alignment: contentAlignment) {
                ZStack(alignment: contentAlignment) {
                    row(source)
                        .id(Content(source: source.id, label: model.label, detail: model.detail))
                        .transition(reduceMotion ? .opacity : AnyTransition(.blurReplace))
                }
                .fixedSize()
            }
            .padding(.vertical, 12)
            .padding(.leading, 14)
            .padding(.trailing, 16)
            .clipShape(.capsule)
            .glassEffect(.regular, in: .capsule)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(source.name)
            .accessibilityValue(model.detail ?? "")
    }

    private func row(_ source: InputSource) -> some View {
        HStack(spacing: 12) {
            SourceIcon(source: source, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(source.name)
                    .font(.headline)
                    .lineLimit(1)
                if let detail = model.detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Text(model.label)
                .font(.callout.weight(.semibold).monospaced())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .overlay {
                    RoundedRectangle(cornerRadius: 5).strokeBorder(.secondary.opacity(0.6), lineWidth: 1)
                }
        }
    }

    private struct Content: Hashable {
        let source: String
        let label: String
        let detail: String?
    }
}
