import SwiftUI
import UIKit

/// Monotone screen-space projection: widest spacing in the reading zone, tight spacing at the pocket.
struct ReceiptStackProjection {
    static let pitch: CGFloat = 136
    static let paperHeight: CGFloat = 244
    let anchor: CGFloat
    let readingY: CGFloat
    let viewportHeight: CGFloat
    private let minimum: CGFloat = 36 / 136
    private let amplitude: CGFloat = (224 - 36) / 136
    private let width: CGFloat
    private let focus: CGFloat

    init(viewportHeight: CGFloat, readingY: CGFloat, anchor: CGFloat) {
        self.viewportHeight = viewportHeight; self.readingY = readingY; self.anchor = anchor
        width = max(60, min(130, viewportHeight * 0.15))
        var low: CGFloat = -4000, high: CGFloat = 4000
        for _ in 0..<40 {
            let distance = (low + high) / 2
            let span = minimum * distance + amplitude * width * tanh(distance / width)
            if span < anchor - readingY { low = distance } else { high = distance }
        }
        focus = anchor - (low + high) / 2
    }
    func position(_ logicalY: CGFloat) -> CGFloat {
        anchor + minimum * (logicalY - anchor)
        + amplitude * width * (tanh((logicalY - focus) / width) - tanh((anchor - focus) / width))
    }
    func logicalPosition(_ displayedY: CGFloat) -> CGFloat {
        var low = anchor - 20_000, high = anchor + 20_000
        for _ in 0..<44 {
            let middle = (low + high) / 2
            if position(middle) < displayedY { low = middle } else { high = middle }
        }
        return (low + high) / 2
    }
    func displayedPosition(_ logicalY: CGFloat, endPull: CGFloat) -> CGFloat {
        // Beyond the last receipt, preserve the shared paper-and-wallet rubber band.
        position(logicalY + endPull) - endPull
    }
    func visibleIndices(baseY: CGFloat, count: Int, endPull: CGFloat) -> Range<Int> {
        guard count > 0 else { return 0..<0 }
        let start = Int(floor((logicalPosition(-300 + endPull) - endPull - baseY) / Self.pitch))
        let end = Int(ceil((logicalPosition(viewportHeight + 60 + endPull) - endPull - baseY) / Self.pitch)) + 1
        let first = max(0, min(count, start)), last = max(first, min(count, end))
        return first..<last
    }
}

/// Distances are calculated from frozen screen rectangles, never chronological indices.
struct ReceiptDepartureGeometry {
    static func travel(frame: CGRect, selected: CGRect, viewportHeight: CGFloat,
                       topInset: CGFloat, bottomInset: CGFloat) -> CGFloat {
        let shadowMargin: CGFloat = 48
        if frame.minY < selected.minY {
            return -max(shadowMargin, frame.maxY + topInset + shadowMargin)
        }
        return max(shadowMargin, viewportHeight + bottomInset + shadowMargin - frame.minY)
    }
}

private struct WalletStackOrigin: Equatable {
    let revision: UUID
    let y: CGFloat
}

private struct WalletDepartingPaper: Identifiable {
    let record: ReceiptRecord
    let index: Int
    let frame: CGRect
    let travel: CGFloat
    var id: UUID { record.id }
}

/// One retained scene: papers leave in their screen order while the selected paper lifts in place.
struct ReceiptWalletScene: View {
    @Bindable var workspace: ReceiptWorkspace
    var openOverview: (String) -> Void
    var requestDelete: (ReceiptRecord) -> Void
    @State private var presented: ReceiptRecord?
    @State private var expanded = false
    @State private var readerSettled = false
    @State private var origin = CGRect.zero
    @State private var departingPapers: [WalletDepartingPaper] = []
    @State private var retainedRecords: [ReceiptRecord]?
    @State private var retainedLayout: ReceiptWalletLayout?
    @State private var positioned = false
    @State private var selectedLayer = 1
    @State private var selectedTilt: Double = 0
    @State private var walletTravel: CGFloat = 0
    @State private var walletFrame = CGRect.zero
    @State private var walletHeight: CGFloat = 110
    @State private var endBounce: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var walletScroll = ScrollPosition()
    @State private var openingOffset: CGFloat = 0
    @State private var jumpToNewest = 0
    @State private var stackSceneY: CGFloat?
    @ScaledMetric(relativeTo: .body) private var accessiblePaperHeight: CGFloat = 190
    @ScaledMetric(relativeTo: .caption) private var accessibleHeadingHeight: CGFloat = 40
    private let tuckedDepth: CGFloat = 32
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var systemMotion
    @State private var revealedID: UUID?
    private var reduceMotion: Bool { ReceiptAccessibility.reduceMotion(systemMotion) }
    private var selectedID: UUID? { [.detail, .review].contains(workspace.flow) ? workspace.selected?.id : nil }
    private var records: [ReceiptRecord] { retainedRecords ?? workspace.walletReceipts }
    private var layout: ReceiptWalletLayout { retainedLayout ?? workspace.walletLayout }
    private var motion: Animation { reduceMotion ? .easeOut(duration: 0.12) : .easeInOut(duration: 0.38) }
    // A bounded follow-through in both directions. Overscroll moves the leather at
    // 22% of the paper's end pull; normal scrolling adds at most 22 points of drift.
    private var pocketMotion: CGFloat { reduceMotion ? 0 : -22 * tanh(scrollOffset / 400) - endBounce * 0.22 }
    private var elastic: Bool { !reduceMotion && !typeSize.isAccessibilitySize }

    private var previewHeight: CGFloat { typeSize.isAccessibilitySize ? accessiblePaperHeight : ReceiptStackProjection.paperHeight }
    private var headingHeight: CGFloat { typeSize.isAccessibilitySize ? accessibleHeadingHeight : ReceiptWalletLayout.headingHeight }
    private var plainLayout: ReceiptWalletPlainLayout {
        ReceiptWalletPlainLayout(grouped: layout, paperHeight: previewHeight, headingHeight: headingHeight)
    }
    private var contentHeight: CGFloat { elastic ? layout.height : plainLayout.height }
    private func offset(_ index: Int) -> CGFloat { elastic ? layout.offsets[index] : plainLayout.offset(index) }

