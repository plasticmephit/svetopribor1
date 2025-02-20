import CoreData
import UIKit

struct Informator {
    let uuid: String
    let name: String
    let cleanName: String
    let longitude: NSDecimalNumber?
    let latitude: NSDecimalNumber?
    let descriptionText: String
    let type: String
}

class InformatorManager {
    static let shared = InformatorManager()

    private init() {}

    // Получаем managedContext
    private var managedContext: NSManagedObjectContext {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            fatalError("Unable to get AppDelegate")
        }
        return appDelegate.persistentContainer.viewContext
    }

    // Метод для добавления информатора
    func addInformator(_ informator: Informator) {
        let entity = NSEntityDescription.entity(forEntityName: "InformatorEntity", in: managedContext)!
        let informatorObject = NSManagedObject(entity: entity, insertInto: managedContext)

        informatorObject.setValue(informator.uuid, forKey: "uuid")
        informatorObject.setValue(informator.name, forKey: "name")
        informatorObject.setValue(informator.cleanName, forKey: "cleanName")
        informatorObject.setValue(informator.descriptionText, forKey: "descriptionText")
        informatorObject.setValue(informator.type, forKey: "type")

        if informator.type != "transport" {
            informatorObject.setValue(informator.longitude, forKey: "longitude")
            informatorObject.setValue(informator.latitude, forKey: "latitude")
        }

        do {
            try managedContext.save()
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }

    // Метод для добавления массива информаторов
    func addInformators(_ informators: [Informator]) {
        for informator in informators {
            addInformator(informator)
        }
    }

    // Метод для удаления информатора по UUID
    func deleteInformator(uuid: String) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "InformatorEntity")
        fetchRequest.predicate = NSPredicate(format: "uuid == %@", uuid)

        do {
            let fetchedResults = try managedContext.fetch(fetchRequest) as? [NSManagedObject]
            if let result = fetchedResults?.first {
                managedContext.delete(result)
                try managedContext.save()
            }
        } catch let error as NSError {
            print("Could not delete. \(error), \(error.userInfo)")
        }
    }

    // Метод для получения информатора по UUID
    func fetchInformator(uuid: String) -> Informator? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "InformatorEntity")
        fetchRequest.predicate = NSPredicate(format: "uuid == %@", uuid)

        do {
            let fetchedResults = try managedContext.fetch(fetchRequest) as? [NSManagedObject]
            if let result = fetchedResults?.first {
                return Informator(
                    uuid: result.value(forKey: "uuid") as! String,
                    name: result.value(forKey: "name") as! String,
                    cleanName: result.value(forKey: "cleanName") as! String,
                    longitude: result.value(forKey: "longitude") as? NSDecimalNumber,
                    latitude: result.value(forKey: "latitude") as? NSDecimalNumber,
                    descriptionText: result.value(forKey: "descriptionText") as! String,
                    type: result.value(forKey: "type") as! String
                )
            }
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
        return nil
    }

    // Метод для обновления информатора
    func updateInformator(_ informator: Informator) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "InformatorEntity")
        fetchRequest.predicate = NSPredicate(format: "uuid == %@", informator.uuid)

        do {
            let fetchedResults = try managedContext.fetch(fetchRequest) as? [NSManagedObject]
            if let informatorObject = fetchedResults?.first {
                informatorObject.setValue(informator.name, forKey: "name")
                informatorObject.setValue(informator.cleanName, forKey: "cleanName")
                informatorObject.setValue(informator.descriptionText, forKey: "descriptionText")
                informatorObject.setValue(informator.type, forKey: "type")

                if informator.type != "transport" {
                    informatorObject.setValue(informator.longitude, forKey: "longitude")
                    informatorObject.setValue(informator.latitude, forKey: "latitude")
                } else {
                    informatorObject.setValue(nil, forKey: "longitude")
                    informatorObject.setValue(nil, forKey: "latitude")
                }

                try managedContext.save()
            }
        } catch let error as NSError {
            print("Could not update. \(error), \(error.userInfo)")
        }
    }

    // Метод для получения всех информаторов
    func fetchAllInformators() -> [Informator]? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "InformatorEntity")

        do {
            let fetchedResults = try managedContext.fetch(fetchRequest) as? [NSManagedObject]
            return fetchedResults?.map {
                Informator(
                    uuid: $0.value(forKey: "uuid") as! String,
                    name: $0.value(forKey: "name") as! String,
                    cleanName: $0.value(forKey: "cleanName") as! String,
                    longitude: $0.value(forKey: "longitude") as? NSDecimalNumber,
                    latitude: $0.value(forKey: "latitude") as? NSDecimalNumber,
                    descriptionText: $0.value(forKey: "descriptionText") as! String,
                    type: $0.value(forKey: "type") as! String
                )
            }
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
            return nil
        }
    }
}
