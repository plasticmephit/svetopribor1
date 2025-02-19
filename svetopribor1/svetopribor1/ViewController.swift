import UIKit
import CoreBluetooth

class BluetoothDevicesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource{
    
   
    
    let bluetoothManager = BluetoothManager.shared
    let tableView = UITableView()
    var devices: [(CBPeripheral, NSNumber)] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTable), name: NSNotification.Name("didUpdateRSSI"), object: nil)
     
       
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

    @objc private func reloadTable() {
        devices = bluetoothManager.devices
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let (device, rssi) = devices[indexPath.row]
        cell.textLabel?.text = "\(device.name ?? "Неизвестное устройство") - \(rssi) dBm"
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let (device, _) = devices[indexPath.row]
        bluetoothManager.centralManager.connect(device, options: nil)
//        let commandViewController = BluetoothCommandViewController(device: device)
//        navigationController?.pushViewController(commandViewController, animated: true)
    }
}