    var body: some View {
        GeometryReader { geometry in
            let viewportHeight = geometry.size.height
            ZStack(alignment: .topLeading) {
                if !records.isEmpty {
                    walletBack(in: geometry)
                        .offset(x: 20, y: geometry.size.height - walletHeight - 32 + pocketMotion)
                        .opacity(presented == nil ? 1 : 0)
                        .zIndex(-1)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            if records.isEmpty {
                                VStack(spacing: 24) {
                                    EmptyWalletArtwork().frame(width: 240, height: 190)
                                    VStack(spacing: 10) {
                                        Text(workspace.hasBrowseFilters || !workspace.searchQuery.isEmpty ? "No matching receipts" : workspace.receipts.isEmpty ? "A place for your receipts" : "Your wallet is clear").font(.title2.weight(.semibold))
                                        Text(workspace.hasBrowseFilters ? "Try changing or clearing your filters." : "Import a photo. Keep the details.")
                                        if workspace.hasBrowseFilters { Button("Clear filters", action: workspace.resetBrowseFilters).buttonStyle(ReceiptSecondaryStyle()) }
                                    }.multilineTextAlignment(.center)
                                    Label("Private · on this device", systemImage: "lock").font(.footnote).padding(.top, 4)
                                }
                                .padding(.horizontal, 8).padding(.vertical, 32)
                                .frame(maxWidth: .infinity, minHeight: max(0, geometry.size.height - 140))
                                .opacity(selectedID == nil ? 1 : 0)
                                if let notice = workspace.notice {
                                    Text(notice).font(.footnote).padding(.top, 24).opacity(selectedID == nil ? 1 : 0)
                                }
                            } else {
                                paperStack(in: geometry)
                                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                                    if !positioned, !records.isEmpty, height > 0 {
                                        positioned = true
                                        var transaction = Transaction(animation: nil)
                                        transaction.disablesAnimations = true
                                        withTransaction(transaction) {
                                            if let focus = workspace.walletFocus, layout.indexByID[focus.receiptID] != nil {
                                                let target = focusOffset(focus, geometry: geometry, calibration: 0)
                                                walletScroll.scrollTo(y: target); workspace.walletScrollOffset = target
                                                workspace.walletFocus = nil
                                            } else if let offset = workspace.walletScrollOffset {
                                                walletScroll.scrollTo(y: offset)
                                            } else {
                                                // Keep the resting position at the pocket as the keyboard inset settles.
                                                walletScroll.scrollTo(edge: .bottom)
                                            }
                                        }
                                    }
                                }
                                .padding(.top, stackTop(in: geometry))
                                // Even at the last scroll position, the paper stays inside the pocket.
                                Color.clear.frame(height: max(0, walletHeight + 20 - tuckedDepth)).id("walletEnd")
                            }
                            #if DEBUG
                            if records.isEmpty { WorkflowTestControls(workspace: workspace) }
                            #endif
                        }.padding(.horizontal, 20).padding(.top, records.isEmpty ? 14 : 0).padding(.bottom, records.isEmpty ? 24 : 0)
                            .onGeometryChange(for: CGFloat.self) { content in
                                // Measure the actual stack end, including native rubber-banding.
                                // For a short stack, its resting end is above the viewport bottom.
                                let restingEnd = min(viewportHeight, content.size.height)
                                return max(0, restingEnd - content.frame(in: .named("walletScene")).maxY)
                            } action: { pull in
                                endBounce = reduceMotion ? 0 : pull
                            }
                    }
                    .swipeActionsContainer()
                    .onChange(of: jumpToNewest) { _, _ in
                        withAnimation(motion) { proxy.scrollTo("walletEnd", anchor: .bottom) }
                    }
                    .onChange(of: workspace.walletFocus) { _, focus in
                        guard let focus, presented == nil, positioned, layout.indexByID[focus.receiptID] != nil else { return }
                        let calibration = (stackSceneY ?? stackTop(in: geometry)) + scrollOffset - stackTop(in: geometry)
                        let target = focusOffset(focus, geometry: geometry, calibration: calibration)
                        var transaction = Transaction(animation: nil); transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            walletScroll.scrollTo(y: target); workspace.walletScrollOffset = target
                            workspace.walletFocus = nil
                        }
                    }
                    .onChange(of: workspace.walletJumpID) { _, id in
                        guard let id, let section = layout.sections.first(where: { $0.id == id }) else { return }
                        revealedID = nil
                        let curve = projection(in: geometry)
                        let readingPosition = elastic ? curve.logicalPosition(curve.readingY) : curve.readingY
                        let target = max(0, stackTop(in: geometry) + offset(section.indices.lowerBound) - readingPosition)
                        withAnimation(motion) { walletScroll.scrollTo(y: target) }
                        workspace.walletMonthID = section.id
                        workspace.walletJumpID = nil
                    }
                    .opacity(presented == nil ? 1 : 0)
                    .scrollDisabled(presented != nil)
                    .allowsHitTesting(presented == nil)
                    .accessibilityHidden(true, isEnabled: presented != nil)
                    .scrollBounceBehavior(.always)
                    .scrollPosition($walletScroll)
                    .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, offset in
                        scrollOffset = offset
                        if positioned && presented == nil && !records.isEmpty { workspace.walletScrollOffset = offset }
                    }
                    .walletScreenEdges(in: geometry)
                }
                if !records.isEmpty {
                    pocketBacking(in: geometry)
                        .offset(y: geometry.size.height - 32 + pocketMotion)
                        .opacity(presented == nil ? 1 : 0)
                        .zIndex(Double(records.count) + 1.9)
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        walletPocket { jumpToNewest += 1 }
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("walletScene")) } action: {
                                walletHeight = $0.height
                                if presented == nil { walletFrame = $0 }
                            }
                            .padding(.horizontal, 20).padding(.bottom, 20)
                    }
                    .frame(width: max(0, geometry.size.width), height: max(0, geometry.size.height))
                    .offset(y: pocketMotion)
                    .opacity(presented == nil ? 1 : 0)
                    .allowsHitTesting(presented == nil)
                    .accessibilityHidden(true, isEnabled: presented != nil)
                    .zIndex(Double(records.count + 2))
                }
                if let presented {
                    liftedPaper(presented, geometry: geometry)
                        .frame(width: max(0, geometry.size.width), height: max(0, geometry.size.height))
                        .zIndex(Double(selectedLayer))
                    // The entire live stack is hidden. Each visible neighbour has one frozen
                    // scene sibling, retaining its original depth for both directions.
                    ForEach(departingPapers) { paper in
                        ReceiptPreviewSurface(record: paper.record)
                            .frame(width: paper.frame.width, height: paper.frame.height)
                            .rotationEffect(.degrees(elastic ? tilt(paper.index) : 0))
                            .offset(x: paper.frame.minX,
                                    y: paper.frame.minY + (expanded && !reduceMotion ? paper.travel : 0))
                            .opacity(expanded ? 0 : 1)
                            .zIndex(Double(paper.index + 1))
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }
                    if walletFrame != .zero {
                        walletBack(in: geometry)
                            .offset(x: walletFrame.minX, y: walletFrame.minY - 12 + (expanded && !reduceMotion ? walletTravel : 0))
                            .opacity(expanded ? 0 : 1)
                            .zIndex(-1)
                            .allowsHitTesting(false).accessibilityHidden(true)
                        pocketBacking(in: geometry)
                            .offset(y: walletFrame.maxY - 12 + (expanded && !reduceMotion ? walletTravel : 0))
                            .opacity(expanded ? 0 : 1)
                            .zIndex(Double(records.count) + 1.9)
                        walletPocket {}
                            .frame(width: walletFrame.width, height: walletFrame.height)
                            .offset(x: walletFrame.minX, y: walletFrame.minY + (expanded && !reduceMotion ? walletTravel : 0))
                            .opacity(expanded ? 0 : 1)
                            .zIndex(Double(records.count + 2))
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .coordinateSpace(name: "walletScene")
            .animation(motion, value: layout.receiptIDs)
            .onChange(of: workspace.walletLayout.receiptIDs) { _, ids in
                if ids.isEmpty && presented == nil {
                    positioned = false; stackSceneY = nil; scrollOffset = 0; openingOffset = 0
                }
            }
            .onChange(of: workspace.selected) { _, current in
                guard let current, presented?.id == current.id else { return }
                presented = current
                if let index = retainedRecords?.firstIndex(where: { $0.id == current.id }) { retainedRecords?[index] = current }
            }
            .onChange(of: selectedID, initial: true) { _, next in
                revealedID = nil
                if next != nil, let record = workspace.selected {
                    if presented?.id != record.id { preparePresentation(record, geometry: geometry) }
                } else if presented != nil {
                    let returningID = presented?.id
                    prepareUpdatedReturn(in: geometry)
                    walletScroll.scrollTo(y: openingOffset)
                    readerSettled = false
                    withAnimation(motion, completionCriteria: .removed) { expanded = false } completion: {
                        guard selectedID == nil, presented?.id == returningID else { return }
                        var transaction = Transaction(animation: nil)
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            presented = nil; departingPapers = []; retainedRecords = nil; retainedLayout = nil
                            if workspace.walletReceipts.isEmpty {
                                positioned = false; stackSceneY = nil; scrollOffset = 0; openingOffset = 0
                            }
                        }
                    }
                }
            }

        }
    }
    private func preparePresentation(_ record: ReceiptRecord, geometry: GeometryProxy) {
        openingOffset = scrollOffset
        let snapshot = records
        // Both presentation modes use the same deterministic geometry as rendering.
        let curve = projection(in: geometry)
        let baseY = stackSceneY ?? stackTop(in: geometry)
        let frames = Dictionary(uniqueKeysWithValues: visibleIndices(curve, baseY: baseY).map { index in
            let logicalY = baseY + offset(index)
            let y = elastic ? curve.displayedPosition(logicalY, endPull: endBounce) : logicalY
            return (snapshot[index].id, CGRect(x: 30, y: y + pocketMotion,
                width: max(0, geometry.size.width - 60), height: previewHeight))
        })
        let selectedFrame = frames[record.id] ?? CGRect(x: 30, y: 52, width: max(0, geometry.size.width - 60), height: 244)
        retainedRecords = snapshot
        retainedLayout = layout
        selectedLayer = (snapshot.firstIndex { $0.id == record.id } ?? snapshot.count) + 1
        selectedTilt = elastic ? tilt(selectedLayer - 1) : 0
        origin = selectedFrame
        workspace.walletAnchorID = record.id; workspace.walletAnchorY = selectedFrame.minY
        departingPapers = snapshot.enumerated().compactMap { index, neighbour in
            guard neighbour.id != record.id, let frame = frames[neighbour.id],
                  frame.maxY > -geometry.safeAreaInsets.top - 48,
                  frame.minY < geometry.size.height + geometry.safeAreaInsets.bottom + 48 else { return nil }
            return WalletDepartingPaper(record: neighbour, index: index, frame: frame,
                travel: ReceiptDepartureGeometry.travel(frame: frame, selected: selectedFrame,
                    viewportHeight: geometry.size.height, topInset: geometry.safeAreaInsets.top,
                    bottomInset: geometry.safeAreaInsets.bottom))
        }
        walletFrame = CGRect(x: 20, y: geometry.size.height - walletHeight - 20 + pocketMotion,
                             width: max(0, geometry.size.width - 40), height: walletHeight)
        walletTravel = geometry.size.height + geometry.safeAreaInsets.bottom + 60 - walletFrame.minY
        // All siblings mount at their home positions before the next display frame.
        expanded = false
        readerSettled = false
        presented = record
    }
    private func focusOffset(_ focus: ReceiptWalletFocus, geometry: GeometryProxy, calibration: CGFloat) -> CGFloat {
        guard let index = layout.indexByID[focus.receiptID] else { return max(0, scrollOffset) }
        let curve = projection(in: geometry), desiredY = focus.y ?? curve.readingY
        let top = stackTop(in: geometry)
        let maximum = max(0, top + contentHeight + walletHeight + 20 - tuckedDepth - geometry.size.height)
        var target = scrollOffset
        // The leather follows normal scrolling by a small bounded amount.
        for _ in 0..<4 {
            let drift = reduceMotion ? 0 : -22 * tanh(target / 400)
            let logical = elastic ? curve.logicalPosition(desiredY - drift) : desiredY - drift
            target = min(maximum, max(0, top + offset(index) + calibration - logical))
        }
        return target
    }
    private func prepareUpdatedReturn(in geometry: GeometryProxy) {
        guard let focus = workspace.walletFocus, !workspace.walletReceipts.isEmpty else { return }
        let calibration = (stackSceneY ?? stackTop(in: geometry)) + openingOffset - stackTop(in: geometry)
        // All departing copies remain invisible while the fresh home layout is prepared.
        retainedRecords = workspace.walletReceipts; retainedLayout = workspace.walletLayout
        guard layout.indexByID[focus.receiptID] != nil else { workspace.walletFocus = nil; return }
        openingOffset = focusOffset(focus, geometry: geometry, calibration: calibration)
        workspace.walletScrollOffset = openingOffset
        let base = stackTop(in: geometry) - openingOffset + calibration
        let curve = projection(in: geometry)
        let drift = reduceMotion ? 0 : -22 * tanh(openingOffset / 400)
        let frames = Dictionary(uniqueKeysWithValues: visibleIndices(curve, baseY: base).map { index in
            let y = base + offset(index)
            return (records[index].id, CGRect(x: 30, y: (elastic ? curve.position(y) : y) + drift,
                width: max(0, geometry.size.width - 60), height: previewHeight))
        })
        if let selected = presented, let index = layout.indexByID[selected.id], let frame = frames[selected.id] {
            origin = frame; selectedLayer = index + 1; selectedTilt = elastic ? tilt(index) : 0
        }
        departingPapers = records.enumerated().compactMap { index, record in
            guard record.id != presented?.id, let frame = frames[record.id] else { return nil }
            return WalletDepartingPaper(record: record, index: index, frame: frame,
                travel: ReceiptDepartureGeometry.travel(frame: frame, selected: origin,
                    viewportHeight: geometry.size.height, topInset: geometry.safeAreaInsets.top,
                    bottomInset: geometry.safeAreaInsets.bottom))
        }
        walletFrame.origin.y = geometry.size.height - walletHeight - 20 + drift
        walletTravel = geometry.size.height + geometry.safeAreaInsets.bottom + 60 - walletFrame.minY
        workspace.walletFocus = nil
    }
    private func projection(in geometry: GeometryProxy) -> ReceiptStackProjection {
        let fullHeight = geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
        return ReceiptStackProjection(viewportHeight: geometry.size.height,
            readingY: fullHeight / 3 - geometry.safeAreaInsets.top,
            anchor: geometry.size.height - walletHeight - 20 + tuckedDepth - ReceiptStackProjection.paperHeight)
    }
    private func paperStack(in geometry: GeometryProxy) -> some View {
        let snapshot = records
        let renderLayout = layout
        let isElastic = elastic
        let height = previewHeight, header = headingHeight
        let plain = ReceiptWalletPlainLayout(grouped: renderLayout, paperHeight: height, headingHeight: header)
        let curve = projection(in: geometry)
        let baseY = stackSceneY ?? stackTop(in: geometry)
        let visible = isElastic
            ? renderLayout.visibleIndices(lower: curve.logicalPosition(-300 + endBounce) - endBounce - baseY,
                                          upper: curve.logicalPosition(curve.viewportHeight + 100 + endBounce) - endBounce - baseY)
            : plain.visibleIndices(lower: -80 - baseY, upper: curve.viewportHeight + 80 - baseY)
        // SwiftUI can evaluate a departing child after the workspace has changed.
        // Capture its offsets and section together with its record, rather than indexing
        // the live layout from a deferred ForEach/overlay closure.
        let papers = visible.map { index in
            let logicalY = baseY + (isElastic ? renderLayout.offsets[index] : plain.offset(index))
            let y = isElastic ? curve.displayedPosition(logicalY, endPull: endBounce) : logicalY
            let section = renderLayout.sections[renderLayout.sectionIndices[index]]
            return (index: index, record: snapshot[index], y: y,
                    section: section.indices.lowerBound == index ? section : nil,
                    tilt: isElastic ? tilt(index) : 0)
        }
        return ZStack(alignment: .topLeading) {
            ForEach(papers, id: \.record.id) { paper in
                card(paper.record, index: paper.index, geometry: geometry)
                    .frame(height: height)
                    .id(paper.record.id)
                    .zIndex(revealedID == paper.record.id ? Double(snapshot.count + 1) : Double(paper.index + 1))
                    .rotationEffect(.degrees(paper.tilt))
                    .overlay(alignment: .topLeading) {
                        if let section = paper.section {
                            let month = ReceiptHistory.monthKey(paper.record)
                            monthHeading(section, month: month).offset(y: -header)
                        }
                    }
                    .offset(y: paper.y - baseY + pocketMotion)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: isElastic ? renderLayout.height : plain.height, alignment: .topLeading)
        .onGeometryChange(for: WalletStackOrigin.self) {
            WalletStackOrigin(revision: renderLayout.revision, y: $0.frame(in: .named("walletScene")).minY)
        } action: { measurement in
            guard layout.revision == measurement.revision else { return }
            let value = measurement.y
            stackSceneY = value
            if presented == nil {
                let logical = (isElastic ? curve.logicalPosition(curve.readingY) : curve.readingY) - value
                if !renderLayout.receiptIDs.isEmpty {
                    let index = min(renderLayout.receiptIDs.count - 1,
                                    isElastic ? renderLayout.lowerBound(logical) : plain.lowerBound(logical))
                    workspace.walletMonthID = renderLayout.sections[renderLayout.sectionIndices[index]].id
                    workspace.walletAnchorID = renderLayout.receiptIDs[index]
                    let logicalY = value + (isElastic ? renderLayout.offsets[index] : plain.offset(index))
                    workspace.walletAnchorY = (isElastic ? curve.displayedPosition(logicalY, endPull: endBounce) : logicalY) + pocketMotion
                }
            }
        }
        .padding(.horizontal, 10)
    }
    private func visibleIndices(_ curve: ReceiptStackProjection, baseY: CGFloat) -> Range<Int> {
        if elastic {
            return layout.visibleIndices(lower: curve.logicalPosition(-300 + endBounce) - endBounce - baseY,
                                         upper: curve.logicalPosition(curve.viewportHeight + 100 + endBounce) - endBounce - baseY)
        }
        return plainLayout.visibleIndices(lower: -80 - baseY, upper: curve.viewportHeight + 80 - baseY)
    }
    private func monthHeading(_ section: ReceiptWalletLayout.Section, month: String?) -> some View {
        let label = HStack(spacing: 6) {
            Text(section.title).fontWeight(.semibold)
            Text("· \(section.count)").foregroundStyle(.secondary)
            if month != nil { Image(systemName: "chart.bar").accessibilityHidden(true) }
        }
        .font(.caption).lineLimit(1).minimumScaleFactor(0.6)
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(.regularMaterial, in: .capsule)

        return Group {
            if let month {
                Button { openOverview(month) } label: {
                    label.frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the purchase overview for this month")
            } else {
                label.accessibilityElement(children: .combine)
            }
        }
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("walletSection-" + section.id)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func card(_ record: ReceiptRecord, index: Int, geometry: GeometryProxy) -> some View {
        return ReceiptSwipePaper(record: record, identifier: "receipt-\(index)") {
            guard workspace.walletLayout.indexByID[record.id] != nil else { return }
            // Freeze the screen rectangle before navigation changes native insets.
            preparePresentation(record, geometry: geometry)
            workspace.open(record)
        } perform: { action in
            if action == .delete { requestDelete(record) } else { workspace.organize(record, action: action) }
        } onPresentationChanged: { isPresented in
            if isPresented { revealedID = record.id }
            else if revealedID == record.id { revealedID = nil }
        }
        .allowsHitTesting(presented == nil)
    }
    private func stackTop(in geometry: GeometryProxy) -> CGFloat {
        if elastic {
            let curve = projection(in: geometry)
            return max(curve.logicalPosition(14), curve.anchor - layout.lastOffset)
        }
        let pocketTop = geometry.size.height - walletHeight - 20
        return max(14, pocketTop + tuckedDepth - contentHeight)
    }
    private func tilt(_ index: Int) -> Double {
        typeSize.isAccessibilitySize ? 0 : [-1.0, 0.7, -0.5, 1.1][index % 4]
    }
    private func walletPocket(_ jump: @escaping () -> Void) -> some View {
        WalletCrown(count: records.count, filtered: workspace.hasBrowseFilters || !workspace.searchQuery.isEmpty, jumpToLatest: jump).fixedSize(horizontal: false, vertical: true)
            .allowsHitTesting(presented == nil)
    }
    private func pocketBacking(in geometry: GeometryProxy) -> some View {
        // The top follows the pocket, but coverage must always reach the screen bottom.
        // Upward drift and end pull otherwise lift the backing off the home-indicator area.
        // Keep the existing feather above the fully opaque lower backing.
        let feather: CGFloat = 32
        let upwardTravel = max(0, -pocketMotion)
        return AtmosphericBackground(alignedToWindow: true)
            .frame(width: geometry.size.width, height: 32 + geometry.safeAreaInsets.bottom + feather + upwardTravel)
            .mask {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: feather)
                    Color.black
                }
            }
            .offset(y: -feather)
            .allowsHitTesting(false).accessibilityHidden(true)
    }
    private func walletBack(in geometry: GeometryProxy) -> some View {
        WalletBackPanel().frame(width: max(0, geometry.size.width - 40), height: walletHeight + 12)
            .accessibilityRepresentation { EmptyView() }
    }
    private func liftedPaper(_ record: ReceiptRecord, geometry: GeometryProxy) -> some View {
        let current = workspace.selected?.id == record.id ? workspace.selected! : record
        return WalletReadingScene(record: current, input: workspace.readerInput, contentReady: workspace.readerRevisionID == current.current.id || workspace.errorMessage != nil, expanded: expanded, settled: readerSettled, origin: origin,
                           tilt: selectedTilt, reduceMotion: reduceMotion,
                           error: workspace.errorMessage,
                           loading: selectedID != nil && workspace.image == nil && workspace.errorMessage == nil,
                           visibleToAccessibility: selectedID != nil && workspace.flow != .review,
                           editLine: { workspace.openDetailLine($0) }) {
            guard selectedID == record.id, presented?.id == record.id, !expanded else { return }
            withAnimation(motion, completionCriteria: .removed) { expanded = true } completion: {
                if expanded && selectedID == record.id { readerSettled = true }
            }
        }.id(record.id)
    }
}

