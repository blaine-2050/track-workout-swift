import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    /// Preview with sample workout data - uses in-memory store
    static var preview: PersistenceController = {
        PersistenceController(inMemory: true)
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "TrackWorkout")

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        // Enable lightweight migration for additive schema changes
        // (new optional attributes, new entities). Avoids the need for an
        // explicit mapping model when growing the schema.
        for description in container.persistentStoreDescriptions {
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }

        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true

        // Seed data on first launch
        if !inMemory {
            seedDataIfNeeded()
        }
    }

    private func seedDataIfNeeded() {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<Move> = Move.fetchRequest()

        do {
            let count = try context.count(for: fetchRequest)
            if count == 0 {
                seedMoves(context: context)
            }
        } catch {
            print("Error checking for existing moves: \(error)")
        }
    }

    private func seedMoves(context: NSManagedObjectContext) {
        // (name, measurementType) pairs. measurementType: "strength" | "duration" | "note_only"
        let moves: [(String, String)] = [
            ("Bench Press", "strength"),
            ("Single Arm Snatch", "strength"),
            ("Incline DB Press", "strength"),
            ("Military DB Press", "strength"),
            ("Squat", "strength"),
            ("Split Squat", "strength"),
            ("Deadlift", "strength"),
            ("Lat Pull Down", "strength"),
            ("Bent Over Row", "strength"),
            ("Leg Press", "strength"),
            ("MTB", "duration"),
            ("Elipitical", "duration"),
            ("Treadmill", "duration")
        ]

        for (index, item) in moves.enumerated() {
            let move = Move(context: context)
            move.id = UUID()
            move.name = item.0
            move.sortOrder = Int16(index)
            move.isCustom = false
            move.measurementType = item.1
        }

        do {
            try context.save()
            print("Seeded \(moves.count) moves")
        } catch {
            print("Error seeding moves: \(error)")
        }
    }
}
