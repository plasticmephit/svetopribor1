import UIKit
import CoreBluetooth
import MobileCoreServices

class BluetoothCommandViewController: UIViewController {
    let bluetoothManager = BluetoothManager.shared
    let device: CBPeripheral
    let tableView = UITableView()
    var activityIndicator: UIActivityIndicatorView!
    var responseTextView: UITextView!

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
        ("z", "Воспроизведение быстрого пика"),
        ("start upload", "Старт отправки"),
        ("upload", "Отправить файл")
    ]
    
    init(device: CBPeripheral) {
        self.device = device
        bluetoothManager.centralManager.connect(device, options: nil)
        
        super.init(nibName: nil, bundle: nil)
        self.title = device.name ?? "Команды устройства"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    var progressView = UIProgressView()


    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupActivityIndicator()
        setupResponseTextView()
        NotificationCenter.default.addObserver(self, selector: #selector(handleResponse), name: NSNotification.Name("didReceiveResponse"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateProgressView(_:)), name: Notification.Name("updateProgress"), object: nil)
        setupProgressView()


    }
    @objc func updateProgressView(_ notification: Notification) {
        if let progress = notification.userInfo?["progress"] as? Float {
            DispatchQueue.main.async {
                self.progressView.setProgress(progress, animated: true)
            }
        }
    }

    private func setupTableView() {
        view.backgroundColor = .white

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "commandCell")
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor).isActive = true
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

    private func setupResponseTextView() {
        responseTextView = UITextView()
        responseTextView.isEditable = false
        responseTextView.font = UIFont.systemFont(ofSize: 16)
        responseTextView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(responseTextView)
        
        responseTextView.topAnchor.constraint(equalTo: tableView.bottomAnchor).isActive = true
        responseTextView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        responseTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        responseTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
    }

    @objc private func handleResponse(notification: Notification) {
        if let response = notification.userInfo?["response"] as? String {
            activityIndicator.stopAnimating()
            tableView.isUserInteractionEnabled = true
            
            // Append response to the UITextView
            let newResponse = "Ответ: \(response)\n"
            responseTextView.text += newResponse
            
            // Scroll to the bottom of the UITextView
            let bottom = NSRange(location: responseTextView.text.count - 1, length: 1)
            responseTextView.scrollRangeToVisible(bottom)
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
    
    private func presentDocumentPicker() {
        let documentPicker = UIDocumentPickerViewController(documentTypes: [kUTTypeWaveformAudio as String], in: .import)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true, completion: nil)
    }

    private func sendFile(url: URL) {
        do {
            let audioData = try Data(contentsOf: url)
            bluetoothManager.currentPacketIndex = 0 // Сброс текущего индекса пакета перед отправкой
            bluetoothManager.packets = []
            
            let packetSize = 128
            for chunk in stride(from: 0, to: audioData.count, by: packetSize) {
                let end = min(chunk + packetSize, audioData.count)
                var packet = audioData.subdata(in: chunk..<end)
                if packet.count < packetSize {
                    packet.append(Data(repeating: 0x66, count: packetSize - packet.count)) // Добиваем последний пакет символом 'f'
                }
                bluetoothManager.packets.append(packet)
                print(bluetoothManager.packets.count, "count")
            }

            // Проверка на нечётное количество пакетов
            if bluetoothManager.packets.count % 2 != 0 {
                let additionalPacket = Data(repeating: 0x66, count: packetSize) // Создаём пакет, состоящий из 'f'
                bluetoothManager.packets.append(additionalPacket)
            }
            
            bluetoothManager.sendCurrentPacket() // Начинаем отправку первого пакета
        } catch {
            print("Ошибка чтения файла: \(error)")
        }
    }


    private func setupProgressView() {
        progressView = UIProgressView(progressViewStyle: .default)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressView)
        
        // Пример авто-лейаута
        NSLayoutConstraint.activate([
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            progressView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40)
        ])
        
        progressView.progress = 0.0
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
        if command == "start upload" {
            bluetoothManager.startUpdate(audioNumber: 0)
        } else if command == "upload" {
            presentDocumentPicker()
        } else {
            sendCommand(command)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension BluetoothCommandViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            return
        }
        sendFile(url: url)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("Выбор файла был отменен.")
    }
}