/// The full paper participates in native scroll layout. A scene-space copy handles
/// the wallet transition without making the scroll extent depend on animation geometry.
private struct WalletReadingScene: View {
    let record: ReceiptRecord
    let expanded: Bool
    let origin: CGRect
    let tilt: Double
    let reduceMotion: Bool
    let error: String?
    let loading: Bool
    let visibleToAccessibility: Bool
    let editLine: ((UUID) -> Void)?
    var onReady: () -> Void
    private let reviewInput: ReceiptReviewDraft?
    private let contentReady: Bool
    private let taxedMarkers: Set<String>
    @State private var retainedInput: ReceiptReviewDraft?
    @State private var fullHeight: CGFloat = 0
    let settled: Bool
    @State private var paperTop: CGFloat = 0
    @State private var canvasY: CGFloat = 0
    @State private var canvasMeasured = false
    @State private var returnCanvasY: CGFloat?
    init(record: ReceiptRecord, input: ReceiptReviewDraft?, contentReady: Bool, expanded: Bool, settled: Bool, origin: CGRect, tilt: Double,
         reduceMotion: Bool, error: String?, loading: Bool, visibleToAccessibility: Bool,
         editLine: ((UUID) -> Void)?, onReady: @escaping () -> Void) {
        self.record = record; self.expanded = expanded; self.settled = settled; self.origin = origin; self.tilt = tilt
        self.reduceMotion = reduceMotion; self.error = error; self.loading = loading
        self.visibleToAccessibility = visibleToAccessibility; self.onReady = onReady
        self.editLine = editLine
        reviewInput = input; self.contentReady = contentReady
        taxedMarkers = record.original.paperTaxedMarkers
    }
    private var ready: Bool { contentReady && fullHeight > 0 && paperTop > 0 && canvasMeasured }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            if !ReceiptCompletion.isComplete(record) { Label("Needs review", systemImage: "exclamationmark.circle") }
                            Spacer()
                            if record.isStarred { Image(systemName: "star.fill").accessibilityLabel("Starred") }
                        }.font(.footnote.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 34).padding(.top, 10)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { paperTop = $0 + 12 }
                            .opacity(expanded ? 1 : 0)
                        ReceiptPaper(fields: record.current.fields, input: reviewInput ?? retainedInput,
                                     reviewed: ReceiptCompletion.isComplete(record), taxedMarkers: taxedMarkers, editLine: editLine)
                            .fixedSize(horizontal: false, vertical: true)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { fullHeight = $0 }
                            .padding(.horizontal, 30).padding(.top, 12)
                            .opacity(settled ? 1 : 0)
                            .accessibilityHidden(!settled || !visibleToAccessibility)
                        VStack(alignment: .leading, spacing: 18) {
                            if loading { ProgressView("Loading original").font(.footnote) }
                            if let error { Text(error).font(.subheadline) }
                            if record.current.fields.currency == nil { Text("Currency needs confirmation. Edit to check the saved amounts.").font(.footnote) }
                        }.padding(.horizontal, 30).fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 22).opacity(expanded ? 1 : 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named("walletScene")).minY } action: {
                        canvasY = $0; canvasMeasured = true
                    }
                }
                .scrollClipDisabled().scrollEdgeEffectStyle(.soft, for: .vertical)
                .contentMargins(.bottom, 12, for: .scrollContent)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scrollDisabled(!settled)
                .allowsHitTesting(expanded)
                .accessibilityIdentifier("detailScreen")

                WalletMorphingPaper(reviewInput: reviewInput ?? retainedInput, record: record, taxedMarkers: taxedMarkers,
                                    settled: settled, progress: expanded ? 1 : 0,
                                    origin: origin,
                                    destination: CGRect(x: 30, y: paperTop + (expanded ? canvasY : returnCanvasY ?? canvasY),
                                                        width: max(0, geometry.size.width - 60), height: max(origin.height, fullHeight)),
                                    tilt: tilt, reduceMotion: reduceMotion)
                    .allowsHitTesting(false).accessibilityRepresentation { EmptyView() }
            }
            .onChange(of: reviewInput, initial: true) { _, value in
                if contentReady { retainedInput = value }
            }
            .onChange(of: ready, initial: true) { _, measured in
                if measured { onReady() }
            }
            .onChange(of: expanded) { _, reading in
                if !reading { returnCanvasY = canvasY }
            }
        }
    }
}

