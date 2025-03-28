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
    var adminReadchar: CBCharacteristic?
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    
    // … остальные свойства
    var isUpdating = false
    var shouldStopUpdate = false
    var retryCounter = 0
    let maxRetries = 5
    
    
    
    // … остальные свойства
    
    
    // Пример обновлённого метода отправки пакета:
    // Функция для отправки текущего пакета
    func sendCurrentPacket() {
        guard !shouldStopUpdate else {
            print("Обновление остановлено. Цикл отправки прерван.")
            isUpdating = false
            return
        }
        
        guard let updateCharacteristic = updateCharacteristic else {
            print("Характеристика для обновления не найдена.")
            return
        }
        let index = Int(String(data: adminReadchar!.value!, encoding: .utf8)!.dropLast())
        print(currentPacketIndex, Int(String(data: adminReadchar!.value!, encoding: .utf8)!.dropLast()), "indexes")
        // Если пакеты закончились, завершаем обновление.
        if currentPacketIndex == Int(String(data: adminReadchar!.value!, encoding: .utf8)!.dropLast()){
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.002) {
                self.sendCurrentPacket()
                return
            }
        }
        guard currentPacketIndex - 1000 < packets.count else {
            finishUpdate()
            return
        }
        
        let packet = packets[currentPacketIndex - 1000]
        let crcString = formatCRC32ToMAC(crc32: crc32Mac)
        
        // Формируем префикс: "b" + crcString
        guard let prefixData = ("b" + crcString).data(using: .utf8) else {
            print("Ошибка при преобразовании префикса в данные.")
            return
        }
        
        // Преобразуем currentPacketIndex в 2-байтовое представление (big endian).
        var packetIndex = UInt16(currentPacketIndex).bigEndian
        let indexData = Data(bytes: &packetIndex, count: MemoryLayout<UInt16>.size)
        
        // Объединяем данные: префикс, номер пакета и сам пакет.
        var fullPacketData = Data()
        fullPacketData.append(prefixData)
        fullPacketData.append(indexData)
        fullPacketData.append(packet)
        
        // Отправляем данные
        selectedDev?.writeValue(fullPacketData, for: updateCharacteristic, type: .withResponse)
        
        // Планируем отправку следующего пакета через 20 мс, только если обновление активно.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.002) { [weak self] in
            guard let self = self else { return }
            if self.isUpdating && !self.shouldStopUpdate {
                // Если ещё не достигнут конец, или же повторная попытка не исчерпана:
                if self.currentPacketIndex - 1000 < self.packets.count {
                    self.currentPacketIndex = index! + 1
                    
                    
                    self.sendCurrentPacket()
                } else {
                    self.finishUpdate()
                }
            } else {
                print("Отправка следующего пакета отменена, так как обновление остановлено.")
            }
        }
    }
    
    // Делегатский метод, который вызывается после завершения записи
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error writing value for characteristic \(characteristic.uuid): \(error.localizedDescription)")
            // Можно здесь реализовать логику повторной попытки или завершения обновления
            return
        }
        
        print("Successfully wrote value for characteristic \(characteristic.uuid)")
        
        // После успешной записи можно, если требуется, прочитать значение для характеристики
        // peripheral.readValue(for: characteristic)
        
        // Обновляем индекс пакета и уведомляем о прогрессе
        //        currentPacketIndex += 1
        
    }
    
    
    // Обновлённый обработчик ответа.
    // Например, если устройство возвращает число, которое говорит о проблеме — продолжить с этого номера.
    func handlePacketResponse(_ receivedPacketNumber: Int) {
        // Если значение равно тому же, что уже отправлялось,
        // увеличиваем счетчик ошибок; иначе – сбрасываем его.
        if receivedPacketNumber == currentPacketIndex {
            retryCounter += 1
            if retryCounter >= maxRetries {
                shouldStopUpdate = true
                print("Превышено максимальное число повторных ошибок (\(retryCounter)), обновление остановлено.")
                return
            }
        } else {
            retryCounter = 0
//            currentPacketIndex = receivedPacketNumber
        }
        
        // Продолжаем, если есть еще пакеты.
        if currentPacketIndex < packets.count {
            sendCurrentPacket()
        } else {
            finishUpdate()
        }
    }
    
    // Пример метод start/update
    func startUpdate(audioNumber: Int) {
        guard let _ = updateCharacteristic else {
            print("Характеристика для обновления не найдена.")
            return
        }
        // Инициализация необходимых переменных для обновления.
        shouldStopUpdate = false
        
        currentPacketIndex = 1000
        retryCounter = 0
        
        
        // Отправляем команду старта обновления (например, "a" + crc + audioNumber)
        let startCommand = "a\(formatCRC32ToMAC(crc32: crc32Mac))\(audioNumber)".data(using: .utf8)!
        selectedDev?.writeValue(startCommand, for: updateCharacteristic!, type: .withResponse)
        
        // Возможно, здесь можно запустить отправку первого пакета после подтверждения устройства.
        // Или же вызвать sendCurrentPacket() напрямую, если устройство готово.
    }
    func deleteUpdate(audioNumber: Int) {
        guard let _ = updateCharacteristic else {
            print("Характеристика для обновления не найдена.")
            return
        }
        // Инициализация необходимых переменных для обновления.
        shouldStopUpdate = false
        //        isUpdating = true
        currentPacketIndex = 1000
        retryCounter = 0
        
        
        // Отправляем команду старта обновления (например, "a" + crc + audioNumber)
        let startCommand = "x\(formatCRC32ToMAC(crc32: crc32Mac))\(audioNumber)".data(using: .utf8)!
        selectedDev?.writeValue(startCommand, for: updateCharacteristic!, type: .withResponse)
        
        // Возможно, здесь можно запустить отправку первого пакета после подтверждения устройства.
        // Или же вызвать sendCurrentPacket() напрямую, если устройство готово.
    }
    
    
    
    
    func playAudio(){
        
    }
    func removeAll(){
        guard let _ = updateCharacteristic else {
            print("Характеристика для обновления не найдена.")
            return
        }
        let startCommand = "z\(formatCRC32ToMAC(crc32: crc32Mac))".data(using: .utf8)!
        selectedDev?.writeValue(startCommand, for: updateCharacteristic!, type: .withResponse)
    }
    func reset(){
        guard let _ = updateCharacteristic else {
            print("Характеристика для обновления не найдена.")
            return
        }
        let startCommand = "f\(formatCRC32ToMAC(crc32: crc32Mac))".data(using: .utf8)!
        selectedDev?.writeValue(startCommand, for: updateCharacteristic!, type: .withResponse)
    }
    func fetchAudio(){
        guard let _ = updateCharacteristic else {
            print("Характеристика для обновления не найдена.")
            return
        }
        let startCommand = "w\(formatCRC32ToMAC(crc32: crc32Mac))".data(using: .utf8)!
        selectedDev?.writeValue(startCommand, for: updateCharacteristic!, type: .withResponse)
    }
    func fetchMemory(){
        guard let _ = updateCharacteristic else {
            print("Характеристика для обновления не найдена.")
            return
        }
        let startCommand = "h\(formatCRC32ToMAC(crc32: crc32Mac))".data(using: .utf8)!
        selectedDev?.writeValue(startCommand, for: updateCharacteristic!, type: .withResponse)
    }
    func finishUpdate() {
        
        // Отправляем команду завершения (например, "c" + crc)
        guard let updateCharacteristic = updateCharacteristic else {
            print("Характеристика для обновления не найдена.")
            return
        }
        
        let crc32Result = calculateCombinedCRC32ByMerging(for: packets)
        
        var packetIndex = crc32Result.bigEndian
        let indexData = Data(bytes: &packetIndex, count: MemoryLayout<UInt32>.size)
        print("1crc32:", packetIndex)
        NotificationCenter.default.post(name: NSNotification.Name("didReceiveResponse"), object: nil, userInfo: ["response": "через 2 сек"])
        var finishCommand = "c\(formatCRC32ToMAC(crc32: crc32Mac))".data(using: .utf8)!
        finishCommand.append(indexData)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            
            self.selectedDev?.writeValue(finishCommand, for: updateCharacteristic, type: .withResponse)
            NotificationCenter.default.post(name: NSNotification.Name("didReceiveResponse"), object: nil, userInfo: ["response": "crc " + String(packetIndex)])
        }
        print("Обновление завершено.")
        isUpdating = false
    }
    
    // Остальные методы остаются без изменений...
    
    
    // Остальные методы остаются без изменений...
    
    
    
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
        NotificationCenter.default.post(name: NSNotification.Name("didReceiveResponse"), object: nil, userInfo: ["response":"connected" + " "])
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        NotificationCenter.default.post(name: NSNotification.Name("connect"), object: nil, userInfo: ["response":"connected"])
        selectedDev = peripheral
        isUpdating = false
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to \(peripheral.name ?? "Unknown Device"): \(error?.localizedDescription ?? "Unknown Error")")
        NotificationCenter.default.post(name: NSNotification.Name("connect"), object: nil, userInfo: ["response":"disconnected"])
        removeInactiveDevices()
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from \(peripheral.name ?? "Unknown Device")")
        selectedDev = nil
        isUpdating = false
        NotificationCenter.default.post(name: NSNotification.Name("didDisconnectPeripheral"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("didReceiveResponse"), object: nil, userInfo: ["response":"disconnected" + " "])
        NotificationCenter.default.post(name: NSNotification.Name("connect"), object: nil, userInfo: ["response":"disconnected"])
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
                } else if characteristic.uuid == CBUUID(string: "E1C800B4-695B-4747-9256-6D22FD869F5D") {
                    peripheral.setNotifyValue(true, for: characteristic)
                    adminReadchar = characteristic
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
            //            NotificationCenter.default.post(name: NSNotification.Name("didReceiveResponse"), object: nil, userInfo: ["response":"CRCCcheckAnswer" + " " +  (String(data: characteristic.value!, encoding: .utf8) ?? "")])
            
            NotificationCenter.default.post(name: NSNotification.Name("crc"), object: nil, userInfo: ["response":"" + " " +  (String(data: characteristic.value!, encoding: .utf8) ?? "")])
            return
        }
        let targetUUID1 = CBUUID(string: "e1c800b4-695b-4747-9256-6d22fd869f5b")
        if characteristic.uuid == targetUUID1 {
            NotificationCenter.default.post(name: NSNotification.Name("isplay"), object: nil, userInfo: ["response":"" + " " +  (String(data: characteristic.value!, encoding: .utf8) ?? "")])
            //            if  String(data: isPlaying!.value!, encoding: .utf8) == "0\0" && String(data: self.readchar!.value!, encoding: .utf8) == "300\0"{
            //                self.sendString(toPeripheral: peripheral, message: "a")
            //            }
        }
        let targetUUID2 = CBUUID(string: "e1c800b4-695b-4747-9256-6d22fd869f58")
        if characteristic.uuid == targetUUID2 {
            NotificationCenter.default.post(name: NSNotification.Name("answer"), object: nil, userInfo: ["response":"" + " " +  (String(data: characteristic.value!, encoding: .utf8) ?? "")])
            NotificationCenter.default.post(name: NSNotification.Name("didReceiveResponse"), object: nil, userInfo: ["response":"" + " " +  (String(data: characteristic.value!, encoding: .utf8)?.dropLast() ?? "") + handleResponse(response: (String(data: characteristic.value!, encoding: .utf8) ?? ""))])
        }
        
        
        //        if String(data: characteristic.value!, encoding: .utf8) == "300\0" {
        //            DispatchQueue.main.asyncAfter(deadline: .now() + 0.0) {
        //                self.sendString(toPeripheral: peripheral, message: "a")
        //            }
        //        }
        if String(data: characteristic.value!, encoding: .utf8) == "300\0" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.0) {
                self.sendString(toPeripheral: peripheral, message: "a")
            }
        }
        print(String(data: characteristic.value!, encoding: .utf8), "string")
        if isPlaying?.value == nil{
            return
        }
        
        
        
        //        if String(data: characteristic.value!, encoding: .utf8) == "200\0" {
        //            DispatchQueue.main.asyncAfter(deadline: .now() + 0.0) {
        //                self.sendString(toPeripheral: peripheral, message: "x")
        //            }
        //        }
        if String(data: characteristic.value!, encoding: .utf8) == "201\0" {
            
            self.centralManager.cancelPeripheralConnection(peripheral)
            
            //                                    self.sendString(toPeripheral: peripheral, message: "x")
        }
        print(String(data: characteristic.value!, encoding: .utf8))
        
        if crc32Char != nil {
            readCharacteristic { [self] value in
                print(characteristic.uuid, "uuid")
                if let readValue = value {
                    
                    let data = readValue
                    
                    if let string = String(data: data, encoding: .utf8) {
                        if characteristic.uuid.uuidString == "E1C800B4-695B-4747-9256-6D22FD869F58"{
                            if string == "0\0"{
                                self.sendString(toPeripheral: peripheral, message: "a")
                            }
                            if string == "201\0" {
                                self.centralManager.cancelPeripheralConnection(peripheral)
                            }
                            if let value = characteristic.value {
                                if let responseString = String(data: value, encoding: .utf8) {
                                    if string == "201\0" {
                                        self.centralManager.cancelPeripheralConnection(peripheral)
                                    }
                                } else {
                                    print("Unable to decode data to a string")
                                }
                            } else {
                                print("No value received or unable to decode data")
                            }
                        }else{
//                            if !self.isUpdating{
//                                return
//                            }
                            if let value = characteristic.value {
                                if let responseString = String(data: value, encoding: .utf8) {
                                    if let intValue = Int(responseString.dropLast()) {
                                        print(intValue, "yyyy")
                                        if intValue - 1000 >= 0{
                                            NotificationCenter.default.post(name: NSNotification.Name("didReceiveResponse"), object: nil, userInfo: ["response": "осталось пакетов " +  String(self.packets.count - intValue + 1000)])
                                          
                                            let progress = Float(intValue - 1000) / Float(packets.count)
                                            NotificationCenter.default.post(name: Notification.Name("updateProgress"),
                                                                            object: nil,
                                                                            userInfo: ["progress": progress])
                                        }
                                    } else {
                                        
                                        print("Received value is not greater than 1000")
                                    }
                                }
                            }
                        }
                    } else {
                        print("Failed to convert Data to String")
                    }
                }
            }
        }
    }
    
    // MARK: - Методы перепрошивки аудио
    
    
    
    func sendAudioPacket(packet: Data) {
        guard let updateCharacteristic = updateCharacteristic else {
            print("Характеристика для обновления не найдена.")
            return
        }
        
        var packetString = "b\(formatCRC32ToMAC(crc32: crc32Mac))" + packet.base64EncodedString()
        
        
        guard let packetData = packetString.data(using: .utf8) else { return }
        
        selectedDev?.writeValue(packetData, for: updateCharacteristic, type: .withResponse)
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
                else{
                    self.sendString(toPeripheral: peripheral, message: message)
                }
            }
           
        } else{
//            self.sendString(toPeripheral: peripheral, message: message)
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
        case "300\0":
            print("READY")
            return "READY"
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
        case "207\0":
            print("UPLOAD_START_OK")
            return "UPLOAD_START_OK"
        case "208\0":
            print("UPLOAD_END_OK")
            isUpdating = false
            return "UPLOAD_END_OK"
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
        case "415\0":
            isUpdating = false
            print("DEVICE_fail")
            return "DEVICE_fail"
        case "500\0":
            print("DISCONNECT_REQ")
            return "DISCONNECT_REQ"
        case "501\0":
            print("CONTINUE_SESSION_SUC")
            return "CONTINUE_SESSION_SUC"
        case "502\0":
            print("SESSION_TIMEOUT_DISK")
            return "SESSION_TIMEOUT_DISK"
        case "209\0":
            print("DELETE_OK")
            return "DELETE_OK"
        case "416\0":
            print("DELETE_ERROR")
            return "DELETE_ERROR"
        default:
            print(": \(response)")
            return ": \(response)"
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
            let packetSize = 200
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
    
    
    
    
    
    
    
    
    // Таблица CRC32 (256 элементов)
    let crc32Table: [UInt32] = [
        0x00000000, 0x77073096, 0xEE0E612C, 0x990951BA,
        0x076DC419, 0x706AF48F, 0xE963A535, 0x9E6495A3,
        0x0EDB8832, 0x79DCB8A4, 0xE0D5E91E, 0x97D2D988,
        0x09B64C2B, 0x7EB17CBD, 0xE7B82D07, 0x90BF1D91,
        0x1DB71064, 0x6AB020F2, 0xF3B97148, 0x84BE41DE,
        0x1ADAD47D, 0x6DDDE4EB, 0xF4D4B551, 0x83D385C7,
        0x136C9856, 0x646BA8C0, 0xFD62F97A, 0x8A65C9EC,
        0x14015C4F, 0x63066CD9, 0xFA0F3D63, 0x8D080DF5,
        0x3B6E20C8, 0x4C69105E, 0xD56041E4, 0xA2677172,
        0x3C03E4D1, 0x4B04D447, 0xD20D85FD, 0xA50AB56B,
        0x35B5A8FA, 0x42B2986C, 0xDBBBC9D6, 0xACBCF940,
        0x32D86CE3, 0x45DF5C75, 0xDCD60DCF, 0xABD13D59,
        0x26D930AC, 0x51DE003A, 0xC8D75180, 0xBFD06116,
        0x21B4F4B5, 0x56B3C423, 0xCFBA9599, 0xB8BDA50F,
        0x2802B89E, 0x5F058808, 0xC60CD9B2, 0xB10BE924,
        0x2F6F7C87, 0x58684C11, 0xC1611DAB, 0xB6662D3D,
        0x76DC4190, 0x01DB7106, 0x98D220BC, 0xEFD5102A,
        0x71B18589, 0x06B6B51F, 0x9FBFE4A5, 0xE8B8D433,
        0x7807C9A2, 0x0F00F934, 0x9609A88E, 0xE10E9818,
        0x7F6A0DBB, 0x086D3D2D, 0x91646C97, 0xE6635C01,
        0x6B6B51F4, 0x1C6C6162, 0x856530D8, 0xF262004E,
        0x6C0695ED, 0x1B01A57B, 0x8208F4C1, 0xF50FC457,
        0x65B0D9C6, 0x12B7E950, 0x8BBEB8EA, 0xFCB9887C,
        0x62DD1DDF, 0x15DA2D49, 0x8CD37CF3, 0xFBD44C65,
        0x4DB26158, 0x3AB551CE, 0xA3BC0074, 0xD4BB30E2,
        0x4ADFA541, 0x3DD895D7, 0xA4D1C46D, 0xD3D6F4FB,
        0x4369E96A, 0x346ED9FC, 0xAD678846, 0xDA60B8D0,
        0x44042D73, 0x33031DE5, 0xAA0A4C5F, 0xDD0D7CC9,
        0x5005713C, 0x270241AA, 0xBE0B1010, 0xC90C2086,
        0x5768B525, 0x206F85B3, 0xB966D409, 0xCE61E49F,
        0x5EDEF90E, 0x29D9C998, 0xB0D09822, 0xC7D7A8B4,
        0x59B33D17, 0x2EB40D81, 0xB7BD5C3B, 0xC0BA6CAD,
        0xEDB88320, 0x9ABFB3B6, 0x03B6E20C, 0x74B1D29A,
        0xEAD54739, 0x9DD277AF, 0x04DB2615, 0x73DC1683,
        0xE3630B12, 0x94643B84, 0x0D6D6A3E, 0x7A6A5AA8,
        0xE40ECF0B, 0x9309FF9D, 0x0A00AE27, 0x7D079EB1,
        0xF00F9344, 0x8708A3D2, 0x1E01F268, 0x6906C2FE,
        0xF762575D, 0x806567CB, 0x196C3671, 0x6E6B06E7,
        0xFED41B76, 0x89D32BE0, 0x10DA7A5A, 0x67DD4ACC,
        0xF9B9DF6F, 0x8EBEEFF9, 0x17B7BE43, 0x60B08ED5,
        0xD6D6A3E8, 0xA1D1937E, 0x38D8C2C4, 0x4FDFF252,
        0xD1BB67F1, 0xA6BC5767, 0x3FB506DD, 0x48B2364B,
        0xD80D2BDA, 0xAF0A1B4C, 0x36034AF6, 0x41047A60,
        0xDF60EFC3, 0xA867DF55, 0x316E8EEF, 0x4669BE79,
        0xCB61B38C, 0xBC66831A, 0x256FD2A0, 0x5268E236,
        0xCC0C7795, 0xBB0B4703, 0x220216B9, 0x5505262F,
        0xC5BA3BBE, 0xB2BD0B28, 0x2BB45A92, 0x5CB36A04,
        0xC2D7FFA7, 0xB5D0CF31, 0x2CD99E8B, 0x5BDEAE1D,
        0x9B64C2B0, 0xEC63F226, 0x756AA39C, 0x026D930A,
        0x9C0906A9, 0xEB0E363F, 0x72076785, 0x05005713,
        0x95BF4A82, 0xE2B87A14, 0x7BB12BAE, 0x0CB61B38,
        0x92D28E9B, 0xE5D5BE0D, 0x7CDCEFB7, 0x0BDBDF21,
        0x86D3D2D4, 0xF1D4E242, 0x68DDB3F8, 0x1FDA836E,
        0x81BE16CD, 0xF6B9265B, 0x6FB077E1, 0x18B74777,
        0x88085AE6, 0xFF0F6A70, 0x66063BCA, 0x11010B5C,
        0x8F659EFF, 0xF862AE69, 0x616BFFD3, 0x166CCF45,
        0xA00AE278, 0xD70DD2EE, 0x4E048354, 0x3903B3C2,
        0xA7672661, 0xD06016F7, 0x4969474D, 0x3E6E77DB,
        0xAED16A4A, 0xD9D65ADC, 0x40DF0B66, 0x37D83BF0,
        0xA9BCAE53, 0xDEBB9EC5, 0x47B2CF7F, 0x30B5FFE9,
        0xBDBDF21C, 0xCABAC28A, 0x53B39330, 0x24B4A3A6,
        0xBAD03605, 0xCDD70693, 0x54DE5729, 0x23D967BF,
        0xB3667A2E, 0xC4614AB8, 0x5D681B02, 0x2A6F2B94,
        0xB40BBE37, 0xC30C8EA1, 0x5A05DF1B, 0x2D02EF8D
    ]
    
    /// Функция для вычисления CRC32, объединяя все данные в один объект Data.
    func calculateCombinedCRC32ByMerging(for dataChunks: [Data]) -> UInt32 {
        // Вычисляем общий объём данных для оптимальной инициализации.
        let totalLength = dataChunks.reduce(0) { $0 + $1.count }
        
        // Объединяем данные в один поток.
        var mergedData = Data(capacity: totalLength)
        dataChunks.forEach { mergedData.append($0) }
        
        var crc: UInt32 = 0xFFFFFFFF
        for byte in mergedData {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ crc32Table[index]
        }
        
        return ~crc
    }
    
    // Пример использования:
    
    
    // Пример использования:
    
    
    
    
}

// MARK: - Data extension for hex encoding

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02X", $0) }.joined()
    }
}
