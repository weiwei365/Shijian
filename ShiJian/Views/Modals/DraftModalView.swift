import SwiftUI

struct DraftModalView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("我的草稿")
                    .font(.headline)
                Spacer()
                Button(action: { vm.showDraftModal = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // List
            if vm.draftManager.drafts.isEmpty {
                VStack {
                    Spacer()
                    Text("暂无保存的草稿")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(vm.draftManager.drafts) { draft in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(draft.name)
                                    .font(.system(size: 13))
                                Text(draft.savedAt, style: .date)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(action: { vm.draftManager.delete(draft) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            vm.loadDraft(draft)
                            vm.showDraftModal = false
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .frame(width: 360, height: 360)
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(radius: 20)
    }
}