/// One animatable value drives the whole silhouette. Both content layouts are measured
/// at their final widths, rather than rebuilding receipt rows during every animation frame.
private struct WalletMorphingPaper: View, Animatable {
    let reviewInput: ReceiptReviewDraft?
    let record: ReceiptRecord
    let taxedMarkers: Set<String>
    let settled: Bool
    var progress: CGFloat
    let origin: CGRect
    let destination: CGRect
    let tilt: Double
    let reduceMotion: Bool
    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    private func blend(_ start: CGFloat, _ end: CGFloat) -> CGFloat { start + (end - start) * progress }
    var body: some View {
        if !settled { transitionPaper }
    }
    private var transitionPaper: some View {
        let start = reduceMotion ? destination : origin
        let width = max(0, blend(start.width, destination.width))
        let height = max(0, blend(start.height, destination.height))
        return ZStack(alignment: .topLeading) {
            WalletReadingContent(fields: record.current.fields, input: reviewInput, reviewed: ReceiptCompletion.isComplete(record), taxedMarkers: taxedMarkers).equatable()
                .frame(width: destination.width).fixedSize(horizontal: false, vertical: true)
                .scaleEffect(x: destination.width > 0 ? width / destination.width : 1, y: 1, anchor: .topLeading)
                .opacity(progress)
            ReceiptPreviewPaper(record: record).equatable()
                .frame(width: origin.width, height: origin.height, alignment: .topLeading)
                .scaleEffect(x: origin.width > 0 ? width / origin.width : 1, y: 1, anchor: .topLeading)
                .opacity(1 - progress).accessibilityHidden(true)
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .clipShape(ReceiptPaperEdge())
        .background { ReceiptPaperBackground() }
        .receiptPaperStyle()
        .rotationEffect(.degrees(reduceMotion ? 0 : tilt * Double(1 - progress)))
        .offset(x: blend(start.minX, destination.minX), y: blend(start.minY, destination.minY))
    }
}

/// Geometry-only updates do not reformat every purchase row. Environment-driven
/// changes still update the underlying native receipt view.
private struct WalletReadingContent: View, Equatable {
    let fields: ReceiptFields
    let input: ReceiptReviewDraft?
    let reviewed: Bool
    let taxedMarkers: Set<String>
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.fields == rhs.fields && lhs.input == rhs.input && lhs.reviewed == rhs.reviewed && lhs.taxedMarkers == rhs.taxedMarkers
    }
    var body: some View {
        ReceiptPaper(fields: fields, input: input, showsSurface: false, reviewed: reviewed, taxedMarkers: taxedMarkers)
    }
}

