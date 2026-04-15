import SwiftUI

struct CustomModelManagerView: View {
    @StateObject private var configManager = FactoryConfigManager()
    @State private var showingAddSheet = false
    @State private var editingModel: CustomModelEntry?
    @State private var modelToDelete: CustomModelEntry?
    @State private var showingDeleteConfirmation = false

    private let oledWindowBackground = Color.black
    private let oledSectionBackground = Color(red: 0x12/255, green: 0x12/255, blue: 0x12/255)
    private let oledFooterText = Color(red: 0xA8/255, green: 0xA8/255, blue: 0xA8/255)

    var body: some View {
        VStack(spacing: 0) {
            headerView
            modelListView
            footerView
        }
        .background(oledWindowBackground)
        .preferredColorScheme(.dark)
        .frame(minWidth: 580, maxWidth: 580, minHeight: 400, maxHeight: .infinity)
        .onAppear {
            configManager.loadModels()
            configManager.startMonitoring()
        }
        .onDisappear {
            configManager.stopMonitoring()
        }
        .sheet(isPresented: $showingAddSheet) {
            CustomModelFormView(mode: .add) { entry in
                configManager.addModel(entry)
            }
        }
        .sheet(item: $editingModel) { model in
            CustomModelFormView(mode: .edit(model)) { entry in
                configManager.updateModel(entry)
            }
        }
        .alert("Delete Model", isPresented: $showingDeleteConfirmation, presenting: modelToDelete) { model in
            Button("Delete", role: .destructive) {
                configManager.deleteModel(id: model.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: { model in
            Text("Remove \"\(model.displayName)\" from Factory custom models?")
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("Custom Models")
                .font(.title2.bold())
            Spacer()
            Text("\(configManager.customModels.count) models")
                .font(.caption)
                .foregroundColor(.secondary)
            Button {
                showingAddSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - List

    private var modelListView: some View {
        Group {
            if let error = configManager.loadError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if configManager.customModels.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No custom models configured")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("~/.factory/settings.json")
                        .font(.caption2)
                        .foregroundColor(oledFooterText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(configManager.customModels) { model in
                        CustomModelRowView(
                            model: model,
                            isDroidProxyPlus: configManager.isDroidProxyPlusModel(model),
                            onEdit: { editingModel = model },
                            onDelete: {
                                modelToDelete = model
                                showingDeleteConfirmation = true
                            }
                        )
                        .listRowBackground(oledSectionBackground)
                        .listRowSeparatorTint(Color.white.opacity(0.08))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Button {
                configManager.loadModels()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                    Text("Reload from Disk")
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            Spacer()

            Text("~/.factory/settings.json")
                .font(.caption2)
                .foregroundColor(oledFooterText)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

// MARK: - Row View

struct CustomModelRowView: View {
    let model: CustomModelEntry
    let isDroidProxyPlus: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var providerColor: Color {
        switch model.provider {
        case "anthropic":
            return Color(red: 0xD9/255, green: 0x77/255, blue: 0x57/255)
        case "openai":
            return Color(red: 0x74/255, green: 0xAA/255, blue: 0x9C/255)
        case "google":
            return Color(red: 0x42/255, green: 0x85/255, blue: 0xF4/255)
        default:
            return .gray
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Provider color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(providerColor)
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                // Top line: display name + badges
                HStack(spacing: 6) {
                    Text(model.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    if isDroidProxyPlus {
                        Text("DROID")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(providerColor.opacity(0.2))
                            .foregroundColor(providerColor)
                            .cornerRadius(3)
                    }

                    Text(model.provider)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.06))
                        .foregroundColor(.secondary)
                        .cornerRadius(3)
                }

                // Middle line: model identifier + tokens
                HStack(spacing: 8) {
                    Text(model.model)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)

                    if model.maxOutputTokens > 0 {
                        Text("\(formatTokens(model.maxOutputTokens)) tokens")
                            .font(.system(size: 10))
                            .foregroundColor(Color(red: 0xA8/255, green: 0xA8/255, blue: 0xA8/255))
                    }
                }

                // Bottom line: base URL
                Text(model.baseUrl)
                    .font(.system(size: 10))
                    .foregroundColor(Color.white.opacity(0.35))
                    .lineLimit(1)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 6)
        }
        .padding(.vertical, 6)
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1000 {
            return "\(count / 1000)K"
        }
        return "\(count)"
    }
}

// MARK: - Form View

struct CustomModelFormView: View {
    enum Mode: Identifiable {
        case add
        case edit(CustomModelEntry)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let entry): return entry.id
            }
        }
    }

    let mode: Mode
    let onSave: (CustomModelEntry) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String = ""
    @State private var model: String = ""
    @State private var entryId: String = ""
    @State private var provider: String = "anthropic"
    @State private var baseUrl: String = "http://localhost:8317"
    @State private var apiKey: String = "dummy-not-used"
    @State private var maxOutputTokens: String = "128000"
    @State private var noImageSupport: Bool = false
    @State private var extraFields: [String: Any] = [:]

    private var isValid: Bool {
        !model.trimmingCharacters(in: .whitespaces).isEmpty
            && !displayName.trimmingCharacters(in: .whitespaces).isEmpty
            && (Int(maxOutputTokens) ?? 0) > 0
    }

    private var title: String {
        switch mode {
        case .add: return "Add Custom Model"
        case .edit: return "Edit Custom Model"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text(title)
                .font(.headline)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Form {
                Section {
                    TextField("Display Name", text: $displayName)
                    TextField("Model", text: $model)
                        .onChange(of: model) { newValue in
                            if case .add = mode {
                                let slug = newValue
                                    .lowercased()
                                    .replacingOccurrences(of: " ", with: "-")
                                entryId = "custom:user:\(slug)"
                            }
                        }
                    TextField("ID", text: $entryId)
                        .font(.system(.body, design: .monospaced))
                }

                Section {
                    Picker("Provider", selection: $provider) {
                        Text("Anthropic").tag("anthropic")
                        Text("OpenAI").tag("openai")
                        Text("Google").tag("google")
                    }
                    .pickerStyle(.segmented)

                    TextField("Base URL", text: $baseUrl)
                        .font(.system(.body, design: .monospaced))
                    TextField("API Key", text: $apiKey)
                        .font(.system(.body, design: .monospaced))
                }

                Section {
                    TextField("Max Output Tokens", text: $maxOutputTokens)
                    Toggle("No Image Support", isOn: $noImageSupport)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            // Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 450, height: 420)
        .background(Color.black)
        .preferredColorScheme(.dark)
        .onAppear {
            populateFields()
        }
    }

    private func populateFields() {
        switch mode {
        case .add:
            break
        case .edit(let entry):
            displayName = entry.displayName
            model = entry.model
            entryId = entry.id
            provider = entry.provider
            baseUrl = entry.baseUrl
            apiKey = entry.apiKey
            maxOutputTokens = String(entry.maxOutputTokens)
            noImageSupport = entry.noImageSupport
            extraFields = entry.extraFields
        }
    }

    private func save() {
        let entry = CustomModelEntry(
            id: entryId.trimmingCharacters(in: .whitespaces),
            model: model.trimmingCharacters(in: .whitespaces),
            index: 0,
            baseUrl: baseUrl.trimmingCharacters(in: .whitespaces),
            apiKey: apiKey.trimmingCharacters(in: .whitespaces),
            displayName: displayName.trimmingCharacters(in: .whitespaces),
            maxOutputTokens: Int(maxOutputTokens) ?? 128000,
            noImageSupport: noImageSupport,
            provider: provider
        )
        onSave(entry)
        dismiss()
    }
}
