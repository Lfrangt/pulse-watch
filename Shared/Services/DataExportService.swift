import Foundation
import SwiftData

/// 数据导出服务 — CSV / JSON 备份
@MainActor
final class DataExportService {

    static let shared = DataExportService()
    private init() {}

    // MARK: - CSV Export

    func exportDailySummariesCSV(summaries: [DailySummary]) throws -> URL {
        var csv = "date,averageHeartRate,minHeartRate,maxHeartRate,restingHeartRate,averageHRV,averageBloodOxygen,minBloodOxygen,totalSteps,activeCalories,restingCalories,exerciseMinutes,sleepDurationMinutes,deepSleepMinutes,remSleepMinutes,coreSleepMinutes,dailyScore\n"

        for s in summaries.sorted(by: { $0.date < $1.date }) {
            var row: [String] = []
            row.append(s.dateString)
            row.append(optStr(s.averageHeartRate))
            row.append(optStr(s.minHeartRate))
            row.append(optStr(s.maxHeartRate))
            row.append(optStr(s.restingHeartRate))
            row.append(optStr(s.averageHRV))
            row.append(optStr(s.averageBloodOxygen))
            row.append(optStr(s.minBloodOxygen))
            row.append(s.totalSteps.map { String($0) } ?? "")
            row.append(optStr(s.activeCalories))
            row.append(optStr(s.restingCalories))
            row.append(optStr(s.exerciseMinutes))
            row.append(s.sleepDurationMinutes.map { String($0) } ?? "")
            row.append(s.deepSleepMinutes.map { String($0) } ?? "")
            row.append(s.remSleepMinutes.map { String($0) } ?? "")
            row.append(s.coreSleepMinutes.map { String($0) } ?? "")
            row.append(s.dailyScore.map { String($0) } ?? "")
            csv += row.joined(separator: ",") + "\n"
        }

        let url = tempURL("pulse-daily-health.csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func exportWorkoutsCSV(workouts: [WorkoutHistoryEntry]) throws -> URL {
        var csv = "startDate,endDate,activityType,activityName,durationMinutes,totalCalories,totalDistance,averageHeartRate,maxHeartRate,source,isManual,notes\n"

        for w in workouts.sorted(by: { $0.startDate < $1.startDate }) {
            csv += [
                iso(w.startDate), iso(w.endDate),
                String(w.activityType), csvEscape(w.activityName),
                String(w.durationMinutes),
                optStr(w.totalCalories), optStr(w.totalDistance),
                optStr(w.averageHeartRate), optStr(w.maxHeartRate),
                csvEscape(w.sourceName),
                w.isManual ? "true" : "false",
                csvEscape(w.notes ?? "")
            ].joined(separator: ",") + "\n"
        }

        let url = tempURL("pulse-workouts.csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func exportStrengthCSV(records: [StrengthRecord]) throws -> URL {
        var csv = "date,liftType,weightKg,sets,reps,estimated1RM,isPersonalRecord,notes\n"

        for r in records.sorted(by: { $0.date < $1.date }) {
            csv += [
                iso(r.date), r.liftType,
                String(format: "%.1f", r.weightKg),
                String(r.sets), String(r.reps),
                String(format: "%.1f", r.estimated1RM),
                r.isPersonalRecord ? "true" : "false",
                csvEscape(r.notes ?? "")
            ].joined(separator: ",") + "\n"
        }

        let url = tempURL("pulse-strength.csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - JSON Backup

    func exportBackup(
        summaries: [DailySummary],
        workouts: [WorkoutHistoryEntry],
        strengthRecords: [StrengthRecord],
        goals: [HealthGoal]
    ) throws -> URL {
        let payload = BackupPayload(
            version: "1.0",
            exportDate: iso(.now),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            dailySummaries: summaries.sorted(by: { $0.date < $1.date }).map(\.backup),
            workouts: workouts.sorted(by: { $0.startDate < $1.startDate }).map(\.backup),
            strengthRecords: strengthRecords.sorted(by: { $0.date < $1.date }).map(\.backup),
            goals: goals.map(\.backup)
        )

        let data = try JSONEncoder.prettyEncoder.encode(payload)
        let url = tempURL("pulse-backup.json")
        try data.write(to: url)
        return url
    }

    func importBackup(from url: URL, modelContext: ModelContext) throws -> ImportResult {
        let data = try Data(contentsOf: url)
        let payload = try JSONDecoder().decode(BackupPayload.self, from: data)

        var stats = ImportResult()

        // Import daily summaries (upsert by dateString)
        for item in payload.dailySummaries {
            let descriptor = FetchDescriptor<DailySummary>(predicate: #Predicate { $0.dateString == item.dateString })
            let existing = (try? modelContext.fetch(descriptor)) ?? []

            if existing.isEmpty {
                let s = DailySummary(date: item.parsedDate)
                item.apply(to: s)
                modelContext.insert(s)
                stats.summariesImported += 1
            }
        }

        // Import workouts (dedup by hkWorkoutUUID)
        for item in payload.workouts {
            let uuid = item.hkWorkoutUUID
            let descriptor = FetchDescriptor<WorkoutHistoryEntry>(predicate: #Predicate { $0.hkWorkoutUUID == uuid })
            let existing = (try? modelContext.fetch(descriptor)) ?? []

            if existing.isEmpty {
                let w = item.toModel()
                modelContext.insert(w)
                stats.workoutsImported += 1
            }
        }

        // Import strength records (dedup by date + liftType + weight)
        for item in payload.strengthRecords {
            let sr = item.toModel()
            modelContext.insert(sr)
            stats.strengthImported += 1
        }

        // Import goals
        for item in payload.goals {
            let g = item.toModel()
            modelContext.insert(g)
            stats.goalsImported += 1
        }

        try modelContext.save()
        return stats
    }

    // MARK: - 辅助

    private func tempURL(_ filename: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }

    private func optStr(_ val: Double?) -> String {
        val.map { String(format: "%.1f", $0) } ?? ""
    }

    private func iso(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private func csvEscape(_ str: String) -> String {
        if str.contains(",") || str.contains("\"") || str.contains("\n") {
            return "\"\(str.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return str
    }
}

// MARK: - Import Result

struct ImportResult {
    var summariesImported = 0
    var workoutsImported = 0
    var strengthImported = 0
    var goalsImported = 0

    var total: Int { summariesImported + workoutsImported + strengthImported + goalsImported }
}

// MARK: - Backup Payload

struct BackupPayload: Codable {
    let version: String
    let exportDate: String
    let appVersion: String
    let dailySummaries: [DailySummaryBackup]
    let workouts: [WorkoutBackup]
    let strengthRecords: [StrengthRecordBackup]
    let goals: [GoalBackup]
}

// MARK: - Backup DTOs

struct DailySummaryBackup: Codable {
    let dateString: String
    let averageHeartRate, minHeartRate, maxHeartRate, restingHeartRate: Double?
    let averageHRV, averageBloodOxygen, minBloodOxygen: Double?
    let totalSteps: Int?
    let activeCalories, restingCalories, exerciseMinutes: Double?
    let sleepDurationMinutes, deepSleepMinutes, remSleepMinutes, coreSleepMinutes: Int?
    let dailyScore: Int?

    var parsedDate: Date {
        DailySummary.dateFormatter.date(from: dateString) ?? .now
    }

    func apply(to s: DailySummary) {
        s.averageHeartRate = averageHeartRate
        s.minHeartRate = minHeartRate
        s.maxHeartRate = maxHeartRate
        s.restingHeartRate = restingHeartRate
        s.averageHRV = averageHRV
        s.averageBloodOxygen = averageBloodOxygen
        s.minBloodOxygen = minBloodOxygen
        s.totalSteps = totalSteps
        s.activeCalories = activeCalories
        s.restingCalories = restingCalories
        s.exerciseMinutes = exerciseMinutes
        s.sleepDurationMinutes = sleepDurationMinutes
        s.deepSleepMinutes = deepSleepMinutes
        s.remSleepMinutes = remSleepMinutes
        s.coreSleepMinutes = coreSleepMinutes
        s.dailyScore = dailyScore
    }
}

struct WorkoutBackup: Codable {
    let hkWorkoutUUID: String
    let activityType: Int
    let startDate, endDate: String
    let durationSeconds: Double
    let totalCalories, totalDistance, averageHeartRate, maxHeartRate: Double?
    let sourceName: String
    let isManual: Bool
    let notes: String?

    func toModel() -> WorkoutHistoryEntry {
        let fmt = ISO8601DateFormatter()
        return WorkoutHistoryEntry(
            hkWorkoutUUID: hkWorkoutUUID,
            activityType: activityType,
            startDate: fmt.date(from: startDate) ?? .now,
            endDate: fmt.date(from: endDate) ?? .now,
            durationSeconds: durationSeconds,
            totalCalories: totalCalories,
            totalDistance: totalDistance,
            averageHeartRate: averageHeartRate,
            maxHeartRate: maxHeartRate,
            sourceName: sourceName,
            isManual: isManual,
            notes: notes
        )
    }
}

struct StrengthRecordBackup: Codable {
    let liftType: String
    let weightKg: Double
    let sets, reps: Int
    let date: String
    let isPersonalRecord: Bool
    let notes: String?

    func toModel() -> StrengthRecord {
        let r = StrengthRecord(
            liftType: liftType, weightKg: weightKg,
            sets: sets, reps: reps,
            date: ISO8601DateFormatter().date(from: date) ?? .now,
            notes: notes
        )
        r.isPersonalRecord = isPersonalRecord
        return r
    }
}

struct GoalBackup: Codable {
    let metricType: String
    let targetValue: Double
    let period: String
    let isActive: Bool

    func toModel() -> HealthGoal {
        let g = HealthGoal(metricType: metricType, targetValue: targetValue, period: period)
        g.isActive = isActive
        return g
    }
}

// MARK: - Model → Backup extensions

extension DailySummary {
    var backup: DailySummaryBackup {
        DailySummaryBackup(
            dateString: dateString,
            averageHeartRate: averageHeartRate, minHeartRate: minHeartRate,
            maxHeartRate: maxHeartRate, restingHeartRate: restingHeartRate,
            averageHRV: averageHRV,
            averageBloodOxygen: averageBloodOxygen, minBloodOxygen: minBloodOxygen,
            totalSteps: totalSteps,
            activeCalories: activeCalories, restingCalories: restingCalories,
            exerciseMinutes: exerciseMinutes,
            sleepDurationMinutes: sleepDurationMinutes, deepSleepMinutes: deepSleepMinutes,
            remSleepMinutes: remSleepMinutes, coreSleepMinutes: coreSleepMinutes,
            dailyScore: dailyScore
        )
    }
}

extension WorkoutHistoryEntry {
    var backup: WorkoutBackup {
        let fmt = ISO8601DateFormatter()
        return WorkoutBackup(
            hkWorkoutUUID: hkWorkoutUUID, activityType: activityType,
            startDate: fmt.string(from: startDate), endDate: fmt.string(from: endDate),
            durationSeconds: durationSeconds,
            totalCalories: totalCalories, totalDistance: totalDistance,
            averageHeartRate: averageHeartRate, maxHeartRate: maxHeartRate,
            sourceName: sourceName, isManual: isManual, notes: notes
        )
    }
}

extension StrengthRecord {
    var backup: StrengthRecordBackup {
        StrengthRecordBackup(
            liftType: liftType, weightKg: weightKg,
            sets: sets, reps: reps,
            date: ISO8601DateFormatter().string(from: date),
            isPersonalRecord: isPersonalRecord, notes: notes
        )
    }
}

extension HealthGoal {
    var backup: GoalBackup {
        GoalBackup(metricType: metricType, targetValue: targetValue, period: period, isActive: isActive)
    }
}

// MARK: - JSON Encoder helper

extension JSONEncoder {
    static let prettyEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
}
