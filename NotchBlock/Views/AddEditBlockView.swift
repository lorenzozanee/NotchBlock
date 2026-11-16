import SwiftUI

struct AddEditBlockView: View {
    @Environment(\.dismiss) private var dismiss
    let store: TimeBlockStore

    var existingBlock: TimeBlock?

    @State private var draftID = UUID()
    @State private var title = ""
    @State private var notes = ""
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    @State private var showConflictAlert = false
    @State private var conflictMessage = ""

    private var isEditing: Bool { existingBlock != nil }
    private var isTimeRangeValid: Bool { startTime < endTime }
    private var isTitleValid: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            MinimalHairline()
            formContent
            MinimalHairline()
            footerBar
        }
        .frame(width: 380)
        .background {
            FrostedGlassBackground(
                material: .hudWindow,
                tint: BrandColors.canvasGlass
            )
            .ignoresSafeArea()
        }
        .tint(BrandColors.accentText)
        .onAppear(perform: populateExisting)
        .alert("时间冲突", isPresented: $showConflictAlert) {
            Button("返回修改", role: .cancel) {}
        } message: {
            Text(conflictMessage)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text(isEditing ? "编辑任务" : "新建任务")
                .font(.headline)
                .foregroundStyle(BrandColors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Form

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("任务名称")
                    .font(.caption)
                    .foregroundStyle(BrandColors.textSecondary)
                TextField("深度工作、代码审查...", text: $title)
                    .minimalInput()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("备注")
                    .font(.caption)
                    .foregroundStyle(BrandColors.textSecondary)
                TextField("可选", text: $notes)
                    .minimalInput()
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("开始")
                        .font(.caption)
                        .foregroundStyle(BrandColors.textSecondary)
                    DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .onChange(of: startTime) { _, newValue in
                            if newValue >= endTime {
                                endTime = newValue.addingTimeInterval(1800)
                            }
                        }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("结束")
                        .font(.caption)
                        .foregroundStyle(BrandColors.textSecondary)
                    DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
            }

            if !isTimeRangeValid {
                Label("结束时间需晚于开始时间", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(BrandColors.missed)
            } else if !detectConflicts().isEmpty {
                Label("与已有任务时间重叠", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(BrandColors.accentText)
            }
        }
        .padding(20)
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(spacing: 10) {
            if isEditing {
                Button("删除", role: .destructive) {
                    if let block = existingBlock {
                        store.delete(block)
                    }
                    dismiss()
                }
                .buttonStyle(MinimalSecondaryButtonStyle(horizontalPadding: 12, verticalPadding: 6, isDestructive: true))
            }

            Spacer()

            Button("取消") { dismiss() }
                .buttonStyle(MinimalSecondaryButtonStyle(horizontalPadding: 14, verticalPadding: 6))
                .keyboardShortcut(.cancelAction)

            Button("保存") { save() }
                .buttonStyle(MinimalPrimaryButtonStyle(horizontalPadding: 16, verticalPadding: 6))
                .keyboardShortcut(.defaultAction)
                .disabled(!isTitleValid || !isTimeRangeValid)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Logic

    private func populateExisting() {
        guard let block = existingBlock else { return }
        title = block.title
        notes = block.notes
        startTime = block.startTime
        endTime = block.endTime
    }

    private func detectConflicts() -> [TimeBlock] {
        let tempBlock = TimeBlock(
            id: existingBlock?.id ?? draftID,
            title: title,
            startTime: startTime,
            endTime: endTime
        )
        return store.conflicts(for: tempBlock)
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, startTime < endTime else { return }

        let conflicts = detectConflicts()
        if !conflicts.isEmpty {
            conflictMessage = conflicts.map {
                "• \($0.title) (\($0.startTime.timeString)-\($0.endTime.timeString))"
            }.joined(separator: "\n")
            showConflictAlert = true
            return
        }

        if let existing = existingBlock {
            let updated = TimeBlock(
                id: existing.id,
                title: trimmedTitle,
                startTime: startTime,
                endTime: endTime,
                status: existing.status,
                notes: trimmedNotes,
                isBreak: existing.isBreak
            )
            store.update(updated)
        } else {
            let newBlock = TimeBlock(
                title: trimmedTitle,
                startTime: startTime,
                endTime: endTime,
                notes: trimmedNotes
            )
            store.add(newBlock)
        }
        dismiss()
    }
}

#if DEBUG
#Preview {
    AddEditBlockView(store: TimeBlockStore(userDefaults: UserDefaults(suiteName: "preview.addedit") ?? .standard))
}
#endif
