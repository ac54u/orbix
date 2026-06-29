import SwiftUI

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

#if DEBUG
    init(hash: String = "demo", name: String, state: String = "downloading", progress: Double = 0,
         dlspeed: Int64 = 0, upspeed: Int64 = 0, dlLimit: Int64 = 0, upLimit: Int64 = 0,
         eta: Int64 = 0, size: Int64 = 0, downloaded: Int64 = 0, uploaded: Int64 = 0,
         ratio: Double = 0, numSeeds: Int = 0, numLeechs: Int = 0,
         category: String = "", tags: String = "", savePath: String = "",
         addedOn: Int64 = 0, completionOn: Int64 = 0,
         error: Int = 0, errorString: String = "") {
        self.hash = hash; self.name = name; self.state = state
        self.progress = progress; self.dlspeed = dlspeed; self.upspeed = upspeed
        self.dlLimit = dlLimit; self.upLimit = upLimit; self.eta = eta
        self.size = size; self.downloaded = downloaded; self.uploaded = uploaded
        self.ratio = ratio; self.numSeeds = numSeeds; self.numLeechs = numLeechs
        self.category = category; self.tags = tags; self.savePath = savePath
        self.addedOn = addedOn; self.completionOn = completionOn
        self.error = error; self.errorString = errorString
    }

    static func demo(name: String = "Ubuntu 24.04 LTS (Noble Numbat) Desktop ISO x64",
                     state: String = "downloading", progress: Double = 0.65,
                     dlspeed: Int64 = 10_240_000, upspeed: Int64 = 512_000,
                     size: Int64 = 5_876_543_210, downloaded: Int64 = 3_800_000_000,
                     uploaded: Int64 = 200_000_000, ratio: Double = 0.05,
                     numSeeds: Int = 142, numLeechs: Int = 38) -> TorrentInfo {
        TorrentInfo(name: name, state: state, progress: progress,
                    dlspeed: dlspeed, upspeed: upspeed,
                    size: size, downloaded: downloaded, uploaded: uploaded,
                    ratio: ratio, numSeeds: numSeeds, numLeechs: numLeechs)
    }
#endif

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

    var progressColor: Color {
        if statusBadge.isError { return AppColors.danger }
        if isCompleted { return AppColors.success }
        return AppColors.accent
    }
}

