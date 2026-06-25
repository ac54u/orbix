import Foundation

struct TorrentInfo: Codable, Identifiable {
    var id: String { hash }
    let hash: String
    let name: String
    let state: String
    let progress: Double
    let dlspeed: Int64
    let upspeed: Int64
    let dlLimit: Int64
    let upLimit: Int64
    let eta: Int64
    let size: Int64
    let downloaded: Int64
    let uploaded: Int64
    let ratio: Double
    let numSeeds: Int
    let numLeechs: Int
    let category: String
    let tags: String
    let savePath: String
    let addedOn: Int64
    let completionOn: Int64
    let error: Int
    let errorString: String

    enum CodingKeys: String, CodingKey {
        case hash, name, state, progress, dlspeed, upspeed
        case dlLimit = "dl_limit"
        case upLimit = "up_limit"
        case eta, size, downloaded, uploaded, ratio
        case numSeeds = "num_seeds"
        case numLeechs = "num_leechs"
        case category, tags
        case savePath = "save_path"
        case addedOn = "added_on"
        case completionOn = "completion_on"
        case error
        case errorString = "error_string"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hash = try c.decode(String.self, forKey: .hash)
        name = try c.decode(String.self, forKey: .name)
        state = try c.decode(String.self, forKey: .state)
        progress = try c.decode(Double.self, forKey: .progress)
        dlspeed = try c.decode(Int64.self, forKey: .dlspeed)
        upspeed = try c.decode(Int64.self, forKey: .upspeed)
        dlLimit = try c.decode(Int64.self, forKey: .dlLimit)
        upLimit = try c.decode(Int64.self, forKey: .upLimit)
        eta = try c.decode(Int64.self, forKey: .eta)
        size = try c.decode(Int64.self, forKey: .size)
        downloaded = try c.decode(Int64.self, forKey: .downloaded)
        uploaded = try c.decode(Int64.self, forKey: .uploaded)
        ratio = try c.decode(Double.self, forKey: .ratio)
        numSeeds = try c.decode(Int.self, forKey: .numSeeds)
        numLeechs = try c.decode(Int.self, forKey: .numLeechs)
        category = try c.decode(String.self, forKey: .category)
        tags = try c.decode(String.self, forKey: .tags)
        savePath = try c.decode(String.self, forKey: .savePath)
        addedOn = try c.decode(Int64.self, forKey: .addedOn)
        completionOn = try c.decode(Int64.self, forKey: .completionOn)
        error = try c.decodeIfPresent(Int.self, forKey: .error) ?? 0
        errorString = try c.decodeIfPresent(String.self, forKey: .errorString) ?? ""
    }

    var statusBadge: TorrentStatus {
        TorrentStatus(rawValue: state) ?? .unknown
    }

    var isActive: Bool {
        statusBadge.isActive
    }

    var isCompleted: Bool {
        progress >= 1.0
    }

    var progressPercent: Int {
        Int(progress * 100)
    }

    var etaFormatted: String {
        guard eta > 0 else { return "∞" }
        let hours = eta / 3600
        let minutes = (eta % 3600) / 60
        let seconds = eta % 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m \(seconds)s" }
        return "\(seconds)s"
    }
}

enum TorrentStatus: String {
    case downloading = "downloading"
    case uploading = "uploading"
    case stalledDL = "stalledDL"
    case stalledUP = "stalledUP"
    case pausedDL = "pausedDL"
    case pausedUP = "pausedUP"
    case queuedDL = "queuedDL"
    case queuedUP = "queuedUP"
    case checkingDL = "checkingDL"
    case checkingUP = "checkingUP"
    case checkingResumeData = "checkingResumeData"
    case moving = "moving"
    case forcedUP = "forcedUP"
    case forcedDL = "forcedDL"
    case allocating = "allocating"
    case error = "error"
    case missingFiles = "missingFiles"
    case metaDL = "metaDL"
    case unknown

    var isActive: Bool {
        switch self {
        case .downloading, .uploading, .stalledDL, .stalledUP,
                .checkingDL, .checkingUP, .checkingResumeData,
                .moving, .metaDL, .forcedUP, .forcedDL, .allocating:
            true
        default:
            false
        }
    }

    var isPaused: Bool {
        self == .pausedDL || self == .pausedUP
    }

    var isError: Bool {
        self == .error || self == .missingFiles
    }

