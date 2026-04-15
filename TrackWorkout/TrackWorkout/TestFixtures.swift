import Foundation
import CoreData

/**
 Test fixtures for Track Workout iOS

 Rules:
 - move: must be a string
 - weight: stored as int, displayed as decimal with 1 digit
 - reps: int > 0
 - timestamps: increasing across the workout
 */

// MARK: - Move Names
/// Standard moves used across all platforms (alphabetically sorted)
let fixtureMovesOrdered: [String] = [
    "Bench Press",
    "Bent Over Row",
    "Deadlift",
    "Elipitical",
    "Incline DB Press",
    "Lat Pull Down",
    "Leg Press",
    "Military DB Press",
    "MTB",
    "Single Arm Snatch",
    "Split Squat",
    "Squat",
    "Treadmill"
]

// MARK: - Sample Workout Data
/// Format: (moveName, weight as Int, reps)
let sampleWorkoutRaw: [(String, Int, Int)] = [
    ("Bench Press", 110, 10),
    ("Bench Press", 150, 5),
    ("Bench Press", 150, 2),
    ("Single Arm Snatch", 2, 10),
    ("Single Arm Snatch", 4, 10),
    ("Single Arm Snatch", 8, 1),
    ("Incline DB Press", 30, 10),
    ("Incline DB Press", 40, 4),
    ("Incline DB Press", 50, 2),
    ("Military DB Press", 50, 2),
    ("Squat", 200, 5),
    ("Split Squat", 50, 12),
    ("Split Squat", 50, 10),
    ("Split Squat", 50, 8),
    ("Split Squat", 50, 4),
    ("Deadlift", 250, 1),
    ("Lat Pull Down", 50, 30),
    ("Lat Pull Down", 80, 10),
    ("Lat Pull Down", 130, 5),
    ("Bent Over Row", 50, 10),
    ("Leg Press", 150, 20),
    ("Leg Press", 170, 10),
    ("Leg Press", 190, 5),
    ("Leg Press", 210, 2),
]

// MARK: - Validation Helpers
func isValidWeight(_ weight: Int) -> Bool {
    return weight >= 0
}

func isValidReps(_ reps: Int) -> Bool {
    return reps > 0
}

func formatWeight(_ weight: Int) -> String {
    return String(format: "%.1f", Double(weight))
}

func formatWeight(_ weight: Double) -> String {
    return String(format: "%.1f", weight)
}

// MARK: - Core Data Test Fixtures
extension PersistenceController {

    /// Create a preview controller with full sample workout data
    static var previewWithSampleWorkout: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let context = result.container.viewContext

        // Create moves
        var movesByName: [String: Move] = [:]
        for (index, name) in fixtureMovesOrdered.enumerated() {
            let move = Move(context: context)
            move.id = UUID()
            move.name = name
            move.sortOrder = Int16(index)
            movesByName[name] = move
        }

        // Create log entries with increasing timestamps
        // Start time: 2024-01-15 06:00:00 UTC
        // Each entry 2 minutes apart
        let baseDate = ISO8601DateFormatter().date(from: "2024-01-15T06:00:00Z")!
        let intervalSeconds: TimeInterval = 2 * 60 // 2 minutes

        for (index, item) in sampleWorkoutRaw.enumerated() {
            let (moveName, weight, reps) = item
            guard let move = movesByName[moveName] else { continue }

            let entry = LogEntry(context: context)
            entry.id = UUID()
            entry.moveId = move.id ?? UUID()
            entry.weight = Double(weight)
            entry.reps = Int16(reps)
            entry.timestamp = baseDate.addingTimeInterval(Double(index) * intervalSeconds)
        }

        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            fatalError("Failed to save preview context: \(nsError), \(nsError.userInfo)")
        }

        return result
    }()

    /// Seed sample workout data into the given context
    func seedSampleWorkout(context: NSManagedObjectContext) {
        // First, get or create moves
        let fetchRequest: NSFetchRequest<Move> = Move.fetchRequest()
        var movesByName: [String: Move] = [:]

        do {
            let existingMoves = try context.fetch(fetchRequest)
            for move in existingMoves {
                if let name = move.name {
                    movesByName[name] = move
                }
            }
        } catch {
            print("Error fetching moves: \(error)")
            return
        }

        // Create log entries
        let baseDate = Date()
        let intervalSeconds: TimeInterval = 2 * 60

        for (index, item) in sampleWorkoutRaw.enumerated() {
            let (moveName, weight, reps) = item
            guard let move = movesByName[moveName] else { continue }

            let entry = LogEntry(context: context)
            entry.id = UUID()
            entry.moveId = move.id ?? UUID()
            entry.weight = Double(weight)
            entry.reps = Int16(reps)
            entry.timestamp = baseDate.addingTimeInterval(Double(index) * intervalSeconds)
        }

        do {
            try context.save()
            print("Seeded \(sampleWorkoutRaw.count) sample workout entries")
        } catch {
            print("Error seeding sample workout: \(error)")
        }
    }
}
