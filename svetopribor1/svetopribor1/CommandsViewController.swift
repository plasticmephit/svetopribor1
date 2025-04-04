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
        // Сначала проверяем валидность MP3-файла
        guard isValidMP3(url: url) else {
            // Если файл не проходит проверку, показываем алерт с ошибкой
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Ошибка", message: "Неверный MP3 файл!", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
            bluetoothManager.isUpdating = false
            return
        }
        
        do {
            bluetoothManager.isUpdating = true
            let audioData = try Data(contentsOf: url)
            bluetoothManager.currentPacketIndex = 0 // Сброс текущего индекса пакета перед отправкой
            bluetoothManager.packets = []
            
            let packetSize = 219
            for chunk in stride(from: 0, to: audioData.count, by: packetSize) {
                let end = min(chunk + packetSize, audioData.count)
                let packet = audioData.subdata(in: chunk..<end)
                bluetoothManager.packets.append(packet)
                print(bluetoothManager.packets.count, "count")
            }
            
            NotificationCenter.default.post(name: NSNotification.Name("didReceiveResponse"),
                                            object: nil,
                                            userInfo: ["response": "\(bluetoothManager.packets.count) пакетов всего"])
            // Начинаем отправку первого пакета
            bluetoothManager.sendCurrentPacket()
        } catch {
            bluetoothManager.isUpdating = false
            print("Ошибка чтения файла: \(error)")
        }
    }

    private func isValidMP3(url: URL) -> Bool {
        // Пробуем загрузить данные из файла
        guard let fileData = try? Data(contentsOf: url) else {
            print("Error: Failed to read file data!")
            return false
        }
        
        // Минимальный размер для проверки — минимум 10 байт (для заголовка ID3)
        guard fileData.count >= 10 else {
            print("Error: File too short to be a valid MP3 file!")
            return false
        }
        
        var offset = 0
        let header = fileData.subdata(in: 0..<10)
        
        // Если первые три байта равны "ID3", это заголовок ID3v2
        if header[0] == 0x49 && header[1] == 0x44 && header[2] == 0x33 {
            // Вычисляем длину заголовка ID3v2 (ячейки 6-9 — "synchsafe")
            let id3Length = Int((UInt32(header[6] & 0x7F) << 21) |
                                (UInt32(header[7] & 0x7F) << 14) |
                                (UInt32(header[8] & 0x7F) << 7)  |
                                UInt32(header[9] & 0x7F))
            offset = 10 + id3Length
            if fileData.count < offset + 4 {
                print("Error: Not enough data after ID3 header!")
                return false
            }
            print("ID3v2 header detected, skipping \(id3Length) bytes...")
        } else {
            offset = 0
            if fileData.count < 4 {
                print("Error: File too short for MP3 frame header!")
                return false
            }
        }
        
        // Читаем 4-байтовый заголовок MP3-фрейма
        let frameHeader = fileData.subdata(in: offset..<offset+4)
        
        // Проверяем валидность заголовка MP3-фрейма: первый байт должен быть 0xFF, а верхние 3 бита второго байта — 0xE0
        if frameHeader[0] != 0xFF || (frameHeader[1] & 0xE0) != 0xE0 {
            print("Error: Invalid MP3 frame header!")
            return false
        }
        
        // Определяем параметры MP3-файла (битрейт, частота дискретизации, режим каналов)
        let bitrates: [Int] = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0]
        let sampleRates: [Int] = [44100, 48000, 32000, 0]
        let channelModes = ["Stereo", "Joint Stereo", "Dual Channel", "Mono"]
        
        let bitrateIndex = Int((frameHeader[2] >> 4) & 0x0F)
        let bitrate = bitrates[bitrateIndex]
        let sampleRateIndex = Int((frameHeader[2] >> 2) & 0x03)
        let sampleRate = sampleRates[sampleRateIndex]
        let channelModeIndex = Int((frameHeader[3] >> 6) & 0x03)
        let channelMode = channelModes[channelModeIndex]
        
        // Если битрейт или частота дискретизации равны 0, формат не поддерживается
        if bitrate == 0 || sampleRate == 0 {
            print("Error: Unsupported MP3 format!")
            return false
        }
        
        print("File: \(url.lastPathComponent)")
        print("Bitrate: \(bitrate) kbps")
        print("Sample Rate: \(sampleRate) Hz")
        print("Channels: \(channelMode)")
        print("MP3 file is valid for playback!")
        
        return true
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
