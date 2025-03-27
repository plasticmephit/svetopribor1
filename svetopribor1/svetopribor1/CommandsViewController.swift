import UIKit
import CoreBluetooth
import MobileCoreServices

class BluetoothCommandViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
  
    private let label1 = UILabel()
       private let label2 = UILabel()
       private let label3 = UILabel()
    private let label6 = UILabel()
       private let headerStackView = UIStackView()
    let label5 = UILabel()
       private let tableView = UITableView()
       private var activityIndicator: UIActivityIndicatorView!
       private let responseTextView = UITextView()
       private let progressView = UIProgressView(progressViewStyle: .default)
    
  
    let bluetoothManager = BluetoothManager.shared
    let device: CBPeripheral
    
    let commands = [
        ("ble", "Подключение ble"),
        ("f1", "reset"),
        ("a", "Подключение"),
        ("b", "Отключение"),
        ("c", "Получение информации"),
        ("d", "Воспроизведение основной аудиозаписи"),
        ("g", "Увеличение громкости"),
        ("h", "Уменьшение громкости"),
        ("w", "Получение состояния проигрывателя"),
        ("f", "Остановка текущей аудиозаписи(0)"),
        ("start upload 0", "Старт отправки 0"),
        ("delete sound 0", "delete sound 0"),
        ("x", "Воспроизведение медленного(1) пика"),
        ("start upload 1", "Старт отправки 1"),
        ("delete sound 1", "delete sound 1"),
        ("y", "Воспроизведение среднего(2) пика"),
        ("delete sound 2", "delete sound 2"),
        ("start upload 2", "Старт отправки 2"),
        ("z", "Воспроизведение быстрого(3) пика"),
        ("start upload 3", "Старт отправки 3"),
        ("delete sound 3", "delete sound 3"),
        ("upload", "Отправить файл"),
        ("h+mac", "осталось памяти у esp под аудио"),
        ("w+mac", "список всех файлов с их размерами"),
        ("z+mac", "удаление всех файлов"),
//        ("g+mac", "воспроизведение аудио под номером цифра"),
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
   


    override func viewDidLoad() {
        super.viewDidLoad()
      
        NotificationCenter.default.addObserver(self, selector: #selector(handleResponse), name: NSNotification.Name("didReceiveResponse"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleResponseIsplay), name: NSNotification.Name("isplay"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleResponseanswer), name: NSNotification.Name("answer"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleResponsecrc), name: NSNotification.Name("crc"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleResponseconnect), name: NSNotification.Name("connect"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateProgressView(_:)), name: Notification.Name("updateProgress"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(deviceUpdated(_:)), name: NSNotification.Name("didUpdateRSSI"), object: nil)
               setupHeaderLabels()
               setupProgressView()
               setupTableView()
               setupActivityIndicator()
               setupResponseTextView()

    }
    
    @objc func handleResponseconnect(_ notification: Notification) {
        if let progress = notification.userInfo?["response"] as? String {
            DispatchQueue.main.async {
                self.label6.text = "status " + progress
            }
        }
    }
    @objc private func deviceUpdated(_ notification: Notification) {
            if let userInfo = notification.userInfo, let device = userInfo["device"] as? (CBPeripheral, NSNumber, Date) {
                if device.0.identifier == self.device.identifier{
                    
                    label5.text = "\(device.0.name ?? "Неизвестное устройство") - \(device.1) dBm"
                }
            }
        }
    @objc func handleResponseIsplay(_ notification: Notification) {
        if let progress = notification.userInfo?["response"] as? String {
            DispatchQueue.main.async {
                self.label1.text = "isplay " + progress
            }
        }
    }
    @objc func handleResponseanswer(_ notification: Notification) {
        if let progress = notification.userInfo?["response"] as? String {
            DispatchQueue.main.async {
                self.label2.text = "answer " + progress
            }
        }
    }
    @objc func handleResponsecrc(_ notification: Notification) {
        if let progress = notification.userInfo?["response"] as? String {
            DispatchQueue.main.async {
                self.label3.text = "crc " + progress
            }
        }
    }
    @objc func updateProgressView(_ notification: Notification) {
        if let progress = notification.userInfo?["progress"] as? Float {
            DispatchQueue.main.async {
                self.progressView.setProgress(progress, animated: true)
            }
        }
    }


    
    // MARK: - Настройка Header с UILabel
    private func setupHeaderLabels() {
          // Настраиваем лейблы
          label1.text = "Заголовок 1"
          label1.textColor = .darkText
          label1.font = UIFont.boldSystemFont(ofSize: 18)
          label1.textAlignment = .center
          
          label2.text = "Заголовок 2"
          label2.textColor = .darkText
          label2.font = UIFont.boldSystemFont(ofSize: 18)
          label2.textAlignment = .center
          
          label3.text = "Заголовок 3"
          label3.textColor = .darkText
          label3.font = UIFont.boldSystemFont(ofSize: 18)
          label3.textAlignment = .center
        let label4 = UILabel()
        label4.text =  bluetoothManager.calculateMACCRC32(macAddress: bluetoothManager.convertUUIDTo12Format(UIDevice.current.identifierForVendor!)) + "   mac device"
        label4.textColor = .darkText
        label4.font = UIFont.boldSystemFont(ofSize: 18)
        label4.textAlignment = .center
        
      
//        label5.text =  bluetoothManager.calculateMACCRC32(macAddress: bluetoothManager.convertUUIDTo12Format(UIDevice.current.identifierForVendor!)) + "   mac device"
        label5.textColor = .darkText
        label5.font = UIFont.boldSystemFont(ofSize: 18)
        label5.textAlignment = .center
        
        label6.textColor = .darkText
        label6.font = UIFont.boldSystemFont(ofSize: 18)
        label6.textAlignment = .center
        
          // Настраиваем UIStackView
          headerStackView.axis = .vertical
          headerStackView.spacing = 8
          headerStackView.distribution = .fillEqually
          headerStackView.translatesAutoresizingMaskIntoConstraints = false
          headerStackView.backgroundColor = .white
          
          // Добавляем лейблы в stackView
          headerStackView.addArrangedSubview(label1)
          headerStackView.addArrangedSubview(label2)
          headerStackView.addArrangedSubview(label3)
        headerStackView.addArrangedSubview(label4)
        headerStackView.addArrangedSubview(label5)
        headerStackView.addArrangedSubview(label6)
          
          // Добавляем stackView на основной view
          view.addSubview(headerStackView)
          
          NSLayoutConstraint.activate([
              headerStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
              headerStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
              headerStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
              headerStackView.heightAnchor.constraint(equalToConstant: 140)
          ])
      }
      
      // MARK: - Setup ProgressView
      private func setupProgressView() {
          progressView.translatesAutoresizingMaskIntoConstraints = false
          progressView.progress = 0.0    // Пример значения
          progressView.trackTintColor = .lightGray
          progressView.progressTintColor = .systemGreen
          
          view.addSubview(progressView)
          
          NSLayoutConstraint.activate([
              progressView.topAnchor.constraint(equalTo: headerStackView.bottomAnchor, constant: 8),
              progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
              progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
              progressView.heightAnchor.constraint(equalToConstant: 6) // Тонкая линия
          ])
      }
      
      // MARK: - Setup TableView
      private func setupTableView() {
          tableView.delegate = self
          tableView.dataSource = self
          tableView.register(UITableViewCell.self, forCellReuseIdentifier: "commandCell")
          tableView.translatesAutoresizingMaskIntoConstraints = false
          
          view.addSubview(tableView)
          
          NSLayoutConstraint.activate([
              tableView.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 8),
              tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
              tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
              // Разместим tableView до середины экрана
              tableView.heightAnchor.constraint(equalToConstant: 200)
          ])
      }
      
      // MARK: - Setup ActivityIndicator
      private func setupActivityIndicator() {
          activityIndicator = UIActivityIndicatorView(style: .large)
          activityIndicator.color = .gray
          activityIndicator.translatesAutoresizingMaskIntoConstraints = false
          
          view.addSubview(activityIndicator)
          
          NSLayoutConstraint.activate([
              activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
              activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
          ])
      }
      
      // MARK: - Setup ResponseTextView
    private func setupResponseTextView() {
        responseTextView.isEditable = false
        responseTextView.font = UIFont.systemFont(ofSize: 16)
        responseTextView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(responseTextView)
        
        NSLayoutConstraint.activate([
            responseTextView.topAnchor.constraint(equalTo: tableView.bottomAnchor, constant: 8),
            responseTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            responseTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            responseTextView.heightAnchor.constraint(equalToConstant: 140),
            responseTextView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
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
        let documentPicker = UIDocumentPickerViewController(documentTypes: [kUTTypeMP3 as String], in: .import)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true, completion: nil)
    }

    private func sendFile(url: URL) {
        do {
            bluetoothManager.isUpdating = true
            let audioData = try Data(contentsOf: url)
            bluetoothManager.currentPacketIndex = 0 // Сброс текущего индекса пакета перед отправкой
            bluetoothManager.packets = []
            
            let packetSize = 128
            for chunk in stride(from: 0, to: audioData.count, by: packetSize) {
                let end = min(chunk + packetSize, audioData.count)
                var packet = audioData.subdata(in: chunk..<end)
//                if packet.count < packetSize {
//                    packet.append(Data(repeating: 0xFF, count: packetSize - packet.count)) // Добиваем последний пакет символом 'f'
//                }
                bluetoothManager.packets.append(packet)
                print(bluetoothManager.packets.count, "count")
                
            }
            NotificationCenter.default.post(name: NSNotification.Name("didReceiveResponse"), object: nil, userInfo: ["response":String(bluetoothManager.packets.count) + " пакетов всего"])
            // Проверка на нечётное количество пакетов
//            if bluetoothManager.packets.count % 2 != 0 {
//                let additionalPacket = Data(repeating: 0xFF, count: packetSize) // Создаём пакет, состоящий из 'f'
//                bluetoothManager.packets.append(additionalPacket)
//            }
            
            bluetoothManager.sendCurrentPacket() // Начинаем отправку первого пакета
        } catch {
            bluetoothManager.isUpdating = false
            print("Ошибка чтения файла: \(error)")
        }
    }



}

extension BluetoothCommandViewController{
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
        if command == "ble" {
            bluetoothManager.centralManager.connect(device, options: nil)
            return
        }
        
        if command == "f1" {
            bluetoothManager.reset()
            return
        }
        if bluetoothManager.isUpdating{
            return
        }
        
        if command == "upload" {
            presentDocumentPicker()
            return
        }
        if bluetoothManager.readchar?.value != nil{
            if String(data: bluetoothManager.readchar!.value!, encoding: .utf8) == "207\0"{
                return
            }
        }
        if command == "start upload 3" {
            bluetoothManager.startUpdate(audioNumber: 3)
            return
        }
        if command == "start upload 2" {
            bluetoothManager.startUpdate(audioNumber: 2)
            return
        }
        if command == "start upload 1" {
            bluetoothManager.startUpdate(audioNumber: 1)
            return
        }
        if command == "delete sound 3" {
            bluetoothManager.deleteUpdate(audioNumber: 3)
            return
        }
        if command == "delete sound 2" {
            bluetoothManager.deleteUpdate(audioNumber: 2)
            return
        }
        if command == "delete sound 1" {
            bluetoothManager.deleteUpdate(audioNumber: 1)
            return
        }
        if command == "delete sound 0" {
            bluetoothManager.deleteUpdate(audioNumber: 0)
            return
        }
      
        if command == "h+mac" {
            bluetoothManager.fetchMemory()
            return
        }
        if command == "w+mac" {
            bluetoothManager.fetchAudio()
            return
        }
        if command == "z+mac" {
            bluetoothManager.removeAll()
            return
        }
        if command == "g+mac" {
//            bluetoothManager.deleteUpdate(audioNumber: 2)
            return
        }
        if command == "start upload 0" {
            bluetoothManager.startUpdate(audioNumber: 0)
            return
        }
       
        if command == "end"{
            bluetoothManager.finishUpdate()
            return
        }else{
            sendCommand(command)
            return
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
