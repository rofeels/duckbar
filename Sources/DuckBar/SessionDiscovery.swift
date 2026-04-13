import Foundation
import CommonCrypto
import Darwin

struct SessionDiscovery {
    private let claudeDir: URL
    private let sessionsDir: URL
    private let projectsDir: URL
    private let desktopAgentSessionsDir: URL
    private let fm = FileManager.default

    // All-time stats 캐시 (파일 mtime 기반 증분 처리)
    private static var cachedAllTimeTokens: Int = 0
    private static var cachedAllTimeCost: Double = 0.0
    private static var cachedFileMtimes: [String: Date] = [:]  // path → last modified

    init() {
        let home = fm.homeDirectoryForCurrentUser
        claudeDir = home.appendingPathComponent(".claude")
        sessionsDir = claudeDir.appendingPathComponent("sessions")
        projectsDir = claudeDir.appendingPathComponent("projects")
        desktopAgentSessionsDir = home
            .appendingPathComponent("Library/Application Support/Claude/local-agent-mode-sessions")
    }

    /// CLI projects + Desktop App agent mode의 모든 프로젝트 하위 디렉토리 반환
    private func allProjectSubDirs() -> [URL] {
        var dirs: [URL] = []

        // 1. CLI: ~/.claude/projects/{hash}/
        if let children = try? fm.contentsOfDirectory(
            at: projectsDir, includingPropertiesForKeys: nil
        ) {
            dirs.append(contentsOf: children)
        }

        // 2. Desktop App: local-agent-mode-sessions/.../.claude/projects/{hash}/
        if let topDirs = try? fm.contentsOfDirectory(
            at: desktopAgentSessionsDir, includingPropertiesForKeys: nil
        ) {
            for d1 in topDirs {
                guard let d2s = try? fm.contentsOfDirectory(at: d1, includingPropertiesForKeys: nil) else { continue }
                for d2 in d2s {
                    guard let locals = try? fm.contentsOfDirectory(at: d2, includingPropertiesForKeys: nil) else { continue }
                    for local in locals where local.lastPathComponent.hasPrefix("local_") {
                        let projDir = local.appendingPathComponent(".claude/projects")
                        if let projChildren = try? fm.contentsOfDirectory(
                            at: projDir, includingPropertiesForKeys: nil
                        ) {
                            dirs.append(contentsOf: projChildren)
                        }
                    }
                }
            }
        }

        return dirs
    }

    // MARK: - Session Discovery

    func discoverSessions() -> [ClaudeSession] {
        guard let files = try? fm.contentsOfDirectory(
            at: sessionsDir,
            includingPropertiesForKeys: nil
        ) else { return [] }

        let sessionStats = loadSessionStats()
        var sessions: [ClaudeSession] = []

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pid = json["pid"] as? Int,
                  let sessionId = json["sessionId"] as? String,
                  let cwd = json["cwd"] as? String,
                  let startedAtMs = json["startedAt"] as? Double
            else { continue }

            guard isProcessAlive(Int32(pid)) else {
                try? fm.removeItem(at: file)
                continue
            }

            let startedAt = Date(timeIntervalSince1970: startedAtMs / 1000)
            let source = classifySource(Int32(pid))
            let state = resolveState(cwd: cwd, pid: Int32(pid))

            let stats = sessionStats[sessionId]
            let toolCallCount = stats?["total_calls"] as? Int ?? 0
            let lastTool = stats?["last_tool"] as? String
            let updatedAt = stats?["updated_at"] as? Double
            let lastActivity = updatedAt.map { Date(timeIntervalSince1970: $0) } ?? startedAt

            var toolCounts: [String: Int] = [:]
            if let tc = stats?["tool_counts"] as? [String: Any] {
                for (k, v) in tc {
                    if let count = v as? Int { toolCounts[k] = count }
                }
            }

            let modelName = loadModelName(for: sessionId, cwd: cwd)

            sessions.append(ClaudeSession(
                id: sessionId,
                pid: Int32(pid),
                workingDirectory: cwd,
                startedAt: startedAt,
                state: state,
                source: source,
                lastActivity: lastActivity,
                toolCallCount: toolCallCount,
                lastTool: lastTool,
                toolCounts: toolCounts,
                modelName: modelName
            ))
        }