private struct WalletCrown: View {
    let count: Int
    var filtered = false
    var jumpToLatest: () -> Void
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Wallet").font(.system(.title2, design: .serif, weight: .semibold))
                    .shadow(color: .white.opacity(scheme == .dark ? 0.08 : 0.25), radius: 0, y: 1)
                    .accessibilityIdentifier("walletHeading")
                Text(filtered ? "\(count) matching" : "\(count) saved").font(.subheadline).lineLimit(1).minimumScaleFactor(0.6)
            }
            Spacer(minLength: 6)
            if count > 3 {
                Button(action: jumpToLatest) { Image(systemName: "arrow.down") }
                    .buttonStyle(ReceiptSecondaryStyle()).accessibilityLabel("Jump to newest receipt").accessibilityIdentifier("latestReceipt")
            } else {
                Image(systemName: "wallet.bifold").font(.title2.weight(.light)).opacity(0.75).accessibilityHidden(true)
            }
        }
        .foregroundStyle(scheme == .dark ? Color(red: 0.99, green: 0.92, blue: 0.83) : Color(red: 0.12, green: 0.06, blue: 0.03))
        .padding(.horizontal, 28).padding(.top, 26).padding(.bottom, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { LeatherWalletSurface() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("walletPocket")
        .accessibilityLabel(filtered ? "Wallet, \(count) matching receipts" : "Wallet, \(count) saved receipts")
    }
}

