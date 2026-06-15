import SwiftUI

struct ProfilesView: View {
    @StateObject private var profileManager = ProfileManager.shared
    @State private var showImportOptions = false
    @State private var showFilePicker = false
    @State private var showURLInput = false
    @State private var urlText = ""
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        List {
            if profileManager.profiles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("没有配置文件")
                        .font(.headline)
                    Text("点击右上角 + 导入 Clash 配置")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .listRowBackground(Color.clear)
            }

            ForEach(profileManager.profiles) { profile in
                ProfileRow(profile: profile)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        profileManager.activateProfile(profile)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            profileManager.deleteProfile(profile)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
            }
        }
        .navigationTitle("配置管理")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showURLInput = true }) {
                        Label("从 URL 导入", systemImage: "link")
                    }
                    Button(action: { showFilePicker = true }) {
                        Label("从文件导入", systemImage: "doc")
                    }
                    Button(action: {
                        do {
                            try profileManager.importFromPasteboard()
                        } catch {
                            alertMessage = error.localizedDescription
                            showAlert = true
                        }
                    }) {
                        Label("从剪贴板导入", systemImage: "clipboard")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showURLInput) {
            URLInputView(urlText: $urlText) {
                Task {
                    do {
                        try await profileManager.importFromURL(urlText)
                        urlText = ""
                    } catch {
                        alertMessage = error.localizedDescription
                        showAlert = true
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.yaml, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    do {
                        try profileManager.importFromFile(url: url)
                    } catch {
                        alertMessage = error.localizedDescription
                        showAlert = true
                    }
                }
            case .failure(let error):
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
}

// MARK: - Profile Row

struct ProfileRow: View {
    let profile: Profile

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(profile.isActive ? Color.green : Color(.systemGray4))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.headline)
                    .fontWeight(profile.isActive ? .semibold : .regular)

                if let sourceURL = profile.sourceURL {
                    Text(sourceURL)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let date = profile.lastUpdated {
                    Text("更新于 \(date, style: .date)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if profile.sourceURL != nil {
                Button(action: {
                    Task {
                        try? await ProfileManager.shared.importFromURL(profile.sourceURL!)
                    }
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.accentColor)
                }
            }

            if profile.isActive {
                Text("当前")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - URL Input View

struct URLInputView: View {
    @Binding var urlText: String
    @Environment(\.dismiss) var dismiss
    var onImport: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                TextField("输入配置文件 URL", text: $urlText)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)

                Button(action: {
                    onImport()
                    dismiss()
                }) {
                    Text("导入")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(urlText.isEmpty ? Color.gray.opacity(0.3) : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(urlText.isEmpty)

                Spacer()
            }
            .padding()
            .navigationTitle("URL 导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

// MARK: - UTType Extension

import UniformTypeIdentifiers

extension UTType {
    static var yaml: UTType {
        UTType(filenameExtension: "yaml") ?? UTType(filenameExtension: "yml") ?? .plainText
    }
}

#Preview {
    NavigationView {
        ProfilesView()
    }
}
