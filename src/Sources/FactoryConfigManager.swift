import Foundation

struct CustomModelEntry: Identifiable, Equatable {
    var id: String
    var model: String
    var index: Int
    var baseUrl: String
    var apiKey: String
    var displayName: String
    var maxOutputTokens: Int
    var noImageSupport: Bool
    var provider: String
    var extraFields: [String: Any]

    init?(from dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let model = dict["model"] as? String else {
            return nil
        }
        self.id = id
        self.model = model
        self.index = dict["index"] as? Int ?? 0
        self.baseUrl = dict["baseUrl"] as? String ?? ""
        self.apiKey = dict["apiKey"] as? String ?? ""
        self.displayName = dict["displayName"] as? String ?? model
        self.maxOutputTokens = dict["maxOutputTokens"] as? Int ?? 0
        self.noImageSupport = dict["noImageSupport"] as? Bool ?? false
        self.provider = dict["provider"] as? String ?? ""

        var extra = dict
        for key in ["id", "model", "index", "baseUrl", "apiKey", "displayName", "maxOutputTokens", "noImageSupport", "provider"] {
            extra.removeValue(forKey: key)
        }
        self.extraFields = extra
    }

    init(id: String, model: String, index: Int, baseUrl: String, apiKey: String,
         displayName: String, maxOutputTokens: Int, noImageSupport: Bool, provider: String) {
        self.id = id
        self.model = model
        self.index = index
        self.baseUrl = baseUrl
        self.apiKey = apiKey
        self.displayName = displayName
        self.maxOutputTokens = maxOutputTokens
        self.noImageSupport = noImageSupport
        self.provider = provider
        self.extraFields = [:]
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = extraFields
        dict["id"] = id
        dict["model"] = model
        dict["index"] = index
        dict["baseUrl"] = baseUrl
        dict["apiKey"] = apiKey
        dict["displayName"] = displayName
        dict["maxOutputTokens"] = maxOutputTokens
        dict["noImageSupport"] = noImageSupport
        dict["provider"] = provider
        return dict
    }

    static func empty() -> CustomModelEntry {
        CustomModelEntry(
            id: "",
            model: "",
            index: 0,
            baseUrl: "http://localhost:8317",
            apiKey: "dummy-not-used",
            displayName: "",
            maxOutputTokens: 128000,
            noImageSupport: false,
            provider: "anthropic"
        )
    }

    static func == (lhs: CustomModelEntry, rhs: CustomModelEntry) -> Bool {
        lhs.id == rhs.id
            && lhs.model == rhs.model
            && lhs.index == rhs.index
            && lhs.baseUrl == rhs.baseUrl
            && lhs.apiKey == rhs.apiKey
            && lhs.displayName == rhs.displayName
            && lhs.maxOutputTokens == rhs.maxOutputTokens
            && lhs.noImageSupport == rhs.noImageSupport
            && lhs.provider == rhs.provider
    }
}

class FactoryConfigManager: ObservableObject {
    @Published var customModels: [CustomModelEntry] = []
    @Published var loadError: String?

    private var fileMonitor: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var pendingReload: DispatchWorkItem?

    private func factorySettingsURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".factory")
            .appendingPathComponent("settings.json")
    }

    // MARK: - Load

    func loadModels() {
        let url = factorySettingsURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            DispatchQueue.main.async {
                self.customModels = []
                self.loadError = nil
            }
            NSLog("[FactoryConfigManager] No settings.json found at %@", url.path)
            return
        }

        do {
            let data = try Data(contentsOf: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async {
                    self.customModels = []
                    self.loadError = "Invalid JSON structure"
                }
                return
            }

            let rawModels = (json["customModels"] as? [[String: Any]]) ?? []
            let entries = rawModels.compactMap { CustomModelEntry(from: $0) }

            DispatchQueue.main.async {
                self.customModels = entries
                self.loadError = nil
            }
            NSLog("[FactoryConfigManager] Loaded %d custom models", entries.count)
        } catch {
            DispatchQueue.main.async {
                self.loadError = error.localizedDescription
            }
            NSLog("[FactoryConfigManager] Failed to load: %@", error.localizedDescription)
        }
    }

    // MARK: - Save

    func saveModels() {
        let url = factorySettingsURL()
        let factoryDir = url.deletingLastPathComponent()

        try? FileManager.default.createDirectory(at: factoryDir, withIntermediateDirectories: true)

        var settings: [String: Any] = [:]
        if let data = try? Data(contentsOf: url),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = existing
        }

        // Reindex all models sequentially
        var dicts: [[String: Any]] = []
        for (offset, entry) in customModels.enumerated() {
            var dict = entry.toDictionary()
            dict["index"] = offset
            dicts.append(dict)
        }

        settings["customModels"] = dicts

        do {
            var data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
            if var jsonString = String(data: data, encoding: .utf8) {
                jsonString = jsonString.replacingOccurrences(of: "\\/", with: "/")
                data = jsonString.data(using: .utf8) ?? data
            }
            try data.write(to: url, options: .atomic)
            NSLog("[FactoryConfigManager] Saved %d custom models", dicts.count)
        } catch {
            NSLog("[FactoryConfigManager] Failed to save: %@", error.localizedDescription)
        }
    }

    // MARK: - CRUD

    func addModel(_ entry: CustomModelEntry) {
        customModels.append(entry)
        saveModels()
    }

    func updateModel(_ entry: CustomModelEntry, originalId: String? = nil) {
        let searchId = originalId ?? entry.id
        guard let idx = customModels.firstIndex(where: { $0.id == searchId }) else {
            NSLog("[FactoryConfigManager] Model not found for update: %@", searchId)
            return
        }
        customModels[idx] = entry
        saveModels()
    }

    func deleteModel(id: String) {
        customModels.removeAll { $0.id == id }
        saveModels()
    }

    func modelExists(id: String, excluding: String? = nil) -> Bool {
        customModels.contains { $0.id == id && $0.id != excluding }
    }

    func isDroidProxyPlusModel(_ entry: CustomModelEntry) -> Bool {
        entry.id.hasPrefix("custom:droidproxyplus:") || entry.id.hasPrefix("custom:CC:")
    }

    // MARK: - File Monitoring

    func startMonitoring() {
        stopMonitoring()

        let url = factorySettingsURL()
        let dir = url.deletingLastPathComponent()

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let fd = open(dir.path, O_EVTONLY)
        guard fd >= 0 else {
            NSLog("[FactoryConfigManager] Failed to open directory for monitoring: %@", dir.path)
            return
        }
        fileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.main
        )

        source.setEventHandler { [weak self] in
            self?.pendingReload?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.loadModels()
            }
            self?.pendingReload = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
                self?.fileDescriptor = -1
            }
        }

        source.resume()
        fileMonitor = source
        NSLog("[FactoryConfigManager] Started monitoring %@", dir.path)
    }

    func stopMonitoring() {
        pendingReload?.cancel()
        pendingReload = nil
        fileMonitor?.cancel()
        fileMonitor = nil
    }

    deinit {
        stopMonitoring()
    }
}
