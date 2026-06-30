import Foundation

actor TorrentDetailDataService {
    let hash: String

    init(hash: String) {
        self.hash = hash
    }

    func fetchInitial() async throws -> (
        torrent: TorrentInfo,
        properties: TorrentProperties?,
        files: [TorrentFile],
        trackers: [TorrentTracker],
        peers: [TorrentPeer],
        peersRid: Int
    ) {
        async let tTask = QBitApi.shared.getTorrentByHash(hash)
        async let pTask = QBitApi.shared.getProperties(hash)
        async let fTask = QBitApi.shared.getTorrentFiles(hash)
        async let trTask = QBitApi.shared.getTorrentTrackers(hash)
        async let peTask = QBitApi.shared.getTorrentPeers(hash, rid: 0)

        let rawTorrent = try await tTask
        guard let torrent = rawTorrent else {
            throw NSError(domain: "TorrentDetail", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: OrbixStrings.errCantLoadTorrent])
        }
        let p = try? await pTask
        let f = (try? await fTask) ?? []
        let tr = (try? await trTask) ?? []
        let (pe, rid) = (try? await peTask) ?? ([], 0)

        return (torrent, p, f, tr, pe, rid)
    }

    func fetchHighFreq(syncRid: Int, peersRid: Int) async -> (
        torrent: TorrentInfo?,
        syncRid: Int,
        peers: [TorrentPeer],
        peersRid: Int
    ) {
        let sync = try? await QBitApi.shared.syncMainData(rid: syncRid)
        let (pe, rid) = (try? await QBitApi.shared.getTorrentPeers(hash, rid: peersRid)) ?? ([], peersRid)
        return (sync?.torrents?[hash], sync?.rid ?? syncRid, pe, rid)
    }

    func fetchLowFreq() async -> (
        files: [TorrentFile]?,
        trackers: [TorrentTracker]?
    ) {
        let f = try? await QBitApi.shared.getTorrentFiles(hash)
        let tr = try? await QBitApi.shared.getTorrentTrackers(hash)
        return (f, tr)
    }

    func fetchAll() async -> (
        torrent: TorrentInfo?,
        properties: TorrentProperties?,
        files: [TorrentFile],
        trackers: [TorrentTracker],
        peers: [TorrentPeer],
        peersRid: Int
    ) {
        let t = try? await QBitApi.shared.getTorrentByHash(hash)
        let p = try? await QBitApi.shared.getProperties(hash)
        let f = (try? await QBitApi.shared.getTorrentFiles(hash)) ?? []
        let tr = (try? await QBitApi.shared.getTorrentTrackers(hash)) ?? []
        let (pe, rid) = (try? await QBitApi.shared.getTorrentPeers(hash, rid: 0)) ?? ([], 0)
        return (t, p, f, tr, pe, rid)
    }

    func performAction(_ type: TorrentDetailAction) async throws {
        switch type {
        case .pause(let isPaused):
            if isPaused {
                try await QBitApi.shared.startTorrent(hash)
            } else {
                try await QBitApi.shared.stopTorrent(hash)
            }
        case .force: try await QBitApi.shared.forceStartTorrent(hash)
        case .recheck: try await QBitApi.shared.recheckTorrent(hash)
        case .announce: try await QBitApi.shared.reannounceTorrent(hash)
        }
    }

    func pollAfterAction(oldState: String, oldDlspeed: Int64, oldUpspeed: Int64, oldProgress: Double) async -> TorrentInfo? {
        var interval: UInt64 = Polling.initialBackoffNanos
        let maxInterval: UInt64 = Polling.maxBackoffNanos
        var attempt = 0

        while attempt < 6 {
            do {
                try await Task.sleep(nanoseconds: interval)
            } catch { break }
            attempt += 1

            if let newTorrent = try? await QBitApi.shared.getTorrentByHash(hash) {
                let stateChanged = newTorrent.state != oldState
                let speedChanged = abs(newTorrent.dlspeed - oldDlspeed) > 1024
                    || abs(newTorrent.upspeed - oldUpspeed) > 1024
                let progressChanged = abs(newTorrent.progress - oldProgress) > 0.001

                if stateChanged || speedChanged || progressChanged || attempt >= 6 {
                    return newTorrent
                }
            }
            interval = min(maxInterval, interval * 13 / 8)
        }
        return nil
    }

    func fetchDetailsAfterAction() async -> (
        properties: TorrentProperties?,
        files: [TorrentFile],
        trackers: [TorrentTracker],
        peers: [TorrentPeer],
        peersRid: Int
    ) {
        let p = try? await QBitApi.shared.getProperties(hash)
        let f = try? await QBitApi.shared.getTorrentFiles(hash)
        let tr = try? await QBitApi.shared.getTorrentTrackers(hash)
        let (pe, rid) = (try? await QBitApi.shared.getTorrentPeers(hash, rid: 0)) ?? ([], 0)
        return (p, f ?? [], tr ?? [], pe, rid)
    }
}

enum TorrentDetailAction {
    case pause(isPaused: Bool)
    case force
    case recheck
    case announce
}
