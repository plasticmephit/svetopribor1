import UIKit
import CoreBluetooth

class BluetoothCommandViewController: UIViewController {
    let bluetoothManager = BluetoothManager.shared
    let device: CBPeripheral
    let tableView = UITableView()
    var activityIndicator: UIActivityIndicatorView!

    let commands = [
        ("a", "Подключение"),
        ("b", "Отключение"),
        ("c", "Получение информации"),
        ("d", "Воспроизведение основной аудиозаписи"),
        ("e", "Постановка на паузу текущей аудиозаписи"),
        ("f", "Остановка текущей аудиозаписи"),
        ("g", "Увеличение громкости"),
        ("h", "Уменьшение громкости"),
        ("w", "Получение состояния проигрывателя"),
        ("x", "Воспроизведение медленного пика"),
        ("y", "Воспроизведение среднего пика"),
        ("z", "Воспроизведение быстрого пика")
    ]
    
    init(device: CBPeripheral) {
        self.device = device
        bluetoothManager.centralManager.connect(device, options: nil)
//        bluetoothManager.sendString(toPeripheral: device, message: "a")
        super.init(nibName: nil, bundle: nil)
        self.title = device.name ?? "Команды устройства"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupActivityIndicator()
        NotificationCenter.default.addObserver(self, selector: #selector(handleResponse), name: NSNotification.Name("didReceiveResponse"), object: nil)
    }

    private func setupTableView() {
        view.backgroundColor = .white

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "commandCell")
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
    }

    private func setupActivityIndicator() {
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .gray
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
        
        activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    }

    @objc private func handleResponse(notification: Notification) {
        
        if let response = notification.userInfo?["response"] as? String {
            activityIndicator.stopAnimating()
            
            tableView.isUserInteractionEnabled = true
            switch response {
            case "200\0":
                print("CONNECT_OK")
            case "400\0":
                print("DEVICE_BUSY_ERR")
            case "401\0":
                print("INVALID_MAC_ERR")
            case "402\0":
                print("CONNECT_ERR")
            case "403\0":
                print("DISCONNECT_ERR")
            case "201\0":
                print("DISCONNECT_OK")
            case "404\0":
                print("AUDIO_ALREADY_START")
            case "202\0":
                print("AUDIO_START_OK")
            case "405\0":
                print("AUDIO_START_ERR")
            case "406\0":
                print("AUDIO_ALREADY_STOP")
            case "203\0":
                print("AUDIO_STOP_OK")
            case "407\0":
                print("AUDIO_STOP_ERR")
            case "408\0":
                print("AUDIO_ALREADY_PAUSE")
            case "204\0":
                print("AUDIO_PAUSE_OK")
            case "409\0":
                print("AUDIO_PAUSE_ERR")
            case "205\0":
                print("AUDIO_LOUDER_OK")
            case "206\0":
                print("AUDIO_QUIET_OK")
            case "100\0":
                print("DEFAULT")
            case "410\0":
                print("WRONG_MESSAGE")
            case "411\0":
                print("DEVICE_ISNT_CONNECTED")
            case "412\0":
                print("DEVICE_ALREADY_CONNECTED")
            case "500\0":
                print("DISCONNECT_REQ")
            case "501\0":
                print("CONTINUE_SESSION_SUC")
            case "502\0":
                print("SESSION_TIMEOUT_DISK")
            default:
                print("Unknown response: \(response)")
            }
            let alert = UIAlertController(title: "Ответ", message: response, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
        }
        activityIndicator.stopAnimating()
        tableView.isUserInteractionEnabled = true
    }

    private func sendCommand(_ command: String) {
        guard let peripheral = bluetoothManager.selectedDev else {
            print("No peripheral connected")
            return
        }

       
        activityIndicator.startAnimating()
      
        bluetoothManager.sendString(toPeripheral: peripheral, message: command)
    }
}

extension BluetoothCommandViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return commands.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "commandCell", for: indexPath)
        let command = commands[indexPath.row]
        cell.textLabel?.text = command.1
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let command = commands[indexPath.row].0
        sendCommand(command)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
