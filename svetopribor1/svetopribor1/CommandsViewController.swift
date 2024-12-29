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