    var displayName: String {
        switch self {
        case .downloading: "Downloading"
        case .uploading: "Seeding"
        case .stalledDL: "Stalled (DL)"
        case .stalledUP: "Stalled (UP)"
        case .pausedDL: "Paused"
        case .pausedUP: "Completed"
        case .queuedDL: "Queued (DL)"
        case .queuedUP: "Queued (UP)"
        case .checkingDL, .checkingUP, .checkingResumeData: "Checking"
        case .moving: "Moving"
        case .forcedUP: "Forced (UP)"
        case .forcedDL: "Forced (DL)"
        case .allocating: "Allocating"
        case .error: "Error"
        case .missingFiles: "Missing Files"
        case .metaDL: "Fetching Metadata"
        case .unknown: "Unknown"
        }
    }
}

struct TransferInfo: Codable {
    let dlInfoSpeed: Int64
    let upInfoSpeed: Int64
    let dlRateLimit: Int64
    let upRateLimit: Int64
    let dlInfoData: Int64
    let upInfoData: Int64
    let serverState: ServerState?

    enum CodingKeys: String, CodingKey {
        case dlInfoSpeed = "dl_info_speed"
        case upInfoSpeed = "up_info_speed"
        case dlRateLimit = "dl_rate_limit"
        case upRateLimit = "up_rate_limit"
        case dlInfoData = "dl_info_data"
        case upInfoData = "up_info_data"
        case serverState = "server_state"
    }
}

struct ServerState: Codable {
    let alltimeDl: Int64
    let alltimeUl: Int64
    let globalRatio: String?
    let totalWastedSession: Int64
    let dhtNodes: Int
    let connectionStatus: String
    let useAltSpeedLimits: Bool
    let freeSpaceOnDisk: Int64
    let queueing: Bool
    let refreshInterval: Int

    enum CodingKeys: String, CodingKey {
        case alltimeDl = "alltime_dl"
        case alltimeUl = "alltime_ul"
        case globalRatio = "global_ratio"
        case totalWastedSession = "total_wasted_session"
        case dhtNodes = "dht_nodes"
        case connectionStatus = "connection_status"
        case useAltSpeedLimits = "use_alt_speed_limits"
        case freeSpaceOnDisk = "free_space_on_disk"
        case queueing, refreshInterval = "refresh_interval"
    }
}

struct TorrentProperties: Codable {
    let totalSize: Int64
    let totalDownloaded: Int64
    let totalUploaded: Int64
    let dlSpeed: Int64
    let upSpeed: Int64
    let seeds: Int
    let peers: Int
    let eta: Int64
    let savePath: String
    let category: String
    let tags: String
    let addedOn: Int64
    let completionOn: Int64
    let hash: String

    enum CodingKeys: String, CodingKey {
        case totalSize = "total_size"
        case totalDownloaded = "total_downloaded"
        case totalUploaded = "total_uploaded"
        case dlSpeed = "dl_speed"
        case upSpeed = "up_speed"
        case seeds, peers, eta
        case savePath = "save_path"
        case category, tags
        case addedOn = "added_on"
        case completionOn = "completion_on"
        case hash
    }
}

struct TorrentFile: Codable, Identifiable {
    var id: Int { index }
    let index: Int
    let name: String
    let size: Int64
    let progress: Double
    let priority: Int
    let isSeed: Bool

    enum CodingKeys: String, CodingKey {
        case index, name, size, progress, priority
        case isSeed = "is_seed"
    }

    var progressPercent: Int { Int(progress * 100) }
}

struct SyncMainData: Codable {
    let torrents: [String: TorrentInfo]?
    let serverState: ServerState?
    let rid: Int?

    enum CodingKeys: String, CodingKey {
        case torrents, serverState = "server_state", rid = "rid"
    }
}

struct Category: Codable, Identifiable {
    var id: String { name }
    let name: String
    let savePath: String

    enum CodingKeys: String, CodingKey {
        case name, savePath = "savePath"
    }
}

struct SearchPlugin: Codable, Identifiable {
    var id: String { name }
    let name: String
    let version: String
    let enabled: Bool

    enum CodingKeys: String, CodingKey {
        case name, version, enabled
    }
}

struct SearchResult: Codable {
    let num: Int
    let descr: String
    let fileName: String
    let fileSize: Int
    let nbLeechers: Int
    let nbSeeders: Int
    let siteUrl: String

    enum CodingKeys: String, CodingKey {
        case num, descr
        case fileName = "fileName"
        case fileSize = "fileSize"
        case nbLeechers = "nbLeechers"
        case nbSeeders = "nbSeeders"
        case siteUrl = "siteUrl"
    }
}