enum TorrentStatus: String {
    case downloading = "downloading"
    case uploading = "uploading"
    case stalledDL = "stalledDL"
    case stalledUP = "stalledUP"
    case pausedDL = "pausedDL"
    case pausedUP = "pausedUP"
    case stoppedDL = "stoppedDL"
    case stoppedUP = "stoppedUP"
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
        self == .pausedDL || self == .pausedUP || self == .stoppedDL || self == .stoppedUP
    }

    var isError: Bool {
        self == .error || self == .missingFiles
    }

    var isDownloadRelated: Bool {
        switch self {
        case .downloading, .metaDL, .forcedDL, .stalledDL,
                .pausedDL, .stoppedDL, .queuedDL, .checkingDL,
                .checkingResumeData, .allocating:
            true
        default: false
        }
    }

    var isUploadRelated: Bool {
        switch self {
        case .uploading, .forcedUP, .stalledUP,
                .pausedUP, .stoppedUP, .queuedUP, .checkingUP:
            true
        default: false
        }
    }

    var statusColor: Color {
        switch self {
        case .uploading, .stalledUP, .forcedUP: return AppColors.success
        case .downloading, .metaDL, .forcedDL, .stalledDL: return AppColors.accent
        case .error, .missingFiles: return AppColors.danger
        case .pausedDL, .pausedUP, .stoppedDL, .stoppedUP, .queuedDL, .queuedUP, .moving: return AppColors.secondaryLabel
        default: return AppColors.secondaryLabel
        }
    }

    var displayName: String {
        switch self {
        case .downloading: OrbixStrings.statsDownloading
        case .uploading: OrbixStrings.statsSeeding
        case .stalledDL: String(localized: "等待下载", comment: "Waiting to download")
        case .stalledUP: String(localized: "做种中 (等待)", comment: "Seeding (waiting)")
        case .pausedDL, .stoppedDL: OrbixStrings.statsPaused
        case .pausedUP, .stoppedUP: String(localized: "已完成", comment: "Completed")
        case .queuedDL: String(localized: "排队下载", comment: "Queued download")
        case .queuedUP: String(localized: "排队做种", comment: "Queued upload")
        case .checkingDL, .checkingUP, .checkingResumeData: String(localized: "校验中", comment: "Checking")
        case .moving: String(localized: "移动中", comment: "Moving")
        case .forcedUP: String(localized: "强制做种", comment: "Forced upload")
        case .forcedDL: String(localized: "强制下载", comment: "Forced download")
        case .allocating: String(localized: "分配空间", comment: "Allocating space")
        case .error: OrbixStrings.statsError
        case .missingFiles: String(localized: "文件丢失", comment: "Missing files")
        case .metaDL: String(localized: "获取元数据", comment: "Fetching metadata")
        case .unknown: String(localized: "未知", comment: "Unknown")
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
        case category, tags, hash
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalSize = try c.decode(Int64.self, forKey: .totalSize)
        totalDownloaded = try c.decode(Int64.self, forKey: .totalDownloaded)
        totalUploaded = try c.decode(Int64.self, forKey: .totalUploaded)
        dlSpeed = try c.decode(Int64.self, forKey: .dlSpeed)
        upSpeed = try c.decode(Int64.self, forKey: .upSpeed)
        seeds = try c.decode(Int.self, forKey: .seeds)
        peers = try c.decode(Int.self, forKey: .peers)
        eta = try c.decode(Int64.self, forKey: .eta)
        savePath = try c.decode(String.self, forKey: .savePath)
        category = try c.decode(String.self, forKey: .category)
        tags = try c.decode(String.self, forKey: .tags)
        hash = try c.decode(String.self, forKey: .hash)

        let raw = try decoder.container(keyedBy: RawKeys.self)
        addedOn = (try? raw.decode(Int64.self, forKey: .added)) ?? -1
        completionOn = (try? raw.decode(Int64.self, forKey: .completed)) ?? -1
    }

    enum RawKeys: String, CodingKey {
        case added = "added_on"
        case completed = "completion_on"
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

struct TorrentTracker: Codable, Identifiable {
    var id: String { url }
    let url: String
    let status: Int
    let tier: Int
    let numPeers: Int
    let numSeeds: Int
    let numLeeches: Int
    let numDownloaded: Int
    let msg: String

    enum CodingKeys: String, CodingKey {
        case url, status, tier
        case numPeers = "num_peers"
        case numSeeds = "num_seeds"
        case numLeeches = "num_leeches"
        case numDownloaded = "num_downloaded"
        case msg
    }

    var statusText: String {
        switch status {
        case 0: return String(localized: "已禁用", comment: "Disabled")
        case 1: return String(localized: "未联系", comment: "Not contacted")
        case 2: return String(localized: "工作中", comment: "Working")
        case 3: return String(localized: "更新中", comment: "Updating")
        case 4: return String(localized: "工作中", comment: "Working")
        default: return msg.isEmpty ? String(localized: "未知", comment: "Unknown") : msg
        }
    }

    var statusColor: Color {
        switch status {
        case 0, 1: return AppColors.danger
        case 2, 4: return AppColors.success
        case 3: return AppColors.warning
        default: return AppColors.secondaryLabel
        }
    }
}

struct TorrentPeer: Codable, Identifiable {
    var id: String { "\(ip):\(port)" }
    let ip: String
    let port: Int
    let country: String
    let countryCode: String
    let progress: Double
    let dlSpeed: Int64
    let upSpeed: Int64
    let connection: String
    let flags: String
    let client: String

    enum CodingKeys: String, CodingKey {
        case ip, port, country
        case countryCode = "country_code"
        case progress, connection, flags, client
        case dlSpeed = "dl_speed"
        case upSpeed = "up_speed"
    }

    var progressPercent: Int { Int(progress * 100) }
}

struct TorrentPeersResponse: Codable {
    let peers: [String: TorrentPeer]?
    let peersRemoved: [String]?
    let rid: Int?

    enum CodingKeys: String, CodingKey {
        case peers, rid
        case peersRemoved = "peers_removed"
    }
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

struct SearchResult: Codable, Identifiable {
    var id: Int { num }
    let num: Int
    let descr: String
    let fileName: String
    let fileSize: Int
    let nbLeechers: Int
    let nbSeeders: Int
    let siteUrl: String
    var isAdded: Bool = false

    enum CodingKeys: String, CodingKey {
        case num, descr
        case fileName = "fileName"
        case fileSize = "fileSize"
        case nbLeechers = "nbLeechers"
        case nbSeeders = "nbSeeders"
        case siteUrl = "siteUrl"
    }
}

#if DEBUG
extension SearchResult {
    static func demo(num: Int = 1, descr: String = "magnet:?xt=urn:btih:demo",
                     fileName: String = "Ubuntu 24.04 LTS (Noble Numbat) Desktop AMD64 iso",
                     fileSize: Int = 5_876_543_210,
                     nbSeeders: Int = 142, nbLeechers: Int = 38,
                     siteUrl: String = "https://ubuntu.com", isAdded: Bool = false) -> SearchResult {
        SearchResult(num: num, descr: descr, fileName: fileName, fileSize: fileSize,
                     nbLeechers: nbLeechers, nbSeeders: nbSeeders, siteUrl: siteUrl,
                     isAdded: isAdded)
    }
}
#endif