        return sessions.sorted { s1, s2 in
            if s1.state.priority != s2.state.priority {
                return s1.state.priority > s2.state.priority
            }
            return s1.lastActivity > s2.lastActivity
        }
    }

    // MARK: - All Time Stats (마일스톤용)

    private func loadAllTimeStats(_ stats: inout UsageStats) {
        // 증분 캐싱: 변경된 파일만 재파싱 (595MB 전체 파싱 방지)
        var deltaTokens = 0
        var deltaCost = 0.0

        for dir in allProjectSubDirs() {
            guard let files = try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { continue }

            for file in files where file.pathExtension == "jsonl" {
                let path = file.path
                let mtime = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate

                // mtime이 캐시와 같으면 스킵
                if let cached = SessionDiscovery.cachedFileMtimes[path],
                   let current = mtime, cached == current {
                    continue
                }

                // 변경된 파일만 파싱
                guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
                var fileTokens = 0
                var fileCost = 0.0

                for line in content.components(separatedBy: .newlines) {
                    guard !line.isEmpty,
                          let lineData = line.data(using: .utf8),
                          let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                          obj["type"] as? String == "assistant",
                          let message = obj["message"] as? [String: Any],
                          let usage = message["usage"] as? [String: Any]
                    else { continue }

                    let input = usage["input_tokens"] as? Int ?? 0
                    let output = usage["output_tokens"] as? Int ?? 0
                    let cacheCreate = usage["cache_creation_input_tokens"] as? Int ?? 0
                    let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0

                    fileTokens += input + output + cacheCreate + cacheRead
                    fileCost += (Double(input) * 15.0
                        + Double(output) * 75.0
                        + Double(cacheCreate) * 18.75
                        + Double(cacheRead) * 1.50) / 1_000_000.0
                }

                deltaTokens += fileTokens
                deltaCost += fileCost
                SessionDiscovery.cachedFileMtimes[path] = mtime
            }
        }

        SessionDiscovery.cachedAllTimeTokens += deltaTokens
        SessionDiscovery.cachedAllTimeCost += deltaCost
        stats.allTimeTokens = SessionDiscovery.cachedAllTimeTokens
        stats.allTimeCostUSD = SessionDiscovery.cachedAllTimeCost
    }

    // MARK: - Codex Usage

    func loadCodexUsageStats(into stats: inout UsageStats) {
        let home = fm.homeDirectoryForCurrentUser
        let codexBase = home.appendingPathComponent(".codex")

        let sessionDirs = [
            codexBase.appendingPathComponent("sessions"),
            codexBase.appendingPathComponent("archived_sessions")
        ]

        let now = Date()
        let fiveHoursAgo = now.addingTimeInterval(-5 * 3600)
        let oneWeekAgo = now.addingTimeInterval(-7 * 24 * 3600)

        for baseDir in sessionDirs {
            guard let yearDirs = try? fm.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: nil) else { continue }
            for yearDir in yearDirs {
                guard let monthDirs = try? fm.contentsOfDirectory(at: yearDir, includingPropertiesForKeys: nil) else { continue }
                for monthDir in monthDirs {
                    guard let dayDirs = try? fm.contentsOfDirectory(at: monthDir, includingPropertiesForKeys: nil) else { continue }
                    for dayDir in dayDirs {
                        guard let files = try? fm.contentsOfDirectory(
                            at: dayDir,
                            includingPropertiesForKeys: [.contentModificationDateKey]
                        ) else { continue }

                        for file in files where file.pathExtension == "jsonl" {
                            // 1주일 이내 수정된 파일만
                            if let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                               let modDate = attrs.contentModificationDate,
                               modDate < oneWeekAgo { continue }

                            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
                            parseCodexJSONL(content, fiveHoursAgo: fiveHoursAgo, oneWeekAgo: oneWeekAgo, into: &stats)
                        }
                    }
                }
            }
        }
    }

    private func parseCodexJSONL(_ content: String, fiveHoursAgo: Date, oneWeekAgo: Date, into stats: inout UsageStats) {
        var prevSnapshot: (Int, Int, Int, Int)? = nil  // 중복 스냅샷 방지

        for line in content.components(separatedBy: .newlines) {
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
            else { continue }

            guard obj["type"] as? String == "event_msg",
                  let payload = obj["payload"] as? [String: Any],
                  payload["type"] as? String == "token_count",
                  let info = payload["info"] as? [String: Any]
            else { continue }

            // last_token_usage 우선, 없으면 total_token_usage
            let usageDict = info["last_token_usage"] as? [String: Any]
                ?? info["total_token_usage"] as? [String: Any]
            guard let usage = usageDict else { continue }

            let input = usage["input_tokens"] as? Int ?? 0
            let output = usage["output_tokens"] as? Int ?? 0
            let cached = usage["cached_input_tokens"] as? Int ?? 0
            let total = usage["total_tokens"] as? Int ?? 0

            // 연속 동일 스냅샷 스킵
            let snapshot = (input, output, cached, total)
            if let prev = prevSnapshot, prev == snapshot { continue }
            prevSnapshot = snapshot

            guard let timestampStr = obj["timestamp"] as? String,
                  let timestamp = parseISO8601(timestampStr)
            else { continue }

            if timestamp >= fiveHoursAgo {
                stats.codexFiveHourTokens.inputTokens += input
                stats.codexFiveHourTokens.outputTokens += output
                stats.codexFiveHourTokens.cachedInputTokens += cached
                stats.codexFiveHourTokens.requestCount += 1
            }
            if timestamp >= oneWeekAgo {
                stats.codexOneWeekTokens.inputTokens += input
                stats.codexOneWeekTokens.outputTokens += output
                stats.codexOneWeekTokens.cachedInputTokens += cached
                stats.codexOneWeekTokens.requestCount += 1
            }
        }
    }

    // MARK: - Usage Stats (통합: 토큰 + API 리밋 + 컨텍스트)

    func loadUsageStats() -> UsageStats {
        var stats = UsageStats()

        // 1. JSONL에서 토큰 사용량 집계
        loadTokenUsageFromJSONL(&stats)

        // 2. OMC usage-cache.json에서 API 리밋 로드
        loadRateLimitsFromCache(&stats)

        // 3. 최신 JSONL에서 컨텍스트 정보 추출
        loadContextInfo(&stats)

        // 4. stats-cache.json에서 모델별 사용량 로드
        loadModelUsageFromStatsCache(&stats)

        // 5. Codex 사용량 로드
        loadCodexUsageStats(into: &stats)

        // 6. 전체 누적 집계 (마일스톤용)
        loadAllTimeStats(&stats)

        return stats
    }

    // MARK: - Model Name from JSONL (세션별)

    func loadModelName(for sessionId: String, cwd: String) -> String? {
        let projectHash = cwdToProjectHash(cwd)
        let projectDir = projectsDir.appendingPathComponent(projectHash)

        // 세션 ID가 포함된 JSONL 찾기
        guard let files = try? fm.contentsOfDirectory(
            at: projectDir,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return nil }

        // 세션 ID로 매칭되는 파일, 없으면 최신 파일
        let jsonlFiles = files.filter { $0.pathExtension == "jsonl" }
        let targetFile = jsonlFiles.first { $0.deletingPathExtension().lastPathComponent == sessionId }
            ?? jsonlFiles.compactMap { file -> (URL, Date)? in
                guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                      let date = attrs.contentModificationDate else { return nil }
                return (file, date)
            }.max(by: { $0.1 < $1.1 })?.0

        guard let file = targetFile,
              let handle = try? FileHandle(forReadingFrom: file)
        else { return nil }

        let fileSize = handle.seekToEndOfFile()
        let readSize: UInt64 = min(fileSize, 10_000)
        handle.seek(toFileOffset: fileSize - readSize)
        let tailData = handle.readDataToEndOfFile()
        handle.closeFile()

        guard let tailStr = String(data: tailData, encoding: .utf8) else { return nil }

        for line in tailStr.components(separatedBy: .newlines).reversed() {
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  obj["type"] as? String == "assistant",
                  let message = obj["message"] as? [String: Any],
                  let model = message["model"] as? String
            else { continue }
            return model
        }
        return nil
    }

    // MARK: - Model Usage from JSONL (1주일 기준)

    private func loadModelUsageFromStatsCache(_ stats: inout UsageStats) {
        let now = Date()
        let oneWeekAgo = now.addingTimeInterval(-7 * 24 * 3600)
        var seenRequests = Set<String>()
        var merged: [String: ModelUsage] = [:]

        for dir in allProjectSubDirs() {
            guard let files = try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { continue }

            for jsonlFile in files where jsonlFile.pathExtension == "jsonl" {
                if let attrs = try? jsonlFile.resourceValues(forKeys: [.contentModificationDateKey]),
                   let modDate = attrs.contentModificationDate,
                   modDate < oneWeekAgo { continue }

                guard let content = try? String(contentsOf: jsonlFile, encoding: .utf8) else { continue }

                for line in content.components(separatedBy: .newlines) {
                    guard !line.isEmpty,
                          let lineData = line.data(using: .utf8),
                          let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                          obj["type"] as? String == "assistant",
                          let message = obj["message"] as? [String: Any],
                          let model = message["model"] as? String,
                          !model.contains("synthetic"),
                          let usage = message["usage"] as? [String: Any],
                          let tsStr = obj["timestamp"] as? String,
                          let ts = parseISO8601(tsStr),
                          ts >= oneWeekAgo
                    else { continue }

                    if let reqId = obj["requestId"] as? String {
                        if seenRequests.contains(reqId) { continue }
                        seenRequests.insert(reqId)
                    }

                    let input = usage["input_tokens"] as? Int ?? 0
                    let output = usage["output_tokens"] as? Int ?? 0
                    let cacheCreate = usage["cache_creation_input_tokens"] as? Int ?? 0
                    let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0

                    var mu = merged[model] ?? ModelUsage(modelName: model)
                    mu.inputTokens += input
                    mu.outputTokens += output
                    mu.cacheCreationTokens += cacheCreate
                    mu.cacheReadTokens += cacheRead
                    merged[model] = mu
                }
            }
        }

        // 같은 shortName(Opus, Sonnet, Haiku) 변형 합산
        var byShortName: [String: ModelUsage] = [:]
        for (_, mu) in merged {
            let key = mu.shortName
            if var existing = byShortName[key] {
                existing.inputTokens += mu.inputTokens
                existing.outputTokens += mu.outputTokens
                existing.cacheCreationTokens += mu.cacheCreationTokens
                existing.cacheReadTokens += mu.cacheReadTokens
                byShortName[key] = existing
            } else {
                byShortName[key] = mu
            }
        }

        stats.modelUsages = byShortName.values.sorted { $0.totalTokens > $1.totalTokens }
    }

    // MARK: - Token Usage from JSONL

    private func loadTokenUsageFromJSONL(_ stats: inout UsageStats) {
        let now = Date()
        let fiveHoursAgo = now.addingTimeInterval(-5 * 3600)
        let oneWeekAgo = now.addingTimeInterval(-7 * 24 * 3600)
        let twentyFourHoursAgo = now.addingTimeInterval(-24 * 3600)

        var seenRequests = Set<String>()
        var hourlyBuckets: [Date: HourlyTokenData] = [:]
        var weeklyHourlyBuckets: [Date: HourlyTokenData] = [:]

        let calendar = Calendar.current

        for dir in allProjectSubDirs() {
            guard let files = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { continue }

            let jsonlFiles = files.filter { $0.pathExtension == "jsonl" }

            for jsonlFile in jsonlFiles {
                // 1주일 이내 수정된 파일만 파싱
                if let attrs = try? jsonlFile.resourceValues(forKeys: [.contentModificationDateKey]),
                   let modDate = attrs.contentModificationDate,
                   modDate < oneWeekAgo { continue }

                guard let content = try? String(contentsOf: jsonlFile, encoding: .utf8) else { continue }

                for line in content.components(separatedBy: .newlines) {
                    guard !line.isEmpty,
                          let lineData = line.data(using: .utf8),
                          let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                          obj["type"] as? String == "assistant",
                          let message = obj["message"] as? [String: Any],
                          let usage = message["usage"] as? [String: Any],
                          let timestampStr = obj["timestamp"] as? String
                    else { continue }

                    // 중복 requestId 제거
                    if let reqId = obj["requestId"] as? String {
                        if seenRequests.contains(reqId) { continue }
                        seenRequests.insert(reqId)
                    }

                    guard let timestamp = parseISO8601(timestampStr) else { continue }

                    let input = usage["input_tokens"] as? Int ?? 0
                    let output = usage["output_tokens"] as? Int ?? 0
                    let cacheCreate = usage["cache_creation_input_tokens"] as? Int ?? 0
                    let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0

                    // 5시간 윈도우
                    if timestamp >= fiveHoursAgo {
                        stats.fiveHourTokens.inputTokens += input
                        stats.fiveHourTokens.outputTokens += output
                        stats.fiveHourTokens.cacheCreationTokens += cacheCreate
                        stats.fiveHourTokens.cacheReadTokens += cacheRead
                        stats.fiveHourTokens.requestCount += 1
                    }

                    // 1주일 윈도우
                    if timestamp >= oneWeekAgo {
                        stats.oneWeekTokens.inputTokens += input
                        stats.oneWeekTokens.outputTokens += output
                        stats.oneWeekTokens.cacheCreationTokens += cacheCreate
                        stats.oneWeekTokens.cacheReadTokens += cacheRead
                        stats.oneWeekTokens.requestCount += 1
                    }

                    // 24시간 시간별 버킷 (라인차트용)
                    if timestamp >= twentyFourHoursAgo {
                        let hourStart = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: timestamp))!
                        var bucket = hourlyBuckets[hourStart] ?? HourlyTokenData(id: hourStart)
                        bucket.inputTokens += input
                        bucket.outputTokens += output
                        bucket.cacheCreationTokens += cacheCreate
                        bucket.cacheReadTokens += cacheRead
                        bucket.requestCount += 1
                        hourlyBuckets[hourStart] = bucket
                    }

                    // 7일 시간별 버킷 (히트맵용)
                    if timestamp >= oneWeekAgo {
                        let hourStart = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: timestamp))!
                        var bucket = weeklyHourlyBuckets[hourStart] ?? HourlyTokenData(id: hourStart)
                        bucket.inputTokens += input
                        bucket.outputTokens += output
                        bucket.cacheCreationTokens += cacheCreate
                        bucket.cacheReadTokens += cacheRead
                        bucket.requestCount += 1
                        weeklyHourlyBuckets[hourStart] = bucket
                    }
                }
            }
        }

        // 24시간 전체 시간대를 빈 버킷으로 채움
        var allHours: [HourlyTokenData] = []
        let startHour = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: twentyFourHoursAgo))!
        let currentHour = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: now))!
        var hour = startHour
        while hour <= currentHour {
            allHours.append(hourlyBuckets[hour] ?? HourlyTokenData(id: hour))
            hour = calendar.date(byAdding: .hour, value: 1, to: hour)!
        }
        stats.hourlyData = allHours

        // 7일 전체 시간대를 빈 버킷으로 채움 (히트맵용)
        var allWeeklyHours: [HourlyTokenData] = []
        let weekStartHour = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: oneWeekAgo))!
        var weekHour = weekStartHour
        while weekHour <= currentHour {
            allWeeklyHours.append(weeklyHourlyBuckets[weekHour] ?? HourlyTokenData(id: weekHour))
            weekHour = calendar.date(byAdding: .hour, value: 1, to: weekHour)!
        }
        stats.weeklyHourlyData = allWeeklyHours
    }

    // MARK: - Rate Limits from OMC Cache

    /// 로컬 캐시 경로
    private var rateLimitsCacheFile: URL {
        claudeDir.appendingPathComponent(".duckbar-ratelimits-cache.json")
    }

    /// API 재호출 최소 간격 (5분)
    private static let apiCooldown: TimeInterval = 300

    private func saveRateLimitsCache(_ data: [String: Any]) {
        var cached = data
        cached["_cachedAt"] = ISO8601DateFormatter().string(from: Date())
        if let json = try? JSONSerialization.data(withJSONObject: cached) {
            try? json.write(to: rateLimitsCacheFile)
        }
    }

    /// 로컬 캐시가 유효한지 (5분 이내)
    private func loadLocalCache() -> (data: [String: Any], fresh: Bool)? {
        guard let data = try? Data(contentsOf: rateLimitsCacheFile),
              let cacheData = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        var isFresh = false
        if let cachedAtStr = cacheData["_cachedAt"] as? String,
           let cachedAt = parseISO8601(cachedAtStr) {
            isFresh = Date().timeIntervalSince(cachedAt) < Self.apiCooldown
        }
        return (cacheData, isFresh)
    }

    private func applyRateLimitsData(_ cacheData: [String: Any], to stats: inout UsageStats) {
        stats.rateLimits.isLoaded = true
        stats.rateLimits.fiveHourPercent = (cacheData["fiveHourPercent"] as? Double)
            ?? Double(cacheData["fiveHourPercent"] as? Int ?? 0)
        stats.rateLimits.weeklyPercent = (cacheData["weeklyPercent"] as? Double)
            ?? Double(cacheData["weeklyPercent"] as? Int ?? 0)

        if let resetStr = cacheData["fiveHourResetsAt"] as? String {
            stats.rateLimits.fiveHourResetsAt = parseISO8601(resetStr)
        }
        if let resetStr = cacheData["weeklyResetsAt"] as? String {
            stats.rateLimits.weeklyResetsAt = parseISO8601(resetStr)
        }
        if let sonnet = cacheData["sonnetWeeklyPercent"] as? Double {
            stats.rateLimits.sonnetWeeklyPercent = sonnet
        } else if let sonnet = cacheData["sonnetWeeklyPercent"] as? Int {
            stats.rateLimits.sonnetWeeklyPercent = Double(sonnet)
        }
        if let resetStr = cacheData["sonnetWeeklyResetsAt"] as? String {
            stats.rateLimits.sonnetWeeklyResetsAt = parseISO8601(resetStr)
        }
        if let opus = cacheData["opusWeeklyPercent"] as? Double {
            stats.rateLimits.opusWeeklyPercent = opus
        } else if let opus = cacheData["opusWeeklyPercent"] as? Int {
            stats.rateLimits.opusWeeklyPercent = Double(opus)
        }
        if let resetStr = cacheData["opusWeeklyResetsAt"] as? String {
            stats.rateLimits.opusWeeklyResetsAt = parseISO8601(resetStr)
        }
        if let enabled = cacheData["extraUsageEnabled"] as? Bool {
            stats.rateLimits.extraUsageLoaded = true
            stats.rateLimits.extraUsageEnabled = enabled
        }
        if let used = cacheData["extraUsageUsed"] as? Double {
            stats.rateLimits.extraUsageUsed = used
        }
        if let limit = cacheData["extraUsageLimit"] as? Double {
            stats.rateLimits.extraUsageLimit = limit
        }
        if let util = cacheData["extraUsageUtilization"] as? Double {
            stats.rateLimits.extraUsageUtilization = util
        }
        if let resetStr = cacheData["extraUsageResetsAt"] as? String {
            stats.rateLimits.extraUsageResetsAt = parseISO8601(resetStr)
        }
    }

    private func loadRateLimitsFromCache(_ stats: inout UsageStats) {
        // 1. 로컬 캐시가 신선하면(5분 이내) 그대로 사용
        if let local = loadLocalCache(), local.fresh {
            applyRateLimitsData(local.data, to: &stats)
            // extra_usage 없으면 API 보완 호출
            if !stats.rateLimits.extraUsageLoaded {
                fetchRateLimitsFromAPI(&stats)
            }
            return
        }

        // 2. OMC 캐시 시도
        let omcFile = claudeDir
            .appendingPathComponent("plugins/oh-my-claudecode/.usage-cache.json")

        if let data = try? Data(contentsOf: omcFile),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let cacheData = json["data"] as? [String: Any] {
            applyRateLimitsData(cacheData, to: &stats)
            saveRateLimitsCache(cacheData)
            // OMC 캐시엔 extra_usage가 없으므로 추가로 API 호출해서 보완
            if !stats.rateLimits.extraUsageLoaded {
                fetchRateLimitsFromAPI(&stats)
            }
            return
        }

        // 3. OMC 없으면 직접 API 호출 (쿨다운 지난 경우만)
        fetchRateLimitsFromAPI(&stats)
        if stats.rateLimits.isLoaded { return }

        // 4. 모든 소스 실패 → 오래된 로컬 캐시라도 사용
        if let local = loadLocalCache() {
            applyRateLimitsData(local.data, to: &stats)
        }
    }

    // MARK: - Direct API Rate Limit Fetch

    private func fetchRateLimitsFromAPI(_ stats: inout UsageStats) {
        guard let token = readOAuthToken() else { return }

        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = [
            "-s", "-m", "5",
            "-H", "Authorization: Bearer \(token)",
            "-H", "anthropic-beta: oauth-2025-04-20",
            "https://api.anthropic.com/api/oauth/usage"
        ]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch { return }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        // API 응답을 OMC 캐시 형식으로 변환해서 로컬 캐시에 저장
        var cacheData: [String: Any] = [:]

        if let fiveHour = json["five_hour"] as? [String: Any] {
            let pct = fiveHour["utilization"] as? Double ?? 0
            cacheData["fiveHourPercent"] = pct
            stats.rateLimits.fiveHourPercent = pct
            if let resetStr = fiveHour["resets_at"] as? String {
                cacheData["fiveHourResetsAt"] = resetStr
                stats.rateLimits.fiveHourResetsAt = parseISO8601(resetStr)
            }
        }
        if let sevenDay = json["seven_day"] as? [String: Any] {
            let pct = sevenDay["utilization"] as? Double ?? 0
            cacheData["weeklyPercent"] = pct
            stats.rateLimits.weeklyPercent = pct
            if let resetStr = sevenDay["resets_at"] as? String {
                cacheData["weeklyResetsAt"] = resetStr
                stats.rateLimits.weeklyResetsAt = parseISO8601(resetStr)
            }
        }

        if let extraUsage = json["extra_usage"] as? [String: Any] {
            let enabled = extraUsage["is_enabled"] as? Bool ?? false
            cacheData["extraUsageEnabled"] = enabled
            stats.rateLimits.extraUsageLoaded = true
            stats.rateLimits.extraUsageEnabled = enabled
            if let used = extraUsage["used_credits"] as? Double {
                let usedUSD = used / 100.0
                cacheData["extraUsageUsed"] = usedUSD
                stats.rateLimits.extraUsageUsed = usedUSD
            }
            if let limit = extraUsage["monthly_limit"] as? Double {
                let limitUSD = limit / 100.0
                cacheData["extraUsageLimit"] = limitUSD
                stats.rateLimits.extraUsageLimit = limitUSD
            }
            if let util = extraUsage["utilization"] as? Double {
                cacheData["extraUsageUtilization"] = util
                stats.rateLimits.extraUsageUtilization = util
            }
            if let resetStr = extraUsage["resets_at"] as? String {
                cacheData["extraUsageResetsAt"] = resetStr
                stats.rateLimits.extraUsageResetsAt = parseISO8601(resetStr)
            }
        }

        if !cacheData.isEmpty {
            stats.rateLimits.isLoaded = true
            saveRateLimitsCache(cacheData)
        }
    }

    private func readOAuthToken() -> String? {
        // 1. Claude Code 키체인 시도
        if let token = readClaudeCodeToken() { return token }
        // 2. Claude.app config.json 시도 (Claude Code 없는 경우)
        return readClaudeAppToken()
    }

    private func readClaudeCodeToken() -> String? {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run(); process.waitUntilExit() } catch { return nil }
        guard process.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let jsonStr = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let jsonData = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else { return nil }

        if let oauth = json["claudeAiOauth"] as? [String: Any] {
            return oauth["accessToken"] as? String
        }
        return json["accessToken"] as? String
    }

    /// Claude.app의 config.json에서 암호화된 OAuth 토큰을 복호화해 반환
    private func readClaudeAppToken() -> String? {
        // 1. config.json에서 암호화된 tokenCache 읽기
        let configURL = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Claude/config.json")
        guard let configData = try? Data(contentsOf: configURL),
              let config = try? JSONSerialization.jsonObject(with: configData) as? [String: Any],
              let encryptedB64 = config["oauth:tokenCache"] as? String,
              let encrypted = Data(base64Encoded: encryptedB64),
              encrypted.count > 19,
              encrypted.prefix(3) == Data("v10".utf8)
        else { return nil }

        // 2. "Claude Safe Storage" 키체인에서 마스터 키 읽기
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Safe Storage", "-w"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run(); process.waitUntilExit() } catch { return nil }
        guard process.terminationStatus == 0 else { return nil }

        let keyData = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let masterKey = String(data: keyData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }

        // 3. PBKDF2-SHA1로 AES 키 유도 (Electron 표준)
        var aesKey = [UInt8](repeating: 0, count: 16)
        let salt = Array("saltysalt".utf8)
        let masterKeyBytes = Array(masterKey.utf8)
        let pbkdf2Result = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            masterKeyBytes, masterKeyBytes.count,
            salt, salt.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
            1003,
            &aesKey, aesKey.count
        )
        guard pbkdf2Result == kCCSuccess else { return nil }

        // 4. AES-CBC 복호화 (IV = 0x20 * 16, ciphertext = encrypted[3:])
        let ciphertext = encrypted.dropFirst(3)
        let iv = [UInt8](repeating: 0x20, count: 16)  // space * 16
        var plaintext = [UInt8](repeating: 0, count: ciphertext.count + kCCBlockSizeAES128)
        var plaintextLen = 0

        let cipherBytes = Array(ciphertext)
        let decryptResult = CCCrypt(
            CCOperation(kCCDecrypt),
            CCAlgorithm(kCCAlgorithmAES),
            CCOptions(kCCOptionPKCS7Padding),
            aesKey, aesKey.count,
            iv,
            cipherBytes, cipherBytes.count,
            &plaintext, plaintext.count,
            &plaintextLen
        )
        guard decryptResult == kCCSuccess else { return nil }

        // 5. JSON 파싱 후 첫 번째 유효 토큰 반환
        let plaintextData = Data(plaintext.prefix(plaintextLen))
        guard let tokenCache = try? JSONSerialization.jsonObject(with: plaintextData) as? [String: Any]
        else { return nil }

        for (_, value) in tokenCache {
            if let entry = value as? [String: Any],
               let token = entry["token"] as? String,
               token.hasPrefix("sk-ant-") {
                return token
            }
        }
        return nil
    }

    // MARK: - Context Info

    private func loadContextInfo(_ stats: inout UsageStats) {
        // 가장 최근 JSONL의 마지막 assistant 메시지에서 컨텍스트 추출
        var latestDate = Date.distantPast
        var latestUsage: [String: Any]?

        for dir in allProjectSubDirs() {
            guard let files = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { continue }

            for file in files where file.pathExtension == "jsonl" {
                guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                      let modDate = attrs.contentModificationDate,
                      modDate > latestDate
                else { continue }

                // 마지막 몇 KB만 읽어서 최신 usage 추출
                guard let handle = try? FileHandle(forReadingFrom: file) else { continue }
                let fileSize = handle.seekToEndOfFile()
                let readSize: UInt64 = min(fileSize, 20_000)
                handle.seek(toFileOffset: fileSize - readSize)
                let tailData = handle.readDataToEndOfFile()
                handle.closeFile()

                guard let tailStr = String(data: tailData, encoding: .utf8) else { continue }

                for line in tailStr.components(separatedBy: .newlines).reversed() {
                    guard !line.isEmpty,
                          let lineData = line.data(using: .utf8),
                          let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                          obj["type"] as? String == "assistant",
                          let message = obj["message"] as? [String: Any],
                          let usage = message["usage"] as? [String: Any],
                          let tsStr = obj["timestamp"] as? String,
                          let ts = parseISO8601(tsStr),
                          ts > latestDate
                    else { continue }

                    latestDate = ts
                    latestUsage = usage

                    // 모델명으로 max context 결정
                    if let model = message["model"] as? String {
                        if model.contains("1m") || model.contains("1M") {
                            stats.contextInfo.maxContextTokens = 1_000_000
                        } else {
                            stats.contextInfo.maxContextTokens = 200_000
                        }
                    }
                    break
                }
            }
        }

        if let usage = latestUsage {
            stats.contextInfo.currentInputTokens = usage["input_tokens"] as? Int ?? 0
            stats.contextInfo.cacheReadTokens = usage["cache_read_input_tokens"] as? Int ?? 0
        }
    }

    // MARK: - Private: Session Stats

    private func loadSessionStats() -> [String: [String: Any]] {
        let file = claudeDir.appendingPathComponent(".session-stats.json")
        guard let data = try? Data(contentsOf: file),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sessions = json["sessions"] as? [String: [String: Any]]
        else { return [:] }
        return sessions
    }

    // MARK: - Private: Process Utilities

    private func isProcessAlive(_ pid: Int32) -> Bool {
        kill(pid, 0) == 0
    }

    private func classifySource(_ pid: Int32) -> SessionSource {
        let ancestors = getAncestorNames(pid, depth: 4)
        let joined = ancestors.joined(separator: " ").lowercased()

        if joined.contains("iterm") { return .iterm }
        if joined.contains("ghostty") { return .ghostty }
        if joined.contains("warp") { return .warp }
        if joined.contains("wezterm") { return .wezterm }
        if joined.contains("cursor") { return .cursor }
        if joined.contains("code") || joined.contains("electron") { return .vscode }
        if joined.contains("xcode") { return .xcode }
        if joined.contains("zed") { return .zed }
        if joined.contains("idea") || joined.contains("webstorm") ||
            joined.contains("pycharm") || joined.contains("goland") ||
            joined.contains("rubymine") || joined.contains("clion") { return .jetbrains }
        if joined.contains("terminal") { return .terminal }

        return .unknown
    }

    private func getAncestorNames(_ pid: Int32, depth: Int) -> [String] {
        var names: [String] = []
        var current = pid
        for _ in 0..<depth {
            guard let ppid = getParentPid(current), ppid > 1 else { break }
            if let name = getProcessName(ppid) {
                names.append(name)
            }
            current = ppid
        }
        return names
    }

    private func getParentPid(_ pid: Int32) -> Int32? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return nil }
        let ppid = info.kp_eproc.e_ppid
        return ppid > 0 ? ppid : nil
    }

    private func getProcessName(_ pid: Int32) -> String? {
        let bufferSize = Int(MAXPATHLEN)
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        proc_name(pid, buffer, UInt32(bufferSize))
        let name = String(cString: buffer)
        return name.isEmpty ? nil : name
    }

    // MARK: - Private: State Resolution

    private func resolveState(cwd: String, pid: Int32) -> SessionState {
        // CPU 측정 제거 — proc_pidinfo/ps 호출이 CPU를 잡아먹는 원인
        // 파일 mtime 기반으로만 상태 판단

        let projectHash = cwdToProjectHash(cwd)
        let projectDir = projectsDir.appendingPathComponent(projectHash)

        guard let files = try? fm.contentsOfDirectory(
            at: projectDir,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return .idle }

        let jsonlFiles = files.filter { $0.pathExtension == "jsonl" }
        guard let latest = jsonlFiles.compactMap({ file -> (URL, Date)? in
            guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                  let date = attrs.contentModificationDate else { return nil }
            return (file, date)
        }).max(by: { $0.1 < $1.1 }) else { return .idle }

        let elapsed = Date().timeIntervalSince(latest.1)
        if elapsed < 15 { return .active }
        if elapsed < 300 { return .waiting }
        return .idle
    }

    private func getProcessCPU(_ pid: Int32) -> Double {
        // proc_pidinfo로 CPU 측정 — ps 프로세스 spawn 없이 (CPU 최적화)
        var taskInfo = proc_taskinfo()
        let size = MemoryLayout<proc_taskinfo>.size
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(size))
        guard result == Int32(size) else { return 0 }
        // total CPU time (user + system) in nanoseconds → 대략적 활성도 판단
        let totalTime = Double(taskInfo.pti_total_user + taskInfo.pti_total_system) / 1_000_000_000.0
        // 단순 활성 여부만 판단 (정확한 %가 아닌 근사치)
        return totalTime > 0 ? min(totalTime * 0.1, 100.0) : 0
    }

    private func cwdToProjectHash(_ cwd: String) -> String {
        cwd.map { c in
            if c.isLetter || c.isNumber { return String(c) }
            return "-"
        }.joined()
    }

    // MARK: - Private: Date Utils

    private func parseISO8601(_ str: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: str) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: str)
    }
}
