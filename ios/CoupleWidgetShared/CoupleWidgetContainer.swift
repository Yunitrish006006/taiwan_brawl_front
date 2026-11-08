import Foundation

enum CoupleWidgetContainer {
    private static func directory() throws -> URL {
        guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: CoupleWidgetStore.group) else {
            throw CoupleWidgetError.unavailable
        }
        return directory
    }
    static func store() throws -> CoupleWidgetStore {
        CoupleWidgetStore(file: try directory().appendingPathComponent("couple-widget-v1.json"))
    }
    static func appearance() throws -> String {
        try CoupleWidgetAppearance.read(from: directory().appendingPathComponent("couple-widget-appearance-v1.txt"))
    }
    static func setAppearance(_ id: String) throws {
        try CoupleWidgetAppearance.write(id, to: directory().appendingPathComponent("couple-widget-appearance-v1.txt"))
    }
}

enum CoupleWidgetAppearance {
    static let ids: Set<String> = ["rose", "lavender", "ocean", "mint", "sand", "midnight"]
    static func normalized(_ id: String?) -> String { id.flatMap { ids.contains($0) ? $0 : nil } ?? "rose" }
    static func colors(_ id: String?) -> [UInt32] {
        switch normalized(id) {
        case "lavender": return [0xF3EFFF, 0xE2D9FA, 0x44305F]
        case "ocean": return [0xECF6FF, 0xD6E9FA, 0x234B66]
        case "mint": return [0xEAF7F1, 0xD2EBDF, 0x254C3F]
        case "sand": return [0xFFF7EA, 0xF2E4C9, 0x654D2C]
        case "midnight": return [0x263049, 0x161D30, 0xF2E8F0]
        default: return [0xFFF0F4, 0xF9D9E3, 0x57263D]
        }
    }
    static func read(from file: URL) throws -> String {
        guard FileManager.default.fileExists(atPath: file.path) else { return "rose" }
        return normalized(try String(contentsOf: file, encoding: .utf8))
    }
    static func write(_ id: String, to file: URL) throws {
        guard ids.contains(id) else { throw CoupleWidgetError.invalid }
        try Data(id.utf8).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
