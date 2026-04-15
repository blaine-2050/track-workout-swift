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
        let moves = [
            "Bench Press",
            "Single Arm Snatch",
            "Incline DB Press",
            "Military DB Press",
            "Squat",
            "Split Squat",
            "Deadlift",
            "Lat Pull Down",
            "Bent Over Row",
            "Leg Press",
            "MTB",
            "Elipitical",
            "Treadmill"
        ]

        for (index, name) in moves.enumerated() {
            let move = Move(context: context)
            move.id = UUID()
            move.name = name
            move.sortOrder = Int16(index)
        }

        do {
            try context.save()
            print("Seeded \(moves.count) moves")
        } catch {
            print("Error seeding moves: \(error)")
        }
    }
}
