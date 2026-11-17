import SwiftUI

/// Native, directly accessible period navigation. Selecting a month scrolls; it never filters receipts out.
struct ReceiptWalletMonths: View {
    let sections: [ReceiptWalletLayout.Section]
    let selected: String?
    var jump: (ReceiptWalletLayout.Section) -> Void
    @State private var year: String
    private var years: [String] { Array(Set(sections.filter { $0.id != "undated" }.map { String($0.id.prefix(4)) })).sorted(by: >) }
    private var visible: [ReceiptWalletLayout.Section] {
        sections.reversed().filter { $0.id == "undated" || $0.id.hasPrefix(year) }
    }
    init(sections: [ReceiptWalletLayout.Section], selected: String?, jump: @escaping (ReceiptWalletLayout.Section) -> Void) {
        self.sections = sections; self.selected = selected; self.jump = jump
        let latest = sections.last { $0.id != "undated" }?.id ?? ""
        _year = State(initialValue: String((selected == "undated" ? latest : selected ?? latest).prefix(4)))
    }
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                    ForEach(visible.filter { $0.id != "undated" }) { section in
                        monthButton(section)
                    }
                }
                if let undated = sections.first(where: { $0.id == "undated" }) {
                    monthButton(undated).padding(.top, 12)
                }
            }.contentMargins(20).scrollEdgeEffectStyle(.soft, for: .vertical)
                .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Jump to month").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if years.count > 1 {
                        Picker("Year", selection: $year) {
                            ForEach(years, id: \.self) { Text($0).tag($0) }
                        }.pickerStyle(.menu).accessibilityIdentifier("walletYear")
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.presentationDetents(visible.count > 6 || typeSize.isAccessibilitySize ? [.large] : [.medium, .large]).presentationDragIndicator(.visible)
    }
    private func monthButton(_ section: ReceiptWalletLayout.Section) -> some View {
        Button {
            jump(section); dismiss()
        } label: {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(section.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(section.count) \(section.count == 1 ? "receipt" : "receipts")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if section.id == selected { Image(systemName: "checkmark").font(.caption).foregroundStyle(.secondary) }
            }.padding(14).frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
                .contentShape(.rect(cornerRadius: 18))
        }.buttonStyle(.plain).accessibilityIdentifier("walletMonth-" + section.id)
    }
}
