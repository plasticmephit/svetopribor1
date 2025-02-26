import UIKit
import CoreBluetooth
import MobileCoreServices

class BluetoothManager: NSObject, CBPeripheralManagerDelegate, CBCentralManagerDelegate, CBPeripheralDelegate, UIDocumentPickerDelegate {
    static let shared = BluetoothManager()
    
    var selectedDev: CBPeripheral? = nil
    var batteryPeripheral: CBPeripheral? = nil
    var centralManager: CBCentralManager!
    var devices: [(CBPeripheral, NSNumber, Date)] = []
    var writeChar: CBCharacteristic?
    var crc32Char: CBCharacteristic?
    var readchar: CBCharacteristic?
    var isPlaying: CBCharacteristic?
    var peripheralManager: CBPeripheralManager?
    var updateCharacteristic: CBCharacteristic?
    var crc32Mac = ""
    var currentPacketIndex = 1
    var packets: [Data] = []
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    func handlePacketResponse(_ packetNumber: Int) {
         if packetNumber == currentPacketIndex + 1 {
             currentPacketIndex = packetNumber
             if currentPacketIndex < packets.count {
                 sendCurrentPacket()
             } else {
                 finishUpdate()
             }
         } else {
             sendCurrentPacket()
         }
     }
     
    func sendCurrentPacket() {
        guard let updateCharacteristic = updateCharacteristic else {
            print("Характеристика для обновления не найдена.")
            return
        }
        
        let packet = packets[currentPacketIndex]
        let crcString = formatCRC32ToMAC(crc32: crc32Mac)
        
        // Преобразуем префикс 'b' и строковый CRC32 в Data
        guard let prefixData = ("b" + crcString).data(using: .utf8) else {
            print("Ошибка при преобразовании префикса в данные.")
            return
        }
        
        // Объединяем префикс с исходными данными пакета
        var fullPacketData = Data()
        fullPacketData.append(prefixData)
        fullPacketData.append(packet)
        
        // Отправляем данные
        selectedDev?.writeValue(fullPacketData, for: updateCharacteristic, type: .withResponse)
    }

    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        } else {
            print("Bluetooth не включен")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let name = peripheral.name, name.starts(with: "BYE") {
            let now = Date()
            if let index = devices.firstIndex(where: { $0.0.identifier == peripheral.identifier }) {
                devices[index].1 = RSSI
                devices[index].2 = now
            } else {
                devices.append((peripheral, RSSI, now))
            }
            NotificationCenter.default.post(name: NSNotification.Name("didUpdateRSSI"), object: nil, userInfo: ["device": (peripheral, RSSI, now)])
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.removeInactiveDevices()
            }
        }
    }
    
    func removeInactiveDevices() {
        let now = Date()
        devices.removeAll { device, _, lastSeen in
            let remove = now.timeIntervalSince(lastSeen) > 2
            if remove {
                print("Removed inactive device \(device.name ?? "Unknown device")")
                NotificationCenter.default.post(name: NSNotification.Name("didRemovePeripheral"), object: nil, userInfo: ["device": device])
            }
            return remove
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown Device")")
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        selectedDev = peripheral
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to \(peripheral.name ?? "Unknown Device"): \(error?.localizedDescription ?? "Unknown Error")")
        removeInactiveDevices()
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from \(peripheral.name ?? "Unknown Device")")
        selectedDev = nil
        NotificationCenter.default.post(name: NSNotification.Name("didDisconnectPeripheral"), object: nil)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
        batteryPeripheral = peripheral
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("Error discovering characteristics: \(String(describing: error))")
            return
        }
        selectedDev = peripheral
        for characteristic in service.characteristics ?? [] {
            let targetUUID = CBUUID(string: "e1c800b4-695b-4747-9256-6d22fd869f5A")
            if characteristic.properties.contains(.notify) {
                if characteristic.uuid == targetUUID {
                    crc32Char = characteristic
                    peripheral.readValue(for: characteristic)
                    peripheral.setNotifyValue(true, for: characteristic)
                } else if characteristic.uuid == CBUUID(string: "E1C800B4-695B-4747-9256-6D22FD869F5B") {
                    peripheral.setNotifyValue(true, for: characteristic)
                    isPlaying = characteristic
                } else if characteristic.uuid == CBUUID(string: "E1C800B4-695B-4747-9256-6D22FD869F58") {
                    peripheral.setNotifyValue(true, for: characteristic)
                    readchar = characteristic
                }
            }
            if characteristic.uuid == CBUUID(string: "E1C800B4-695B-4747-9256-6D22FD869F5C") {
               
                updateCharacteristic = characteristic
            }
            if characteristic.uuid == CBUUID(string: "E1C800B4-695B-4747-9256-6D22FD869F59") {
                writeChar = characteristic
            }
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error writing value for characteristic \(characteristic.uuid): \(error.localizedDescription)")
        } else {
            print("Successfully wrote value for characteristic \(characteristic.uuid)")
            peripheral.readValue(for: characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if peripheral != selectedDev {
            return
        }
        let crc = calculateMACCRC32(macAddress: convertUUIDTo12Format(UIDevice.current.identifierForVendor!))
        if let error = error {
            print("Error updating value for characteristic \(characteristic.uuid): \(error.localizedDescription)")
            return
        }
        
        let targetUUID3 = CBUUID(string: "e1c800b4-695b-4747-9256-6d22fd869f5a")
        if characteristic.uuid == targetUUID3 {
            return
        }
        let targetUUID1 = CBUUID(string: "e1c800b4-695b-4747-9256-6d22fd869f5b")
        if characteristic.uuid == targetUUID1 {
        }
        let targetUUID2 = CBUUID(string: "e1c800b4-695b-4747-9256-6d22fd869f58")
        if characteristic.uuid == targetUUID2 {
        }
        NotificationCenter.default.post(name: NSNotification.Name("didReceiveResponse"), object: nil, userInfo: ["response":characteristic.uuid.uuidString + " " +  (String(data: characteristic.value!, encoding: .utf8) ?? "")])
        if let readChar = crc32Char {
            readCharacteristic { value in
                if let readValue = value {
                    let data = readValue
                    if let string = String(data: data, encoding: .utf8) {
//                        print("Converted string: \(string)", crc)
                        if string == "0\0" {
                            self.sendString(toPeripheral: peripheral, message: "a")
                        }
//
//                        let targetUUID1 = CBUUID(string: "e1c800b4-695b-4747-9256-6d22fd869f5b")
//                        if characteristic.uuid == targetUUID1 {
//                            return
//                        }
//
//                        if string == crc + "\0" {
                        if let value = characteristic.value {
                            if let responseString = String(data: value, encoding: .utf8) {
                                if let intValue = Int(responseString.dropLast()) {
                                    print(intValue, "yyyy")
                                    if intValue - 1000 > 0{
                                        NotificationCenter.default.post(name: NSNotification.Name("didReceiveResponse"), object: nil, userInfo: ["response": "сережа поц осталось пакетов высрать " +  String(self.packets.count - self.currentPacketIndex)])
                                        self.handlePacketResponse(intValue - 1000)
                                    }
                                } else {
                                   
                                    print("Received value is not greater than 1000")
                                }
                            } else {
                                print("Unable to decode data to a string")
                            }
                        } else {
                            print("No value received or unable to decode data")
                        }

//                        }
//                        if string == crc + "\0" || string == "0\0" {
//                        } else {
//                            if self.selectedDev != nil {
//                                self.centralManager.cancelPeripheralConnection(self.selectedDev!)
//                            }
                        
                        
                    } else {
                        print("Failed to convert Data to String")
                    }
                }
            }
        }
    }
    
    // MARK: - Методы перепрошивки аудио
    
    func startUpdate(audioNumber: Int) {
        guard let updateCharacteristic = updateCharacteristic else {
            print("Характеристика для обновления не найдена.")
            return
        }
        
        let startCommand = "a\(formatCRC32ToMAC(crc32: crc32Mac))\(audioNumber)".data(using: .utf8)!
        print("a\(String(describing: formatCRC32ToMAC(crc32: crc32Mac)))\(audioNumber)")
        selectedDev?.writeValue(startCommand, for: updateCharacteristic, type: .withResponse)
    }
    
    func sendAudioPacket(packet: Data) {
        guard let updateCharacteristic = updateCharacteristic else {
            print("Характеристика для обновления не найдена.")
            return
        }
        
        var packetString = "b\(formatCRC32ToMAC(crc32: crc32Mac))" + packet.base64EncodedString()
        if packetString.count < 128 {
            packetString.append(String(repeating: "0", count: 128 - packetString.count))
        }
        
        guard let packetData = packetString.data(using: .utf8) else { return }
        
        selectedDev?.writeValue(packetData, for: updateCharacteristic, type: .withResponse)
    }
    
    func finishUpdate() {
        guard let updateCharacteristic = updateCharacteristic else {
            print("Характеристика для обновления не найдена.")
            return
        }
        
        let finishCommand = "c\(formatCRC32ToMAC(crc32: crc32Mac))".data(using: .utf8)!
        selectedDev?.writeValue(finishCommand, for: updateCharacteristic, type: .withResponse)
    }
    
    // MARK: - CBPeripheralManagerDelegate
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            print("Peripheral manager is powered on")
        } else {
            print("Peripheral manager is not powered on")
        }
    }
    
    // MARK: - CBPeripheralDelegate
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        print("Peripheral did modify services: \(invalidatedServices)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateName name: String?) {
        print("Peripheral did update name: \(name ?? "Unknown")")
    }
    
    func sendString(toPeripheral peripheral: CBPeripheral, message: String) {
        selectedDev = peripheral
        
        if selectedDev?.state != .connected {
            centralManager.connect(peripheral)
        }
        
        let crc = calculateMACCRC32(macAddress: convertUUIDTo12Format(UIDevice.current.identifierForVendor!))
        
        if let readChar = crc32Char {
            readCharacteristic { value in
                if let readValue = value {
                    let data = readValue
                    if let string = String(data: data, encoding: .utf8) {
                        if string == crc + "\0" || string == "0\0" {
                            self.performSendString(message: message)
                            print("Nice crc")
                        } else {
                            if self.selectedDev != nil {
                                self.centralManager.cancelPeripheralConnection(self.selectedDev!)
                            }
                        }
                    } else {
                        print("Failed to convert Data to String")
                    }
                }
            }
        }
    }
    
    func sendpause() {
        if selectedDev == nil {
            return
        }
        if selectedDev?.state != .connected {
            centralManager.connect(selectedDev!)
        }
        
        let crc = calculateMACCRC32(macAddress: convertUUIDTo12Format(UIDevice.current.identifierForVendor!))
        
        if let readChar = crc32Char {
            readCharacteristic { value in
                if let readValue = value {
                    let data = readValue
                    if let string = String(data: data, encoding: .utf8) {
                        print("Converted string: \(string)", crc)
                        if string == crc + "\0" {
                            self.readCharacteristicPlay { bool in
                                if bool == true {
                                    self.sendString(toPeripheral: self.selectedDev!, message: "e")
                                } else {
                                    
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func readCharacteristic(completion: @escaping (Data?) -> Void) {
        selectedDev?.readValue(for: crc32Char!)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0) {
            completion(self.crc32Char!.value)
        }
    }
    
    private func readCharacteristicPlay(completion: @escaping (Bool) -> Void) {
        selectedDev?.readValue(for: isPlaying!)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0) {
            completion((String(data: self.isPlaying!.value!, encoding: .utf8) != nil))
        }
    }
    
    private func performSendString(message: String) {
        let fullMessage = message + convertUUIDTo12Format(UIDevice.current.identifierForVendor!)
        if let data = fullMessage.data(using: .utf8) {
            selectedDev?.writeValue(data, for: writeChar!, type: .withResponse)
        }
    }
    
    func convertUUIDTo12Format(_ uuid: UUID) -> String {
        let uuidString = uuid.uuidString.replacingOccurrences(of: "-", with: "").prefix(12)
        var result = ""
        for (index, char) in uuidString.enumerated() {
            result.append(char)
            if index % 2 == 1 && index < 11 {
                result.append(":")
            }
        }
        let mac = result
        let crc32 = calculateMACCRC32(macAddress: mac)
        crc32Mac = crc32
        return result
    }
    
    func calculateMACCRC32(macAddress: String) -> String {
        let cleanMacAddress = macAddress.replacingOccurrences(of: ":", with: "")
        let polynomial: UInt32 = 0xEDB88320
        var crc: UInt32 = 0xFFFFFFFF
        let hexBytes = stride(from: 0, to: cleanMacAddress.count, by: 2).compactMap { index -> UInt8? in
            let start = cleanMacAddress.index(cleanMacAddress.startIndex, offsetBy: index)
            let end = cleanMacAddress.index(start, offsetBy: 2)
            let byteString = String(cleanMacAddress[start..<end])
            return UInt8(byteString, radix: 16)
        }
        
        for byte in hexBytes {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                if crc & 1 == 1 {
                    crc = (crc >> 1) ^ polynomial
                } else {
                    crc >>= 1
                }
            }
        }
        
        crc ^= 0xFFFFFFFF
        return String(format: "%08X", crc)
    }
    
    func handleResponse(response: String) -> String {
        switch response {
        case "0\0":
            print("BLE_CON")
            return "BLE_CON"
        case "200\0":
            print("CONNECT_OK")
            return "CONNECT_OK"
        case "400\0":
            print("DEVICE_BUSY_ERR")
            return "DEVICE_BUSY_ERR"
        case "401\0":
            print("INVALID_MAC_ERR")
            return "INVALID_MAC_ERR"
        case "402\0":
            print("CONNECT_ERR")
            return "CONNECT_ERR"
        case "403\0":
            print("DISCONNECT_ERR")
            return "DISCONNECT_ERR"
        case "201\0":
            print("DISCONNECT_OK")
            return "DISCONNECT_OK"
        case "404\0":
            print("AUDIO_ALREADY_START")
            return "AUDIO_ALREADY_START"
        case "202\0":
            print("AUDIO_START_OK")
            return "AUDIO_START_OK"
        case "405\0":
            print("AUDIO_START_ERR")
            return "AUDIO_START_ERR"
        case "406\0":
            print("AUDIO_ALREADY_STOP")
            return "AUDIO_ALREADY_STOP"
        case "203\0":
            print("AUDIO_STOP_OK")
            return "AUDIO_STOP_OK"
        case "407\0":
            print("AUDIO_STOP_ERR")
            return "AUDIO_STOP_ERR"
        case "408\0":
            print("AUDIO_ALREADY_PAUSE")
            return "AUDIO_ALREADY_PAUSE"
        case "204\0":
            print("AUDIO_PAUSE_OK")
            return "AUDIO_PAUSE_OK"
        case "409\0":
            print("AUDIO_PAUSE_ERR")
            return "AUDIO_PAUSE_ERR"
        case "205\0":
            print("AUDIO_LOUDER_OK")
            return "AUDIO_LOUDER_OK"
        case "206\0":
            print("AUDIO_QUIET_OK")
            return "AUDIO_QUIET_OK"
        case "100\0":
            print("DEFAULT")
            return "DEFAULT"
        case "410\0":
            print("WRONG_MESSAGE")
            return "WRONG_MESSAGE"
        case "411\0":
            print("DEVICE_ISNT_CONNECTED")
            return "DEVICE_ISNT_CONNECTED"
        case "412\0":
            print("DEVICE_ALREADY_CONNECTED")
            return "DEVICE_ALREADY_CONNECTED"
        case "500\0":
            print("DISCONNECT_REQ")
            return "DISCONNECT_REQ"
        case "501\0":
            print("CONTINUE_SESSION_SUC")
            return "CONTINUE_SESSION_SUC"
        case "502\0":
            print("SESSION_TIMEOUT_DISK")
            return "SESSION_TIMEOUT_DISK"
        default:
            print("Unknown response: \(response)")
            return "Unknown response: \(response)"
        }
    }
    
    // MARK: - Выбор файла
    
    func presentDocumentPicker(in viewController: UIViewController) {
        let documentPicker = UIDocumentPickerViewController(documentTypes: [kUTTypeWaveformAudio as String], in: .import)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        viewController.present(documentPicker, animated: true, completion: nil)
    }
    
    // MARK: - UIDocumentPickerDelegate
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            return
        }
        
        do {
            let audioData = try Data(contentsOf: url)
            let packetSize = 128
            var packetNumber = 0
            for chunk in stride(from: 0, to: audioData.count, by: packetSize) {
                let end = min(chunk + packetSize, audioData.count)
                let packet = audioData.subdata(in: chunk..<end)
                sendAudioPacket(packet: packet)
                packetNumber += 1
            }
            finishUpdate()
        } catch {
            print("Ошибка чтения файла: \(error)")
        }
    }


    func formatCRC32ToMAC(crc32: String) -> String {
        // Убедитесь, что CRC32 имеет длину 8 символов
        let fullMessage = convertUUIDTo12Format(UIDevice.current.identifierForVendor!)
        
        return fullMessage
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("Выбор файла был отменен.")
    }
    
    // MARK: - Вспомогательные методы
    
    private func showAlert(response: String) {
        
        if let topController = UIApplication.shared.keyWindow?.rootViewController {
            let alert = UIAlertController(title: "Ответ", message: response, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            topController.present(alert, animated: true, completion: nil)
        }
    }
}

// MARK: - Data extension for hex encoding

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02X", $0) }.joined()
    }
}
