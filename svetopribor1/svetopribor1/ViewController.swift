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
        cell.textLabel?.text = "\(device.name ?? "Неизвестное устройство") - \(rssi) dBm"
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let (device, _, _) = devices[indexPath.row]
        bluetoothManager.centralManager.connect(device, options: nil)
        bluetoothManager.sendpause()
//        let commandViewController = BluetoothCommandViewController(device: device)
//        navigationController?.pushViewController(commandViewController, animated: true)
    }
}