/// A shallow scooped mouth sits in front of the inserted papers, with a separate leather welt.
private struct WalletPocketFace: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height, corner: CGFloat = min(28, h / 3)
        var p = Path()
        p.move(to: CGPoint(x: 0, y: corner))
        p.addQuadCurve(to: CGPoint(x: corner, y: 8), control: CGPoint(x: 0, y: 8))
        p.addCurve(to: CGPoint(x: w - corner, y: 8), control1: CGPoint(x: w * 0.3, y: 18), control2: CGPoint(x: w * 0.7, y: 18))
        p.addQuadCurve(to: CGPoint(x: w, y: corner), control: CGPoint(x: w, y: 8))
        p.addLine(to: CGPoint(x: w, y: h - corner))
        p.addQuadCurve(to: CGPoint(x: w - corner, y: h), control: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: corner, y: h))
        p.addQuadCurve(to: CGPoint(x: 0, y: h - corner), control: CGPoint(x: 0, y: h))
        p.closeSubpath(); return p
    }
}

private struct WalletStitch: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 9, y: 32)); p.addLine(to: CGPoint(x: 9, y: r.height - 28))
        p.addQuadCurve(to: CGPoint(x: 28, y: r.height - 9), control: CGPoint(x: 9, y: r.height - 9))
        p.addLine(to: CGPoint(x: r.width - 28, y: r.height - 9))
        p.addQuadCurve(to: CGPoint(x: r.width - 9, y: r.height - 28), control: CGPoint(x: r.width - 9, y: r.height - 9))
        p.addLine(to: CGPoint(x: r.width - 9, y: 32)); return p
    }
}

private struct LeatherWalletSurface: View {
    @Environment(\.colorScheme) private var scheme
    private var dark: Bool { scheme == .dark }
    var body: some View {
        ZStack {
            // Only the front welt and face belong here. The back is a scene sibling below all papers.
            WalletPocketFace().fill(LinearGradient(colors: dark ? [Color(red: 0.49, green: 0.32, blue: 0.21), Color(red: 0.25, green: 0.14, blue: 0.08)] : [Color(red: 0.81, green: 0.62, blue: 0.43), Color(red: 0.49, green: 0.28, blue: 0.16)], startPoint: .top, endPoint: .bottom))
                .overlay { WalletPocketFace().stroke(.white.opacity(0.16), lineWidth: 1) }
            WalletPocketFace().fill(Color(red: 0.18, green: 0.09, blue: 0.05)).padding(.horizontal, 6).padding(.top, 1).padding(.bottom, 6)
            WalletPocketFace()
                .fill(LinearGradient(colors: dark ? [Color(red: 0.48, green: 0.31, blue: 0.20), Color(red: 0.34, green: 0.19, blue: 0.11)] : [Color(red: 0.78, green: 0.57, blue: 0.39), Color(red: 0.67, green: 0.43, blue: 0.27)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    Canvas { context, size in
                        // Fixed, sparse grain: no image assets, randomness or moving texture.
                        for row in 0..<Int(size.height / 3) {
                            for column in 0..<Int(size.width / 3) {
                                let seed = (row * 37 + column * 17) % 19
                                let rect = CGRect(x: CGFloat(column * 3) + CGFloat(seed % 3) * 0.3,
                                                  y: CGFloat(row * 3), width: 0.7, height: 0.9)
                                context.fill(Path(ellipseIn: rect), with: .color(seed % 2 == 0 ? .white.opacity(0.08) : .black.opacity(0.07)))
                            }
                        }
                    }.clipShape(WalletPocketFace())
                }
                .overlay { WalletPocketFace().stroke(.black.opacity(0.22), lineWidth: 1) }
                .overlay { WalletPocketFace().stroke(.white.opacity(0.14), lineWidth: 0.7).padding(1) }
                .overlay {
                    WalletStitch().stroke(.black.opacity(0.22), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [2, 5]))
                    WalletStitch().stroke(Color(red: 0.94, green: 0.76, blue: 0.55).opacity(dark ? 0.38 : 0.65), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 5]))
                        .offset(y: -0.5)
                }
                .padding(.horizontal, 4).padding(.bottom, 4)
        }
        .compositingGroup()
        // Contact shadow belongs to the leather mouth, so exposed paper never fades away.
        .shadow(color: .black.opacity(dark ? 0.4 : 0.24), radius: 7, y: -5)
        .shadow(color: .black.opacity(dark ? 0.4 : 0.2), radius: 14, y: 8)
        .shadow(color: .black.opacity(0.18), radius: 2, y: 2)
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}

