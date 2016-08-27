//
//  MutableCharacteristicTests.swift
//  BlueCapKit
//
//  Created by Troy Stribling on 3/24/15.
//  Copyright (c) 2015 Troy Stribling. The MIT License (MIT).
//

import UIKit
import XCTest
import CoreBluetooth
import CoreLocation
@testable import BlueCapKit

// MARK: - MutableCharacteristicTests -
class MutableCharacteristicTests: XCTestCase {

    let immediateContext = ImmediateContext()

    override func setUp() {
        GnosusProfiles.create()
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func addCharacteristics(_ onSuccess: @escaping (_ mock: CBPeripheralManagerMock, _ peripheralManager: PeripheralManagerUT, _ service: MutableService) -> Void) {
        let (mock, peripheralManager) = createPeripheralManager(false, state: .poweredOn)
        let services = createPeripheralManagerServices(peripheralManager)
        services[0].characteristics = services[0].profile.characteristics.map { profile in
            let characteristic = CBMutableCharacteristicMock(UUID:profile.UUID, properties: profile.properties, permissions: profile.permissions, isNotifying: false)
            return MutableCharacteristic(cbMutableCharacteristic: characteristic, profile: profile)
        }
        let future = peripheralManager.addService(services[0])
        future.onSuccess(self.immediateContext) {
            mock.isAdvertising = true
            onSuccess(mock: mock, peripheralManager: peripheralManager, service: services[0])
        }
        future.onFailure(self.immediateContext) {error in
            XCTFail("onFailure called")
        }
        peripheralManager.didAddService(services[0].cbMutableService, error: nil)
    }

    // MARK: Add characteristics
    func testAddCharacteristics_WhenServiceAddWasSuccessfull_CompletesSuccessfully() {
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: MutableService) -> Void in
            let chracteristics = peripheralManager.characteristics.map { $0.UUID }
            XCTAssertEqual(chracteristics.count, 2, "characteristic count invalid")
            XCTAssert(chracteristics.contains(CBUUID(string: Gnosus.HelloWorldService.Greeting.UUID)), "characteristic uuid is invalid")
            XCTAssert(chracteristics.contains(CBUUID(string: Gnosus.HelloWorldService.UpdatePeriod.UUID)), "characteristic uuid is invalid")
        }
    }

    // MARK: Subscribe to charcteristic updates
    func testUpdateValueWithData_WithNoSubscribers_AddsUpdateToPengingQueue() {
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: MutableService) -> Void in
            let characteristic = peripheralManager.characteristics[0]
            XCTAssertFalse(characteristic.isUpdating, "isUpdating value invalid")
            XCTAssertEqual(characteristic.subscribers.count, 0, "characteristic has subscribers")
            XCTAssertFalse(characteristic.updateValueWithData("aa".dataFromHexString()), "updateValueWithData invalid return status")
            XCTAssertFalse(mock.updateValueCalled, "CBPeripheralManager#updateValue called")
            XCTAssertEqual(characteristic.pendingUpdates.count, 1, "pendingUpdates is invalid")
        }
    }

    func testUpdateValueWithData_WithSubscriber_IsSendingUpdates() {
        let centralMock = CBCentralMock(maximumUpdateValueLength: 20)
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: MutableService) -> Void in
            let characteristic = peripheralManager.characteristics[0]
            let value = "aa".dataFromHexString()
            peripheralManager.didSubscribeToCharacteristic(characteristic.cbMutableChracteristic, central: centralMock)
            XCTAssert(characteristic.isUpdating, "isUpdating value invalid")
            XCTAssert(characteristic.updateValueWithData(value), "updateValueWithData invalid return status")
            XCTAssert(mock.updateValueCalled, "CBPeripheralManager#updateValue not called")
            XCTAssertEqual(characteristic.value, value, "characteristic value is invalid")
            XCTAssertEqual(characteristic.subscribers.count, 1, "characteristic subscriber count invalid")
            XCTAssertEqual(characteristic.pendingUpdates.count, 0, "pendingUpdates is invalid")
        }
    }


    func testUpdateValueWithData_WithSubscribers_IsSendingUpdates() {
        let centralMock1 = CBCentralMock(maximumUpdateValueLength: 20)
        let centralMock2 = CBCentralMock(maximumUpdateValueLength: 20)
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: MutableService) -> Void in
            let characteristic = peripheralManager.characteristics[0]
            let value = "aa".dataFromHexString()
            peripheralManager.didSubscribeToCharacteristic(characteristic.cbMutableChracteristic, central: centralMock1)
            peripheralManager.didSubscribeToCharacteristic(characteristic.cbMutableChracteristic, central: centralMock2)
            let centrals = characteristic.subscribers
            let centralIDs = centrals.map { $0.identifier }
            XCTAssert(characteristic.isUpdating, "isUpdating value invalid")
            XCTAssert(characteristic.updateValueWithData(value), "updateValueWithData invalid return status")
            XCTAssertEqual(characteristic.value, value, "characteristic value is invalid")
            XCTAssert(mock.updateValueCalled, "CBPeripheralManager#updateValue not called")
            XCTAssertEqual(centrals.count, 2, "characteristic subscriber count invalid")
            XCTAssert(centralIDs.contains(centralMock1.identifier) as (UUID) as (UUID) as (UUID) as (UUID) as (UUID) as (UUID), "invalid central identifier")
            XCTAssert(centralIDs.contains(centralMock2.identifier) as (UUID) as (UUID) as (UUID) as (UUID) as (UUID) as (UUID), "invalid central identifier")
            XCTAssertEqual(characteristic.pendingUpdates.count, 0, "pendingUpdates is invalid")
        }
    }

    func testupdateValueWithData_WithSubscriberOnUnsubscribe_IsNotSendingUpdates() {
        let centralMock = CBCentralMock(maximumUpdateValueLength: 20)
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: MutableService) -> Void in
            let characteristic = peripheralManager.characteristics[0]
            let value = "aa".dataFromHexString()
            peripheralManager.didSubscribeToCharacteristic(characteristic.cbMutableChracteristic, central: centralMock)
            XCTAssertEqual(characteristic.subscribers.count, 1, "characteristic subscriber count invalid")
            peripheralManager.didUnsubscribeFromCharacteristic(characteristic.cbMutableChracteristic, central: centralMock)
            XCTAssertFalse(characteristic.isUpdating, "isUpdating value invalid")
            XCTAssertFalse(characteristic.updateValueWithData(value), "updateValueWithData invalid return status")
            XCTAssertEqual(characteristic.value, value, "characteristic value is invalid")
            XCTAssertFalse(mock.updateValueCalled, "CBPeripheralManager#updateValue called")
            XCTAssertEqual(characteristic.subscribers.count, 0, "characteristic subscriber count invalid")
            XCTAssertEqual(characteristic.pendingUpdates.count, 1, "pendingUpdates is invalid")
        }
    }

    func testupdateValueWithData_WithSubscribersWhenOneUnsubscribes_IsSendingUpdates() {
        let centralMock1 = CBCentralMock(maximumUpdateValueLength: 20)
        let centralMock2 = CBCentralMock(maximumUpdateValueLength: 20)
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: MutableService) -> Void in
            let characteristic = peripheralManager.characteristics[0]
            let value = "aa".dataFromHexString()
            peripheralManager.didSubscribeToCharacteristic(characteristic.cbMutableChracteristic, central: centralMock1)
            peripheralManager.didSubscribeToCharacteristic(characteristic.cbMutableChracteristic, central: centralMock2)
            XCTAssertEqual(characteristic.subscribers.count, 2, "characteristic subscriber count invalid")
            peripheralManager.didUnsubscribeFromCharacteristic(characteristic.cbMutableChracteristic, central: centralMock1)
            let centrals = characteristic.subscribers
            XCTAssert(characteristic.isUpdating, "isUpdating value invalid")
            XCTAssert(characteristic.updateValueWithData(value), "updateValueWithData invalid return status")
            XCTAssertEqual(characteristic.value, value, "characteristic value is invalid")
            XCTAssert(mock.updateValueCalled, "CBPeripheralManager#updateValue not called")
            XCTAssertEqual(centrals.count, 1, "characteristic subscriber count invalid")
            XCTAssertEqual(centrals[0].identifier, centralMock2.identifier as UUID, "invalid central identifier")
            XCTAssertEqual(characteristic.pendingUpdates.count, 0, "pendingUpdates is invalid")
        }
    }

    func testupdateValueWithData_WithSubscriberWhenUpdateFailes_UpdatesAreSavedToPendingQueue() {
        let centralMock = CBCentralMock(maximumUpdateValueLength: 20)
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: MutableService) -> Void in
            let characteristic = peripheralManager.characteristics[0]
            let value1 = "aa".dataFromHexString()
            let value2 = "bb".dataFromHexString()
            peripheralManager.didSubscribeToCharacteristic(characteristic.cbMutableChracteristic, central: centralMock)
            XCTAssert(characteristic.isUpdating, "isUpdating not set")
            XCTAssertEqual(characteristic.subscribers.count, 1, "characteristic subscriber count invalid")
            mock.updateValueReturn = false
            XCTAssertFalse(characteristic.updateValueWithData(value1), "updateValueWithData invalid return status")
            XCTAssertFalse(characteristic.updateValueWithData(value2), "updateValueWithData invalid return status")
            XCTAssertFalse(characteristic.isUpdating, "isUpdating not set")
            XCTAssert(mock.updateValueCalled, "CBPeripheralManager#updateValue not called")
            XCTAssertEqual(characteristic.pendingUpdates.count, 2, "pendingUpdates is invalid")
            XCTAssertEqual(characteristic.value, value2, "characteristic value is invalid")
            XCTAssertEqual(characteristic.pendingUpdates.count, 2, "pendingUpdates is invalid")
        }
    }

    func testupdateValueWithData_WithSubscriberWithPendingUpdatesThatResume_PendingUpdatesAreSent() {
        let centralMock = CBCentralMock(maximumUpdateValueLength: 20)
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: MutableService) -> Void in
            let characteristic = peripheralManager.characteristics[0]
            let value1 = "aa".dataFromHexString()
            let value2 = "bb".dataFromHexString()
            peripheralManager.didSubscribeToCharacteristic(characteristic.cbMutableChracteristic, central: centralMock)
            XCTAssert(characteristic.isUpdating, "isUpdating not set")
            XCTAssertEqual(characteristic.subscribers.count, 1, "characteristic subscriber count invalid")
            XCTAssert(characteristic.updateValueWithData("11".dataFromHexString()), "updateValueWithData invalid return status")
            XCTAssertEqual(characteristic.pendingUpdates.count, 0, "pendingUpdates is invalid")
            mock.updateValueReturn = false
            XCTAssertFalse(characteristic.updateValueWithData(value1), "updateValueWithData invalid return status")
            XCTAssertFalse(characteristic.updateValueWithData(value2), "updateValueWithData invalid return status")
            XCTAssertEqual(characteristic.pendingUpdates.count, 2, "pendingUpdates is invalid")
            XCTAssertFalse(characteristic.isUpdating, "isUpdating not set")
            XCTAssert(mock.updateValueCalled, "CBPeripheralManager#updateValue not called")
            XCTAssertEqual(characteristic.value, value2, "characteristic value is invalid")
            mock.updateValueReturn = true
            peripheralManager.isReadyToUpdateSubscribers()
            XCTAssertEqual(characteristic.pendingUpdates.count, 0, "pendingUpdates is invalid")
            XCTAssert(characteristic.isUpdating, "isUpdating not set")
            XCTAssertEqual(characteristic.value, value2, "characteristic value is invalid")
        }
    }

    func testupdateValueWithData_WithPendingUpdatesPriorToSubscriber_SEndPensingUpdates() {
        let centralMock = CBCentralMock(maximumUpdateValueLength: 20)
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: MutableService) -> Void in
            let characteristic = peripheralManager.characteristics[0]
            let value1 = "aa".dataFromHexString()
            let value2 = "bb".dataFromHexString()
            XCTAssertFalse(characteristic.isUpdating, "isUpdating value invalid")
            XCTAssertFalse(characteristic.updateValueWithData(value1))
            XCTAssertFalse(characteristic.updateValueWithData(value2), "updateValueWithData invalid return status")
            XCTAssertFalse(mock.updateValueCalled, "CBPeripheralManager#updateValue called")
            XCTAssertEqual(characteristic.value, value2, "characteristic value is invalid")
            XCTAssertEqual(characteristic.subscribers.count, 0, "characteristic subscriber count invalid")
            XCTAssertEqual(characteristic.pendingUpdates.count, 2, "pendingUpdates is invalid")
            peripheralManager.didSubscribeToCharacteristic(characteristic.cbMutableChracteristic, central: centralMock)
            XCTAssertEqual(characteristic.subscribers.count, 1, "characteristic subscriber count invalid")
            XCTAssertEqual(characteristic.pendingUpdates.count, 0, "pendingUpdates is invalid")
            XCTAssert(mock.updateValueCalled, "CBPeripheralManager#updateValue not called")
        }
    }


    // MARK: Respond to write requests
    func testStartRespondingToWriteRequests_WhenRequestIsRecieved_CompletesSuccessfullyAndResponds() {
        let centralMock = CBCentralMock(maximumUpdateValueLength: 20)
        var peripheralManagerUT: PeripheralManagerUT?
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: MutableService) -> Void in
            peripheralManagerUT = peripheralManager
        }
        if let peripheralManagerUT = peripheralManagerUT {
            let characteristic = peripheralManagerUT.characteristics[0]
            let value = "aa".dataFromHexString()
            let requestMock = CBATTRequestMock(characteristic: characteristic.cbMutableChracteristic, offset: 0, value: value)
            let future = characteristic.startRespondingToWriteRequests()
            peripheralManagerUT.didReceiveWriteRequest(requestMock, central: centralMock)
            XCTAssertFutureStreamSucceeds(future, context: self.immediateContext, validations: [{ (request, central) in
                    characteristic.respondToRequest(request, withResult: CBATTError.Code.success)
                    XCTAssertEqual(centralMock.identifier, central.identifier)
                    XCTAssertEqual(request.getCharacteristic().UUID, characteristic.UUID)
                    XCTAssertEqual(peripheralManagerUT.result, CBATTError.Code.success)
                    XCTAssertEqual(request.value, value, "request value is invalid")
                    XCTAssert(peripheralManagerUT.respondToRequestCalled, "respondToRequest not called")
                }
            ])
        } else {
            XCTFail("peripheralManagerUT is nil")
        }

    }

    func testStartRespondingToWriteRequests_WhenMultipleRequestsAreReceived_CompletesSuccessfullyAndRespondstoAll() {
        let centralMock = CBCentralMock(maximumUpdateValueLength: 20)
        var peripheralManagerUT: PeripheralManagerUT?
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: MutableService) -> Void in
            peripheralManagerUT = peripheralManager
        }
        if let peripheralManagerUT = peripheralManagerUT {
            let characteristic = peripheralManagerUT.characteristics[0]
            let values = ["aa".dataFromHexString(), "a1".dataFromHexString(), "a2".dataFromHexString(), "a3".dataFromHexString(), "a4".dataFromHexString(), "a5".dataFromHexString()]
            let requestMocks = values.map { CBATTRequestMock(characteristic: characteristic.cbMutableChracteristic, offset: 0, value: $0) }
            let future = characteristic.startRespondingToWriteRequests()
            for requestMock in requestMocks {
                peripheralManagerUT.didReceiveWriteRequest(requestMock, central: centralMock)
            }
            XCTAssertFutureStreamSucceeds(future, context: self.immediateContext, validations: [
                 {(request, central) in
                    characteristic.respondToRequest(request, withResult: CBATTError.Code.success)
                    XCTAssertEqual(centralMock.identifier, central.identifier)
                    XCTAssertEqual(request.getCharacteristic().UUID, characteristic.UUID)
                    XCTAssertEqual(peripheralManagerUT.result, CBATTError.Code.success)
                    XCTAssertEqual(request.value, values[0])
                    XCTAssert(peripheralManagerUT.respondToRequestCalled)
                },
                {(request, central) in
                    characteristic.respondToRequest(request, withResult: CBATTError.Code.success)
                    XCTAssertEqual(centralMock.identifier, central.identifier)
                    XCTAssertEqual(request.getCharacteristic().UUID, characteristic.UUID)
                    XCTAssertEqual(peripheralManagerUT.result, CBATTError.Code.success)
                    XCTAssertEqual(request.value, values[1])
                    XCTAssert(peripheralManagerUT.respondToRequestCalled)
                },
                {(request, central) in
                    characteristic.respondToRequest(request, withResult: CBATTError.Code.success)
                    XCTAssertEqual(centralMock.identifier, central.identifier)
                    XCTAssertEqual(request.getCharacteristic().UUID, characteristic.UUID)
                    XCTAssertEqual(peripheralManagerUT.result, CBATTError.Code.success)
                    XCTAssertEqual(request.value, values[2])
                    XCTAssert(peripheralManagerUT.respondToRequestCalled)
                },
                {(request, central) in
                    characteristic.respondToRequest(request, withResult: CBATTError.Code.success)
                    XCTAssertEqual(centralMock.identifier, central.identifier)
                    XCTAssertEqual(request.getCharacteristic().UUID, characteristic.UUID)
                    XCTAssertEqual(peripheralManagerUT.result, CBATTError.Code.success)
                    XCTAssertEqual(request.value, values[3])
                    XCTAssert(peripheralManagerUT.respondToRequestCalled)
                },
                {(request, central) in
                    characteristic.respondToRequest(request, withResult: CBATTError.Code.success)
                    XCTAssertEqual(centralMock.identifier, central.identifier)
                    XCTAssertEqual(request.getCharacteristic().UUID, characteristic.UUID)
                    XCTAssertEqual(peripheralManagerUT.result, CBATTError.Code.success)
                    XCTAssertEqual(request.value, values[4])
                    XCTAssert(peripheralManagerUT.respondToRequestCalled)
                },
                {(request, central) in
                    characteristic.respondToRequest(request, withResult: CBATTError.Code.success)
                    XCTAssertEqual(centralMock.identifier, central.identifier)
                    XCTAssertEqual(request.getCharacteristic().UUID, characteristic.UUID)
                    XCTAssertEqual(peripheralManagerUT.result, CBATTError.Code.success)
                    XCTAssertEqual(request.value, values[5])
                    XCTAssert(peripheralManagerUT.respondToRequestCalled)
                }
            ])
        } else {
            XCTFail("peripheralManagerUT is nil")
        }
    }

    func testStartRespondingToWriteRequests_WhenNotCalled_RespondsToRequestWithRequestNotSupported() {
        let centralMock = CBCentralMock(maximumUpdateValueLength: 20)
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: MutableService) -> Void in
            let characteristic = peripheralManager.characteristics[0]
            let value = "aa".dataFromHexString()
            let request = CBATTRequestMock(characteristic: characteristic.cbMutableChracteristic, offset: 0, value: value)
            peripheralManager.didReceiveWriteRequest(request, central: centralMock)
            XCTAssertEqual(peripheralManager.result, CBATTError.Code.requestNotSupported)
            XCTAssert(peripheralManager.respondToRequestCalled, "respondToRequest not called")
        }
    }

    func testStartRespondingToWriteRequests_WhenNotCalledAndCharacteristicNotAddedToService_RespondsToRequestWithUnlikelyError() {
        let centralMock = CBCentralMock(maximumUpdateValueLength: 20)
        let (_, peripheralManager) = createPeripheralManager(false, state: .poweredOn)
        let characteristic = MutableCharacteristic(profile: StringCharacteristicProfile<Gnosus.HelloWorldService.Greeting>())
        let request = CBATTRequestMock(characteristic: characteristic.cbMutableChracteristic, offset: 0, value: nil)
        let value = "aa".dataFromHexString()
        characteristic.value = value
        peripheralManager.didReceiveWriteRequest(request, central: centralMock)
        XCTAssertEqual(request.value, nil, "value is invalid")
        XCTAssert(peripheralManager.respondToRequestCalled, "respondToRequest not called")
        XCTAssertEqual(peripheralManager.result, CBATTError.Code.unlikelyError, "result is invalid")
    }

    func testStopRespondingToWriteRequests_WhenRespondingToWriteRequests_StopsRespondingToWriteRequests() {
        let centralMock = CBCentralMock(maximumUpdateValueLength: 20)
        var peripheralManagerUT: PeripheralManagerUT?
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: MutableService) -> Void in
            peripheralManagerUT = peripheralManager
        }
        if let peripheralManagerUT = peripheralManagerUT {
            let characteristic = peripheralManagerUT.characteristics[0]
            let value = "aa".dataFromHexString()
            let request = CBATTRequestMock(characteristic: characteristic.cbMutableChracteristic, offset: 0, value: value)
            let future = characteristic.startRespondingToWriteRequests()
            characteristic.stopRespondingToWriteRequests()
            future.onSuccess(self.immediateContext) {_ in
                XCTFail()
            }
            future.onFailure (self.immediateContext) {error in
                XCTFail()
            }
            peripheralManagerUT.didReceiveWriteRequest(request, central: centralMock)
            XCTAssert(peripheralManagerUT.respondToRequestCalled)
            XCTAssertEqual(peripheralManagerUT.result, CBATTError.Code.requestNotSupported)
        } else {
            XCTFail()
        }
    }

    // MARK: Respond to read requests
    func testDidReceiveReadRequest_WhenCharacteristicIsInService_RespondsToRequest() {
        let centralMock = CBCentralMock(maximumUpdateValueLength: 20)
        self.addCharacteristics {(mock: CBPeripheralManagerMock, peripheralManager: PeripheralManagerUT, service: MutableService) -> Void in
            let characteristic = peripheralManager.characteristics[0]
            let request = CBATTRequestMock(characteristic: characteristic.cbMutableChracteristic, offset: 0, value: nil)
            let value = "aa".dataFromHexString()
            characteristic.value = value
            peripheralManager.didReceiveReadRequest(request, central: centralMock)
            XCTAssertEqual(request.value, value)
            XCTAssert(peripheralManager.respondToRequestCalled)
            XCTAssertEqual(peripheralManager.result, CBATTError.Code.success)
        }
    }
    
    func testDidReceiveReadRequest_WhenCharacteristicIsNotInService_RespondsWithUnlikelyError() {
        let centralMock = CBCentralMockmaximumUpdateValueLength: 20)
        let (_, peripheralManager) = createPeripheralManager(false, state: .poweredOn)
        let characteristic = MutableCharacteristic(profile: StringCharacteristicProfile<Gnosus.HelloWorldService.Greeting>())
        let request = CBATTRequestMock(characteristic: characteristic.cbMutableChracteristic, offset: 0, value: nil)
        let value = "aa".dataFromHexString()
        characteristic.value = value
        peripheralManager.didReceiveReadRequest(request, central: centralMock)
        XCTAssertEqual(request.value, nil, "value is invalid")
        XCTAssert(peripheralManager.respondToRequestCalled, "respondToRequest not called")
        XCTAssertEqual(peripheralManager.result, CBATTError.Code.unlikelyError, "result is invalid")
    }

}
