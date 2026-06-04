import SwiftUI

struct AddEditBlockView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TimeBlockStore

    var existingBlock: TimeBlock?

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date().addingTimeInterval(3600)
    @State private var showConflictAlert = false
    @State private var conflictMessage = ""

    private var isEditing: Bool { existingBlock != nil }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            formContent
            Divider()
            footerBar
        }
        .frame(width: 380)
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
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Form

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            titleField
            notesField
            timePickers
            conflictWarning
        }
        .padding(20)
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("任务名称").font(.caption).foregroundStyle(.secondary)
            TextField("例如：深度工作、代码审查", text: $title)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("备注 (可选)").font(.caption).foregroundStyle(.secondary)
            TextField("任务描述、目标、注意事项...", text: $notes)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var timePickers: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("开始时间").font(.caption).foregroundStyle(.secondary)
                DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .onChange(of: startTime) { _, newValue in
                        if newValue >= endTime {
                            endTime = newValue.addingTimeInterval(1800)
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("结束时间").font(.caption).foregroundStyle(.secondary)
                DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
        }
    }

    @ViewBuilder
    private var conflictWarning: some View {
        let conflicts = detectConflicts()
        if !conflicts.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text("与已有任务时间冲突")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
        }
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            if isEditing {
                Button("删除任务", role: .destructive) {
                    if let block = existingBlock {
                        store.delete(block)
                    }
                    dismiss()
                }
            }
            Spacer()
            Button("取消") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("保存") { save() }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
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
            id: existingBlock?.id ?? UUID(),
            title: title,
            startTime: startTime,
            endTime: endTime
        )
        return store.conflicts(for: tempBlock)
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        guard startTime < endTime else { return }

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
                id: existing.id, title: trimmedTitle,
                startTime: startTime, endTime: endTime,
                status: existing.status, notes: notes.trimmingCharacters(in: .whitespaces)
            )
            store.update(updated)
        } else {
            let newBlock = TimeBlock(
                title: trimmedTitle,
                startTime: startTime, endTime: endTime,
                notes: notes.trimmingCharacters(in: .whitespaces)
            )
            store.add(newBlock)
        }
        dismiss()
    }
}

#if DEBUG
#Preview {
    AddEditBlockView(store: TimeBlockStore())
}
#endif
