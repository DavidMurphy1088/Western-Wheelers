import SwiftUI
import Combine
import os.log
import CoreBluetooth
//https://medium.com/@shu223/core-bluetooth-snippets-with-swift-9be8524600b2

class BTDelegate : NSObject, CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        print("peripheralManagerDidUpdateState \(peripheral.state.rawValue)")
    }
    
//    func peripheralManagerDidStartAdvertising() {
//        print("Started advertising")
//    }
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("Failed… error: \(error)")
            return
        }
        print("Started advertising")
    }
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
    //func peripheralManager(peripheral: CBPeripheralManager, didAddService service: CBService, error: Error?) {
        if let error = error {
            print("error: \(error)")
            return
        }

        print("Added service")
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, didReceiveReadRequest request: CBATTRequest) {
//        if request.characteristic.UUID.isEqual(characteristic.UUID)
//        {
//            // Set the correspondent characteristic's value
//            // to the request
//            request.value = characteristic.value
//
//            // Respond to the request
//            peripheralManager.respondToRequest(
//                request,
//                withResult: .Success)
//        }
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, didReceiveWriteRequests requests: [CBATTRequest]) {
//        for request in requests
//        {
//            if request.characteristic.UUID.isEqual(characteristic.UUID)
//            {
//                // Set the request's value
//                // to the correspondent characteristic
//                characteristic.value = request.value
//            }
//        }
//        peripheralManager.respondToRequest(requests[0], withResult: .Success)
    }
}

class BTService  {
    var delegate = BTDelegate()
    var manager:CBPeripheralManager!

    func start() {
        print("BT Service starting")
        manager = CBPeripheralManager(delegate: delegate, queue: nil)
        
        let advertisementData = [CBAdvertisementDataLocalNameKey: "WW Ride Sign In"]
        manager.startAdvertising(advertisementData)
        
        let kServiceUUID = "5b68339e-ae7b-452d-9687-00822b648f80"
        let serviceUUID = CBUUID(string: kServiceUUID)
        let service = CBMutableService(type: serviceUUID, primary: true)
        //create service characteristics
        let kCharacteristicUUID = "51776c26-6080-4377-9336-025999664b74"
        let characteristicUUID = CBUUID(string: kCharacteristicUUID)
        let properties: CBCharacteristicProperties = [.notify, .read, .write]
        let permissions: CBAttributePermissions = [.readable, .writeable]
        let characteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: properties,
            value: nil,
            permissions: permissions)

        service.characteristics = [characteristic]
        manager.add(service)
    }
    
    func stop() {
        print("BT Service stopping")
        manager.stopAdvertising()
    }
    
}

struct SignedInView: View {
    var bt = BTService()
    var body: some View {
        VStack {
            Text("Signed in")
        }
        .onAppear() {
            bt.start()
        }
        .onDisappear() {
            bt.stop()
        }
    }
}