private struct WalletBackPanel: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        RoundedRectangle(cornerRadius: 28)
            .fill(LinearGradient(colors: scheme == .dark ? [Color(red: 0.35, green: 0.21, blue: 0.13), Color(red: 0.25, green: 0.14, blue: 0.08)] : [Color(red: 0.62, green: 0.40, blue: 0.25), Color(red: 0.49, green: 0.28, blue: 0.16)], startPoint: .top, endPoint: .bottom))
            .overlay { RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.2), lineWidth: 0.8) }
            .overlay { RoundedRectangle(cornerRadius: 24).stroke(.black.opacity(0.22), lineWidth: 1).padding(4) }
    }
}

private struct ReceiptPaperAppearanceKey: EnvironmentKey {
    static let defaultValue: ReceiptPaperAppearance = .matchAppearance
}
extension EnvironmentValues {
    var receiptPaperAppearance: ReceiptPaperAppearance {
        get { self[ReceiptPaperAppearanceKey.self] }
        set { self[ReceiptPaperAppearanceKey.self] = newValue }
    }
}
private struct ReceiptPaperStyle: ViewModifier {
    @Environment(\.receiptPaperAppearance) private var appearance
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content.environment(\.colorScheme, appearance == .alwaysWhite ? .light : scheme)
    }
}
private struct ReceiptPaperSecondaryInk: ViewModifier {
    let enabled: Bool
    @Environment(\.colorSchemeContrast) private var systemContrast

    func body(content: Content) -> some View {
        let opacity = ReceiptAccessibility.contrast(systemContrast) == .increased ? 0.86 : 0.70
        content.foregroundStyle(.primary.opacity(enabled ? opacity : 1))
    }
}

extension View {
    func receiptPaperStyle() -> some View { modifier(ReceiptPaperStyle()) }
    func receiptPaperSecondaryInk(_ enabled: Bool = true) -> some View {
        modifier(ReceiptPaperSecondaryInk(enabled: enabled))
    }
}

/// Opaque receipt paper with a modest torn edge; long item text fades inside the preview.
struct ReceiptPaperEdge: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let radius: CGFloat = 12
        p.move(to: CGPoint(x: 0, y: radius))
        p.addQuadCurve(to: CGPoint(x: radius, y: 0), control: .zero)
        p.addLine(to: CGPoint(x: rect.maxX - radius, y: 0))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: radius), control: CGPoint(x: rect.maxX, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 4))
        let steps = max(1, Int(rect.width / 12))
        for step in stride(from: steps, through: 0, by: -1) {
            p.addLine(to: CGPoint(x: rect.width * CGFloat(step) / CGFloat(steps), y: rect.maxY - (step % 2 == 0 ? 4 : 0)))
        }
        p.closeSubpath(); return p
    }
}

struct ReceiptPaperBackground: View {
    var walletPreview = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var systemContrast
    private var contrast: ColorSchemeContrast { ReceiptAccessibility.contrast(systemContrast) }
    var body: some View {
        ReceiptPaperEdge().fill(Color(uiColor: .secondarySystemGroupedBackground))
            .overlay { ReceiptPaperEdge().stroke(.primary.opacity(contrast == .increased ? 0.6 : 0.12), lineWidth: 0.5) }
            .compositingGroup()
            .shadow(color: .black.opacity(walletPreview ? (scheme == .dark ? 0.52 : 0.21) : (scheme == .dark ? 0.45 : 0.16)), radius: walletPreview ? 14 : 12, y: 6)
            .shadow(color: .black.opacity(scheme == .dark ? 0.3 : 0.12), radius: 2, y: 2)
    }
}

private struct ReceiptSwipePaper: View {
    let record: ReceiptRecord
    let identifier: String
    var open: () -> Void
    var perform: (ReceiptWalletAction) -> Void
    var onPresentationChanged: (Bool) -> Void

    var body: some View {
        Button(action: open) {
            ReceiptPreviewSurface(record: record)
                .contentShape(ReceiptPaperEdge())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(summary)
        .accessibilityHint("Opens receipt")
        .accessibilityIdentifier(identifier)
        .accessibilityAction(named: Text(record.isStarred ? "Unstar" : "Star")) { perform(.star) }
        .receiptSwipeActions(record, identifier: identifier, perform: perform,
                             onPresentationChanged: onPresentationChanged)
    }
    private var summary: String {
        [record.current.fields.merchant ?? "Merchant missing", ExactInput.dateText(record.current.fields.purchaseDate),
         record.current.fields.total.map { "\($0.currency.code) \(ExactInput.format($0.minorUnits, scale: $0.currency.minorUnitScale))" } ?? "Total missing",
         record.isStarred ? "Starred" : "", ReceiptCompletion.isComplete(record) ? "Finished" : "Needs review"].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

private struct ReceiptPreviewSurface: View {
    let record: ReceiptRecord
    var body: some View {
        ReceiptPreviewPaper(record: record).equatable()
            .frame(maxHeight: .infinity, alignment: .top)
            .background { ReceiptPaperBackground(walletPreview: true) }
            .receiptPaperStyle()
    }
}

struct ReceiptPreviewPaper: View, Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.record.id == rhs.record.id && lhs.record.current.id == rhs.record.current.id
            && lhs.record.organization == rhs.record.organization
    }
    let record: ReceiptRecord
    @Environment(\.dynamicTypeSize) private var typeSize
    private var fields: ReceiptFields { record.current.fields }
    private var long: Bool { fields.items.count > 2 || fields.items.contains { ($0.description?.count ?? 0) > 40 } }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(fields.merchant ?? "Merchant missing").font(.headline).lineLimit(typeSize.isAccessibilitySize ? 3 : 2)
                Spacer(minLength: 8)
                if record.isStarred { Image(systemName: "star.fill").font(.caption) }
                if ReceiptCompletion.isComplete(record) { ReceiptReviewedMark() }
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) { Text(ExactInput.dateText(fields.purchaseDate).nilIfEmpty ?? "Date missing").font(.footnote).receiptPaperSecondaryInk(); Spacer(); total }
                VStack(alignment: .leading, spacing: 6) { Text(ExactInput.dateText(fields.purchaseDate).nilIfEmpty ?? "Date missing").font(.footnote).receiptPaperSecondaryInk(); total }
            }
            if !ReceiptCompletion.isComplete(record) { Label("Needs review", systemImage: "exclamationmark.circle").font(.caption) }
            PaperRule().stroke(.primary.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(height: 1)
            if !typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 9) {
                ForEach(fields.items.prefix(long ? 6 : 3)) { item in
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.paperName).lineLimit(1)
                        Spacer(minLength: 10)
                        Text(item.amount.map { ExactInput.format($0.minorUnits, scale: $0.currency.minorUnitScale) } ?? "—").monospacedDigit()
                    }.font(.system(.footnote, design: .monospaced))
                }
                if fields.items.isEmpty { Text("Purchases need review").font(.footnote) }
            }
            .frame(maxHeight: typeSize.isAccessibilitySize ? nil : (long ? 126 : 68), alignment: .top)
            .clipped()
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            if !typeSize.isAccessibilitySize && !long { HStack {
                Text("\(fields.items.count) \(fields.items.count == 1 ? "item" : "items")")
                Spacer()
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }.font(.caption).receiptPaperSecondaryInk().padding(.bottom, 4) }
        }
        .fontDesign(.monospaced)
        .accessibilityRepresentation { EmptyView() }
        .foregroundStyle(.primary).padding(.horizontal, 22).padding(.top, 30).padding(.bottom, 14)
        .frame(height: typeSize.isAccessibilitySize ? nil : 244, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private var total: some View {
        Text(fields.total.map { "\($0.currency.code) \(ExactInput.format($0.minorUnits, scale: $0.currency.minorUnitScale))" } ?? "Total missing")
            .font(.subheadline.weight(.semibold)).monospacedDigit()
    }
}

