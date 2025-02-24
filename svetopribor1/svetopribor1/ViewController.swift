import UIKit
import CoreBluetooth

class BluetoothDevicesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource{
    
   
    
    let bluetoothManager = BluetoothManager.shared
    let tableView = UITableView()
    var devices: [(CBPeripheral, NSNumber, Date)] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
      
        NotificationCenter.default.addObserver(self, selector: #selector(deviceUpdated(_:)), name: NSNotification.Name("didUpdateRSSI"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(deviceRemoved(_:)), name: NSNotification.Name("didRemovePeripheral"), object: nil)
        // Добавление информатора
        let newInformator = Informator(
            uuid: UUID().uuidString,
            name: "example-uuid-to-delete",
            cleanName: "Clean Example Name",
            longitude: NSDecimalNumber(string: "27.9876543"),
            latitude: NSDecimalNumber(string: "53.8976543"),
            descriptionText: "Example description",
            type: "object"
        )
        InformatorManager.shared.addInformator(newInformator)

        // Добавление массива информаторов
        let informatorsArray = [
            Informator(
                uuid: "example-uuid-to-fetch",
                name: "Example Name 1",
                cleanName: "Clean Example Name 1",
                longitude: NSDecimalNumber(string: "27.9876543"),
                latitude: NSDecimalNumber(string: "53.8976543"),
                descriptionText: "Example description 1",
                type: "object"
            ),
            Informator(
                uuid: "example-uuid-to-fetch1",
                name: "Example Name 2",
                cleanName: "Clean Example Name 2",
                longitude: NSDecimalNumber(string: "26.9876543"),
                latitude: NSDecimalNumber(string: "52.8976543"),
                descriptionText: "Example description 2",
                type: "transport"
            )
        ]
        InformatorManager.shared.addInformators(informatorsArray)

        // Удаление информатора по UUID
//        let informatorUUIDToDelete = "example-uuid-to-delete" // Пример UUID для удаления
//        InformatorManager.shared.deleteInformator(uuid: informatorUUIDToDelete)

        // Получение информатора по UUID
        let informatorUUIDToFetch = "example-uuid-to-fetch" // Пример UUID для получения данных
        if let fetchedInformator = InformatorManager.shared.fetchInformator(uuid: informatorUUIDToFetch) {
            print("Fetched Informator: \(fetchedInformator)")
        } else {
            print("Informator not found.")
        }

        // Обновление информатора
        let updatedInformator = Informator(
            uuid: informatorUUIDToFetch,
            name: "Updated Name",
            cleanName: "Updated Clean Name",
            longitude: NSDecimalNumber(string: "25.9876543"),
            latitude: NSDecimalNumber(string: "51.8976543"),
            descriptionText: "Updated description",
            type: "object"
        )
        InformatorManager.shared.updateInformator(updatedInformator)

        // Получение всех информаторов
        if let allInformators = InformatorManager.shared.fetchAllInformators() {
            for informator in allInformators {
                print("Informator: \(informator)")
            }
        } else {
            print("No informators found.")
        }

       
    }
    
    @objc private func deviceRemoved(_ notification: Notification) {
         if let userInfo = notification.userInfo, let device = userInfo["device"] as? CBPeripheral {
             if let index = devices.firstIndex(where: { $0.0.identifier == device.identifier }) {
                 devices.remove(at: index)
                 tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
             }
         }
     }

    private func setupTableView() {
        view.backgroundColor = .white
        title = "Устройства Bluetooth"

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
    }

   
    @objc private func deviceUpdated(_ notification: Notification) {
            if let userInfo = notification.userInfo, let device = userInfo["device"] as? (CBPeripheral, NSNumber, Date) {
                if let index = devices.firstIndex(where: { $0.0.identifier == device.0.identifier }) {
                    devices[index] = device
//                    tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
                 
                    (tableView.cellForRow(at: IndexPath(row: index, section: 0)))?.textLabel?.text = "\(device.0.name ?? "Неизвестное устройство") - \(device.1) dBm"
                } else {
                    devices.append(device)
                    tableView.insertRows(at: [IndexPath(row: devices.count - 1, section: 0)], with: .automatic)
                }
            }
        }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let (device, rssi, data) = devices[indexPath.row]
        print(device.identifier, "device1")
        cell.textLabel?.text = "\(device.name ?? "Неизвестное устройство") - \(rssi) dBm"
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let (device, _, _) = devices[indexPath.row]
//        bluetoothManager.centralManager.connect(device, options: nil)
//        bluetoothManager.sendpause()
        let commandViewController = BluetoothCommandViewController(device: device)
        navigationController?.pushViewController(commandViewController, animated: true)
    }
}
