import AndroidAutoConnectedDeviceManager
import AndroidAutoLogger
import CoreBluetooth
import Flutter
import LocalAuthentication
import os.log

/// The possible errors that can result from a phone-initiated enrollment in trusted device.
private enum TrustedDeviceEnrollmentError: Int {
  case unknown = 0
  case carNotConnected = 1
  case passcodeNotSet = 2
}

/// This is the class used to setup Flutter method channel, handle and invoke any methods from and
/// to Flutter app.
public class TrustedDeviceMethodChannel: TrustedDeviceModel {

    private static let unlockNotificationIdentifier = "trusted-device-unlock-succeed"
    private static let enrollmentNotificationIdentifier = "trusted-device-enrollment-succeed"
    private static let unenrollmentNotificationIdentifier = "trusted-device-unenrollment"

    /// The prefix that can be combined with a car id to form a key within `UserDefaults` that
    /// stores whether a notification should be shown for a particular car when it is unlocked.
    private static let showUnlockNotificationPrefixKey = "showUnlockNotificationKey"

    private let connectedDeviceMethodChannel: FlutterMethodChannel
    private let trustedDeviceMethodChannel: FlutterMethodChannel
    private let flutterViewController: FlutterViewController

    private let storage = UserDefaults.standard

    /// Whether log file sharing is supported.
    ///
    /// The implementation depends on the share sheet which is supported in iOS 13+.
    private var isLogSharingSupported: Bool {
        if #available(iOS 13, *) {
            return true
        } else {
            return false
        }
    }

    /// The most recently received unlock status for a car
    private enum UnlockStatus: Int {
        /// The status is not known
        case unknown = 0

        /// The unlock is in progress
        case inProgress = 1

        /// The unlock was successful
        case success = 2

        /// An error was encountered during the unlock process
        case error = 3
    }

    /// The possible states that a car can be in.
    private enum CarConnectionStatus: Int {
        /// A car that is associated has been detected and connection is being established.
        case detected = 0

        /// A secure communication channel has been established with an associated car.
        case connected = 1

        /// An associated car has been disconnected.
        case disconnected = 2
    }

    //TODO

    func setupConnection(result: @escaping FlutterResult) {
        let response = connectionManager.setupConnection()
        result(response)
    }

    public init(_ controller: FlutterViewController) {
        flutterViewController = controller
        super.init()
        print("TOTO")
        setupConnection()
        //setUpTrustedDeviceCallHandler()

    }
    //MARK: Setup Connected Device FlutterMethod Channel

    private func setupConnectedDevice() {
        connectedDeviceMethodChannel = FlutterMethodChannel(
            name: ConnectedDeviceConstants.channel,
            binaryMessenger: controller.binaryMessenger)
    }

    private func setupTrustedDevice(){
        trustedDeviceMethodChannel = FlutterMethodChannel(
            name: TrustedDeviceConstants.channel,
            binaryMessenger: controller.binaryMessenger)
    }

    private func setUpTrustedDeviceCallHandler() {
        trustedDeviceMethodChannel.setMethodCallHandler(handle)
    }

    private func setupConnection() {
        setupConnectedDevice();
        connectedDeviceMethodChannel.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "setupConnection":
                print("setupConnection ******")
                self?.setupConnection(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }


        private func connectedDeviceHandle(connectedDeviceMethodChannel call: FlutterMethodCall, result: @escaping FlutterResult) {
            switch call.method {
            case "setupConnection":
                self?.setupConnection(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        nonisolated private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
            Task { [weak self] in
                switch call.method {
                case TrustedDeviceConstants.openSecuritySettings:
                    await self?.openSettings()

                case TrustedDeviceConstants.enrollTrustAgent:
                    await self?.invokeEnrollForTrustAgent(methodCall: call)

                case TrustedDeviceConstants.stopTrustAgentEnrollment:
                    await self?.invokeStopEnrollment(methodCall: call)

                case TrustedDeviceConstants.getUnlockHistory:
                    await self?.invokeRetrieveUnlockHistory(methodCall: call, result: result)

                case TrustedDeviceConstants.isTrustedDeviceEnrolled:
                    await self?.invokeIsTrustedDeviceEnrolled(methodCall: call, result: result)

                case TrustedDeviceConstants.isDeviceUnlockRequired:
                    await self?.invokeIsDeviceUnlockRequired(methodCall: call, result: result)

                case TrustedDeviceConstants.setDeviceUnlockRequired:
                    await self?.invokeSetDeviceUnlockRequired(methodCall: call)

                case TrustedDeviceConstants.shouldShowUnlockNotification:
                    await self?.invokeShouldShowUnlockNotification(methodCall: call, result: result)

                case TrustedDeviceConstants.setShowUnlockNotification:
                    await self?.invokeSetShowUnlockNotification(methodCall: call)

                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        }

        private func setUpConnectedDeviceCallHandler2() {
            connectedDeviceMethodChannel.setMethodCallHandler { [weak self] (call, result) in
                switch call.method {
                case ConnectedDeviceConstants.isBluetoothEnabled:
                    result(self?.connectionManager.state.isPoweredOn)

                case ConnectedDeviceConstants.isBluetoothPermissionGranted:
                    self?.invokeIsBluetoothPermissionGranted(result: result)

                case ConnectedDeviceConstants.scanForCarsToAssociate:
                    self?.scanForCarsToAssociate(methodCall: call)

                case ConnectedDeviceConstants.openApplicationDetailsSettings:
                    self?.openSettings()

                case ConnectedDeviceConstants.openBluetoothSettings:
                    self?.openSettings()

                case ConnectedDeviceConstants.associateCar:
                    self?.invokeAssociateCar(methodCall: call)

                case ConnectedDeviceConstants.getAssociatedCars:
                    self?.invokeRetrieveAssociatedCars(methodCall: call, result: result)

                case ConnectedDeviceConstants.getConnectedCars:
                    self?.invokeRetrieveConnectedCars(methodCall: call, result: result)

                case ConnectedDeviceConstants.connectToAssociatedCars:
                    self?.connectionManager.connectToAssociatedCars()

                case ConnectedDeviceConstants.clearCurrentAssociation:
                    self?.connectionManager.clearCurrentAssociation()

                case ConnectedDeviceConstants.clearAssociation:
                    self?.invokeClearAssociation(methodCall: call, result: result)

                case ConnectedDeviceConstants.renameCar:
                    self?.invokeRenameCar(methodCall: call, result: result)

                case ConnectedDeviceConstants.isCarConnected:
                    self?.invokeIsConnected(methodCall: call, result: result)

                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        }

        override public func onStateChange(state: RadioState) {
            invokeFlutterMethod(
                ConnectedDeviceConstants.onStateChanged,
                arguments: [
                    ConnectedDeviceConstants.connectionManagerStateKey: state.toBluetoothState()
                ],
                methodChannel: connectedDeviceMethodChannel
            )
        }

        override public func onConnection(car: Car) {
            var arguments = car.toDictionary()
            arguments[ConnectedDeviceConstants.carConnectionStatusKey] =
            String(CarConnectionStatus.detected.rawValue)

            invokeFlutterMethod(
                ConnectedDeviceConstants.onCarConnectionStatusChange,
                arguments: arguments,
                methodChannel: connectedDeviceMethodChannel
            )
        }

        override public func onSecureChannelSetup(car: Car) {
            var arguments = car.toDictionary()
            arguments[ConnectedDeviceConstants.carConnectionStatusKey] =
            String(CarConnectionStatus.connected.rawValue)

            invokeFlutterMethod(
                ConnectedDeviceConstants.onCarConnectionStatusChange,
                arguments: arguments,
                methodChannel: connectedDeviceMethodChannel
            )
        }

        override public func onDisconnection(car: Car) {
            var arguments = car.toDictionary()
            arguments[ConnectedDeviceConstants.carConnectionStatusKey] =
            String(CarConnectionStatus.disconnected.rawValue)

            invokeFlutterMethod(
                ConnectedDeviceConstants.onCarConnectionStatusChange,
                arguments: arguments,
                methodChannel: connectedDeviceMethodChannel
            )
        }

        func invokeFlutterMethod(
            _ methodName: String,
            arguments: [String: String]? = nil,
            methodChannel: FlutterMethodChannel
        ) {
            methodChannel.invokeMethod(methodName, arguments: arguments) { result in
                if let error = result as? FlutterError {
                    os_log(
                        "invokeMethod failed for method `%@` with error: %@",
                        type: .error,
                        methodName,
                        error.message ?? "no error message")
                } else if FlutterMethodNotImplemented.isEqual(result) {
                    os_log(
                        "method `%@` not implemented",
                        type: .error,
                        methodName)
                } else {
                    os_log(
                        "Invocation of method `%@` is successful.",
                        type: .debug,
                        methodName)
                }
            }
        }

        private func scanForCarsToAssociate(methodCall: FlutterMethodCall) {
            discoveredCars = [:]

            let namePrefix = methodCall.arguments as? String ?? ""
            connectionManager.scanForCarsToAssociate(namePrefix: namePrefix)
        }

        /// Attempts to open the settings page.
        private func openSettings() {
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        }

        private func invokeAssociateCar(methodCall: FlutterMethodCall) {
            guard connectionManager.state.isPoweredOn else {
                os_log(
                    "Associate car method invoked when BLE adapter is not on. Ignoring.",
                    type: .error)
                return
            }

            guard let uuid = methodCall.arguments as? String else {
                os_log(
                    "Associate car method invoked with nil uuid. Ignoring.",
                    type: .error)
                return
            }

            guard let carToAssociate = discoveredCars[uuid] else {
                os_log(
                    "Call to associate a car with UUID %@, but no cars with that UUID found. Ignoring",
                    type: .error,
                    uuid)
                return
            }

            os_log("Call to associate car with UUID %@", type: .debug, uuid)

            do {
                try connectionManager.associate(carToAssociate)
            } catch {
                os_log("Association was unsuccessful: %@", type: .error, error.localizedDescription)
            }
        }

        private func invokeRetrieveConnectedCars(methodCall: FlutterMethodCall, result: FlutterResult) {
            result(connectionManager.securedChannels.map { $0.car.toDictionary() })
        }

        private func invokeRetrieveAssociatedCars(methodCall: FlutterMethodCall, result: FlutterResult) {
            result(connectionManager.associatedCars.map { $0.toDictionary() })
        }

        private func invokeClearAssociation(methodCall: FlutterMethodCall, result: FlutterResult)  {
            guard let carId = methodCall.arguments as? String else {
                os_log(
                    "clearAssociation method invoked with invalid carId. Ignoring.",
                    type: .error)
                return
            }
            clearConfig(forCarId: carId)
            connectionManager.clearAssociation(for: Car(id: carId, name: nil))
            result(nil)
        }

        private func invokeEnrollForTrustAgent(methodCall: FlutterMethodCall) {
            guard let car = methodCall.argumentsToCar() else {
                os_log(
                    "Trust agent enrollment called with invalid car. Ignoring.",
                    type: .error)
                return
            }

            do {
                try trustAgentManager.enroll(car)
            } catch {
                os_log(
                    "Encountered error during enrollment: %@",
                    type: .error,
                    error.localizedDescription
                )

                // Should never be something other than a `TrustAgentManagerError`.
                if let enrollmentError = error as? TrustAgentManagerError {
                    handleEnrollingError(enrollmentError, for: car)
                }
            }
        }

        private func invokeRetrieveUnlockHistory(methodCall: FlutterMethodCall, result: FlutterResult) {
            guard let car = methodCall.argumentsToCar() else {
                os_log(
                    "getUnlockHistory method invoked with invalid car. Ignoring.",
                    type: .error)
                return
            }

            let unlockHistory = trustAgentManager.unlockHistory(for: car)
            let dateFormatter = ISO8601DateFormatter()

            result(unlockHistory.map { dateFormatter.string(from: $0) })
        }

        private func invokeRenameCar(methodCall: FlutterMethodCall, result: FlutterResult) {
            guard let carMap = methodCall.arguments as? [String: String],
                  let carId = carMap[ConnectedDeviceConstants.carIdKey],
                  let name = carMap[ConnectedDeviceConstants.carNameKey]
            else {
                os_log(
                    "renameCar method invoked with invalid id or name. Ignoring.",
                    type: .error)
                return
            }

            result(connectionManager.renameCar(withId: carId, to: name))
        }

        private func invokeIsTrustedDeviceEnrolled(methodCall: FlutterMethodCall, result: FlutterResult) {
            guard let car = methodCall.argumentsToCar()
            else {
                os_log(
                    "isTrustedDeviceEnrolled method invoked with invalid id or name. Ignoring.",
                    type: .error)
                return
            }

            result(trustAgentManager.isEnrolled(with: car))
        }

        private func invokeIsBluetoothPermissionGranted(result: FlutterResult) {
            if #available(iOS 13.0, *) {
                result(CBCentralManager().authorization == .allowedAlways)
            } else {
                // Bluetooth permissions are not required before iOS 13.
                result(true)
            }
        }

        private func invokeIsConnected(methodCall: FlutterMethodCall, result: FlutterResult) {
            guard let car = methodCall.argumentsToCar() else {
                os_log(
                    "isConnected method invoked with invalid car. Ignoring.",
                    type: .error)
                return
            }
            result(isCarConnectedSecurely(car))
        }

        private func invokeStopEnrollment(methodCall: FlutterMethodCall) {
            guard let car = methodCall.argumentsToCar() else {
                os_log(
                    "Trust agent stop enrollment called with invalid car. Ignoring.",
                    type: .error)
                return
            }
            trustAgentManager.stopEnrollment(for: car)
        }

        private func invokeIsDeviceUnlockRequired(methodCall: FlutterMethodCall, result: FlutterResult) {
            guard let car = methodCall.argumentsToCar() else {
                os_log(
                    "IsDeviceUnlockRequired called with invalid car. Ignoring.",
                    type: .error)
                return
            }
            result(trustAgentManager.isDeviceUnlockRequired(for: car))
        }

        private func invokeSetDeviceUnlockRequired(methodCall: FlutterMethodCall) {
            guard let car = methodCall.argumentsToCar(),
                  let arguments = methodCall.arguments as? [String: String],
                  let isRequired = arguments[TrustedDeviceConstants.isDeviceUnlockRequiredKey]
            else {
                os_log(
                    "setDeviceUnlockRequired method invoked with invalid arguments. Ignoring.",
                    type: .error)
                return
            }
            trustAgentManager.setDeviceUnlockRequired((isRequired as NSString).boolValue, for: car)
        }

        private func invokeShouldShowUnlockNotification(
            methodCall: FlutterMethodCall, result: FlutterResult
        ) {
            guard let car = methodCall.argumentsToCar() else {
                os_log(
                    "showUnlockNotification called with invalid car. Ignoring.",
                    type: .error)
                return
            }
            result(shouldShowUnlockNotification(for: car))
        }

        private func invokeSetShowUnlockNotification(methodCall: FlutterMethodCall) {
            guard let car = methodCall.argumentsToCar(),
                  let arguments = methodCall.arguments as? [String: String],
                  let shouldShow = arguments[TrustedDeviceConstants.shouldShowUnlockNotificationKey]
            else {
                os_log(
                    "setShowUnlockNotification method invoked with invalid arguments. Ignoring.",
                    type: .error)
                return
            }
            let shouldShowBoolValue = (shouldShow as NSString).boolValue

            if shouldShowBoolValue {
                showNotificationPermissionDialogIfNeeded()
            }
            setShowUnlockNotification(shouldShowBoolValue, for: car)
        }

        /// Return whether the given car should show a notification when its unlocked.
        private func shouldShowUnlockNotification(for car: Car) -> Bool {
            let key = Self.notificationKey(forCarId: car.id)

            // By default, the notification should be shown unless the user has explicitly overridden it.
            return storage.containsKey(key)
            ? storage.bool(forKey: key)
            : true
        }

        /// Stores in lcoal storage whether the given car should show a notification when it's unlocked.
        private func setShowUnlockNotification(_ shouldShow: Bool, for car: Car) {
            storage.set(shouldShow, forKey: Self.notificationKey(forCarId: car.id))
        }

        /// Clears any stored configuration data for the given car.
        private func clearConfig(forCarId carId: String) {
            storage.removeObject(forKey: Self.notificationKey(forCarId: carId))
        }

        private static func notificationKey(forCarId carId: String) -> String {
            return "\(showUnlockNotificationPrefixKey).\(carId)"
        }

        /// Pop up the system notification permission dialog.
        /// The dialog will not be shown if the permission has been denied before.
        private func requestNotificationPermission() {
            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge]) {
                    granted, error in
                    os_log("Notification permission granted: %{bool}", type: .debug, granted)
                    if let error = error {
                        os_log(
                            "Error asking for notification permission: %@",
                            type: .error,
                            error.localizedDescription)
                    }
                }
        }

        private func showNotificationPermissionDialogIfNeeded() {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                switch settings.authorizationStatus {
                case .denied:
                    self.showNotificationExplanationDialog(isDenied: true)
                case .notDetermined:
                    self.showNotificationExplanationDialog(isDenied: false)
                default:
                    os_log(
                        "The notification permission status is %lld", type: .debug,
                        Int64(settings.authorizationStatus.rawValue))
                }
            }
        }

        private func showNotificationExplanationDialog(isDenied: Bool) {
            let alert = UIAlertController(
                title: NSString.localizedUserNotificationString(
                    forKey: "notificationPermissionDialogTitle", arguments: nil),
                message: NSString.localizedUserNotificationString(
                    forKey: "notificationPermissionDialogText", arguments: nil),
                preferredStyle: .alert)
            alert.addAction(makeAlertAction(forLocalizedKey: "notNowButtonLabel"))

            if isDenied {
                alert.addAction(
                    makeAlertAction(
                        forLocalizedKey: "settingsButtonLabel",
                        handler: { _ in
                            self.openSettings()
                        }))
            } else {
                alert.addAction(
                    makeAlertAction(
                        forLocalizedKey: "okButtonLabel",
                        handler: { _ in
                            self.requestNotificationPermission()
                        }))
            }

            DispatchQueue.main.async {
                self.flutterViewController.present(alert, animated: true)
            }
        }

        private func makeAlertAction(
            forLocalizedKey key: String, handler: ((UIAlertAction) -> Void)? = nil
        ) -> UIAlertAction {
            return UIAlertAction(
                title: NSString.localizedUserNotificationString(forKey: key, arguments: nil),
                style: .default,
                handler: handler)

        }

        private func pushUnlockNotification(for car: Car) {
            let defaultCarName = NSString.localizedUserNotificationString(
                forKey: "defaultCarName", arguments: nil)
            let notificationBody = NSString.localizedUserNotificationString(
                forKey: "unlockNotificationContent", arguments: [car.name ?? defaultCarName])
            showNotification(
                body: notificationBody, identifier: TrustedDeviceMethodChannel.unlockNotificationIdentifier)
        }

        private func pushEnrollmentCompletedNotification(for car: Car) {
            let defaultCarName = NSString.localizedUserNotificationString(
                forKey: "defaultCarName", arguments: nil)
            let notificationTitle = NSString.localizedUserNotificationString(
                forKey: "enrollmentNotificationTitle", arguments: nil)
            let notificationBody = NSString.localizedUserNotificationString(
                forKey: "enrollmentNotificationBody", arguments: [car.name ?? defaultCarName])
            showNotification(
                title: notificationTitle, body: notificationBody,
                identifier: TrustedDeviceMethodChannel.enrollmentNotificationIdentifier)
        }

        private func pushUnenrollmentNotification(for car: Car) {
            let defaultCarName = NSString.localizedUserNotificationString(
                forKey: "defaultCarName", arguments: nil)
            let notificationTitle = NSString.localizedUserNotificationString(
                forKey: "unenrollmentNotificationTitle", arguments: nil)
            let notificationBody = NSString.localizedUserNotificationString(
                forKey: "unenrollmentNotificationBody", arguments: [car.name ?? defaultCarName])
            showNotification(
                title: notificationTitle, body: notificationBody,
                identifier: TrustedDeviceMethodChannel.unenrollmentNotificationIdentifier)
        }

        private func showNotification(title: String = "", body: String, identifier: String) {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                if settings.authorizationStatus != .authorized {
                    os_log("Notification permission is granted", type: .debug)
                    return
                }
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let request = UNNotificationRequest(
                    identifier: identifier, content: content, trigger: trigger)

                let center = UNUserNotificationCenter.current()
                center.add(request)
            }
        }

        // MARK: - ConnectionManagerAssociationDelegate Overrides

        public override func connectionManager(
            _ connectionManager: AnyConnectionManager,
            didDiscover car: AnyPeripheral,
            advertisedName: String?
        ) {
            super.connectionManager(connectionManager, didDiscover: car, advertisedName: advertisedName)

            let name = advertisedName ?? car.name ?? ""

            invokeFlutterMethod(
                ConnectedDeviceConstants.onCarDiscovered,
                arguments: [
                    ConnectedDeviceConstants.carNameKey: name,
                    ConnectedDeviceConstants.carIdKey: car.identifier.uuidString,
                ],
                methodChannel: connectedDeviceMethodChannel
            )
        }

        public override func connectionManager(
            _ connectionManager: AnyConnectionManager,
            didDisconnect peripheral: AnyPeripheral
        ) {
            super.connectionManager(connectionManager, didDisconnect: peripheral)

            let name = peripheral.name ?? ""
            invokeFlutterMethod(
                ConnectedDeviceConstants.onCarConnectionStatusChange,
                arguments: [
                    ConnectedDeviceConstants.carNameKey: name,
                    ConnectedDeviceConstants.carIdKey: peripheral.identifier.uuidString,
                    ConnectedDeviceConstants.carConnectionStatusKey:
                        String(CarConnectionStatus.connected.rawValue),
                ],
                methodChannel: connectedDeviceMethodChannel
            )
        }

        public override func connectionManager(
            _ connectionManager: AnyConnectionManager,
            requiresDisplayOf pairingCode: String
        ) {
            invokeFlutterMethod(
                ConnectedDeviceConstants.onPairingCodeAvailable,
                arguments: [
                    ConnectedDeviceConstants.pairingCodeKey: pairingCode
                ],
                methodChannel: connectedDeviceMethodChannel
            )
        }

        public override func connectionManager(
            _ connectionManager: AnyConnectionManager,
            didCompleteAssociationWithCar car: Car
        ) {
            invokeFlutterMethod(
                ConnectedDeviceConstants.onAssociationCompleted,
                arguments: [
                    ConnectedDeviceConstants.carNameKey: car.name ?? "",
                    ConnectedDeviceConstants.carIdKey: car.id,
                ],
                methodChannel: connectedDeviceMethodChannel
            )
        }

        public override func connectionManager(
            _ connectionManager: AnyConnectionManager,
            didEncounterError error: Error
        ) {
            invokeFlutterMethod(
                ConnectedDeviceConstants.onAssociationError, methodChannel: connectedDeviceMethodChannel)
        }

        // MARK: - TrustAgentManagerDelegate

        public override func trustAgentManager(
            _ trustAgentManager: TrustAgentManager, didCompleteEnrolling car: Car, initiatedFromCar: Bool
        ) {
            invokeFlutterMethod(
                TrustedDeviceConstants.onTrustAgentEnrollmentCompleted,
                arguments: car.toDictionary(),
                methodChannel: trustedDeviceMethodChannel
            )
            if initiatedFromCar {
                showNotificationPermissionDialogIfNeeded()
                pushEnrollmentCompletedNotification(for: car)
            }
        }

        public override func trustAgentManager(
            _ trustAgentManager: TrustAgentManager, didUnenroll car: Car, initiatedFromCar: Bool
        ) {
            invokeFlutterMethod(
                TrustedDeviceConstants.onTrustAgentUnenrolled,
                arguments: car.toDictionary(),
                methodChannel: trustedDeviceMethodChannel
            )

            if initiatedFromCar {
                showNotificationPermissionDialogIfNeeded()
                pushUnenrollmentNotification(for: car)
            }
        }

        public override func trustAgentManager(
            _ trustAgentManager: TrustAgentManager,
            didEncounterEnrollingErrorFor car: Car,
            error: TrustAgentManagerError
        ) {
            handleEnrollingError(error, for: car)
        }

        private func handleEnrollingError(_ error: TrustAgentManagerError, for car: Car) {
            let convertedError = String(error.toEnrollmentError().rawValue)
            var arguments = car.toDictionary()
            arguments[TrustedDeviceConstants.trustAgentEnrollmentErrorKey] = convertedError

            invokeFlutterMethod(
                TrustedDeviceConstants.onTrustAgentEnrollmentError,
                arguments: arguments,
                methodChannel: trustedDeviceMethodChannel
            )
        }

        public override func trustAgentManager(
            _ trustAgentManager: TrustAgentManager, didStartUnlocking car: Car
        ) {
            invokeFlutterMethod(
                TrustedDeviceConstants.onUnlockStatusChanged,
                arguments: [
                    ConnectedDeviceConstants.carIdKey: car.id,
                    TrustedDeviceConstants.unlockStatusKey: String(UnlockStatus.inProgress.rawValue),
                ],
                methodChannel: trustedDeviceMethodChannel
            )
        }

        public override func trustAgentManager(
            _ trustAgentManager: TrustAgentManager, didSuccessfullyUnlock car: Car
        ) {
            invokeFlutterMethod(
                TrustedDeviceConstants.onUnlockStatusChanged,
                arguments: [
                    ConnectedDeviceConstants.carIdKey: car.id,
                    TrustedDeviceConstants.unlockStatusKey: String(UnlockStatus.success.rawValue),
                ],
                methodChannel: trustedDeviceMethodChannel
            )
            if shouldShowUnlockNotification(for: car) {
                pushUnlockNotification(for: car)
            }
        }

        public override func trustAgentManager(
            _ trustAgentManager: TrustAgentManager,
            didEncounterUnlockErrorFor car: Car,
            error: TrustAgentManagerError
        ) {
            invokeFlutterMethod(
                TrustedDeviceConstants.onUnlockStatusChanged,
                arguments: [
                    ConnectedDeviceConstants.carIdKey: car.id,
                    TrustedDeviceConstants.unlockStatusKey: String(UnlockStatus.error.rawValue),
                ],
                methodChannel: trustedDeviceMethodChannel
            )
        }
    }

    // MARK: - Extension helpers

    extension UserDefaults {
        /// Returns `true` if the given key has a value mapped to it in `UserDefaults`.
        func containsKey(_ key: String) -> Bool {
            return object(forKey: key) != nil
        }
    }

    extension Car {
        /// Converts the current `Car` object to a dictionary.
        ///
        /// - Returns: A dictionary representation of the `Car`.
        fileprivate func toDictionary() -> [String: String] {
            return [
                ConnectedDeviceConstants.carIdKey: id,
                ConnectedDeviceConstants.carNameKey: name ?? "",
            ]
        }
    }

    extension FlutterMethodCall {
        /// Attempts to cast thet arguments of this current method call as a `Car` object.
        ///
        /// - Returns: A `Car` object from the arguments of `nil` if a conversion is not possible.
        fileprivate func argumentsToCar() -> Car? {
            guard let carMap = arguments as? [String: String],
                  let carId = carMap[ConnectedDeviceConstants.carIdKey],
                  let name = carMap[ConnectedDeviceConstants.carNameKey]
            else {
                return nil
            }

            return Car(id: carId, name: name)
        }

    extension TrustAgentManagerError {
        fileprivate func toEnrollmentError() -> TrustedDeviceEnrollmentError {
            switch self {
            case .carNotConnected:
                return .carNotConnected
            case .passcodeNotSet:
                return .passcodeNotSet
            default:
                // There's currently no need for the app to know the exact details of any other errors.
                return .unknown
            }
        }
    }