struct PaperRule: Shape {
    func path(in rect: CGRect) -> Path { var p = Path(); p.move(to: .zero); p.addLine(to: CGPoint(x: rect.width, y: 0)); return p }
}

struct ReceiptWalletSettingsView: View {
    @Bindable var workspace: ReceiptWorkspace
    @State private var backupMode: ReceiptBackupMode?
    @State private var information = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Display") {
                    Picker("Receipt view", selection: Binding(get: { workspace.library }, set: { value in
                        if value != workspace.library {
                            workspace.endSearch(); workspace.switchReceiptView(); workspace.resetHomeToNewest()
                        }
                    })) {
                        Text("Wallet").tag(false)
                        Text("List").tag(true)
                    }.accessibilityIdentifier("receiptDisplayMode")
                    Picker("Receipt paper", selection: Binding(get: { workspace.walletSettings.paperAppearance }, set: { appearance in
                        var settings = workspace.walletSettings; settings.paperAppearance = appearance
                        workspace.setWalletSettings(settings)
                    })) {
                        ForEach(ReceiptPaperAppearance.allCases) { Text($0.title).tag($0) }
                    }.accessibilityIdentifier("paperAppearanceSetting")
                }
                Section("Recognition") {
                    NavigationLink {
                        ReceiptAISettingsView(connection: workspace.aiConnection, privacyCovered: workspace.privacyCovered)
                    } label: {
                        LabeledContent("AI recognition", value: workspace.aiConnection.settingsSummary)
                    }.accessibilityIdentifier("aiRecognitionSettings")
                }
                ReceiptAppLockSettings()
                ReceiptBackupSettingsSection(workspace: workspace, mode: $backupMode)
                Section("Receipt actions") {
                    LabeledContent("Swipe left", value: "Delete")
                    LabeledContent("Swipe right", value: "Archive")
                }
                Section("About") {
                    Button("Wallet information", systemImage: "info.circle") { information = true }
                        .accessibilityIdentifier("walletInformationSetting")
                }
                if let notice = workspace.notice { Section { Text(notice) } }
            }
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .disabled(workspace.saving && !workspace.backupBusy)
        }.tint(.primary)
            .sheet(isPresented: $information) { WalletInformationView() }
            .sheet(item: $backupMode, onDismiss: { workspace.cancelBackup() }) { mode in ReceiptBackupView(workspace: workspace, mode: mode) }
            .onChange(of: workspace.active) { _, active in if !active { backupMode = nil } }
    }
}

extension View {
    func receiptSwipeActions(_ record: ReceiptRecord, identifier: String,
                             perform: @escaping (ReceiptWalletAction) -> Void,
                             onPresentationChanged: @escaping (Bool) -> Void = { _ in }) -> some View {
        self
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button("Delete", systemImage: "trash") { perform(.delete) }
                    .tint(.red).accessibilityLabel("Delete").accessibilityIdentifier("swipeAction-\(identifier)")
            } onPresentationChanged: { onPresentationChanged($0) }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button(record.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox") { perform(.archive) }
                    .tint(.blue).accessibilityLabel(record.isArchived ? "Unarchive" : "Archive")
                    .accessibilityIdentifier("swipeAction-\(identifier)")
            } onPresentationChanged: { onPresentationChanged($0) }
    }
}

private struct EmptyWalletArtwork: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        RoundedRectangle(cornerRadius: 2).fill(.primary.opacity(0.23)).frame(width: 52, height: 5)
                        ForEach(0..<4) { index in
                            HStack {
                                RoundedRectangle(cornerRadius: 2).fill(.primary.opacity(0.12)).frame(width: index == 2 ? 52 : 72, height: 3)
                                Spacer()
                                RoundedRectangle(cornerRadius: 2).fill(.primary.opacity(0.12)).frame(width: 24, height: 3)
                            }
                        }
                    }.padding(20)
                }
                .overlay { RoundedRectangle(cornerRadius: 16).stroke(.primary.opacity(0.08), lineWidth: 0.5) }
                .frame(width: 164, height: 166).rotationEffect(.degrees(-6)).offset(x: -4, y: -18)
                .shadow(color: .black.opacity(scheme == .dark ? 0.4 : 0.1), radius: 16, x: 0, y: 9)
            RoundedRectangle(cornerRadius: 23)
                .fill(LinearGradient(colors: [Color(uiColor: .tertiarySystemGroupedBackground), Color(uiColor: .secondarySystemGroupedBackground)], startPoint: .top, endPoint: .bottom))
                .overlay { RoundedRectangle(cornerRadius: 23).stroke(.primary.opacity(0.12), lineWidth: 0.5) }
                .overlay(alignment: .top) { Capsule().fill(.primary.opacity(0.1)).frame(height: 1).padding(.horizontal, 18).padding(.top, 12) }
                .overlay { Image(systemName: "wallet.bifold").font(.system(size: 23, weight: .light)).foregroundStyle(.primary.opacity(0.55)) }
                .frame(width: 218, height: 87)
                .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.1), radius: 18, x: 0, y: 10)
        }.accessibilityHidden(true)
    }
}

private extension View {
    func walletScreenEdges(in geometry: GeometryProxy) -> some View {
        let top = geometry.safeAreaInsets.top
        let bottom = geometry.safeAreaInsets.bottom
        // Scroll beneath the system bars; preserve safe resting positions with content margins.
        // Use the same native soft edges as lists and receipt detail.
        return self
            .scrollClipDisabled()
            .scrollEdgeEffectStyle(.soft, for: .vertical)
            .contentMargins(.top, top, for: .scrollContent)
            .contentMargins(.bottom, bottom, for: .scrollContent)
            .frame(width: geometry.size.width, height: geometry.size.height + top + bottom)
            .offset(y: -top)
    }
}
