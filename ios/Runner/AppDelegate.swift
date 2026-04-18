import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let notificationsChannelName = "taiwan_brawl/notifications"
  private var notificationsChannel: FlutterMethodChannel?
  private var latestApnsToken: String?
  private var pendingRegistrationResult: FlutterResult?
  private var pendingOpenedNotification: [String: Any]?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    if let payload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      storeOpenedNotification(payload)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    let registry = engineBridge.pluginRegistry
    GeneratedPluginRegistrant.register(with: registry)

    let registrar = registry.registrar(forPlugin: notificationsChannelName)
    let channel = FlutterMethodChannel(
      name: notificationsChannelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler(handleNotificationsMethodCall)
    notificationsChannel = channel
  }

  private func handleNotificationsMethodCall(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "registerForRemoteNotifications":
      requestRemoteNotificationRegistration(result: result)
    case "unregisterForRemoteNotifications":
      UIApplication.shared.unregisterForRemoteNotifications()
      latestApnsToken = nil
      result(nil)
    case "consumeNotificationOpen":
      let payload = pendingOpenedNotification
      pendingOpenedNotification = nil
      result(payload)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestRemoteNotificationRegistration(result: @escaping FlutterResult) {
    if let token = latestApnsToken, !token.isEmpty {
      result(token)
      return
    }

    if pendingRegistrationResult != nil {
      result(
        FlutterError(
          code: "registration_pending",
          message: "APNs registration is already in progress.",
          details: nil
        )
      )
      return
    }

    pendingRegistrationResult = result
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    ) { [weak self] granted, error in
      guard let self else { return }
      if let error {
        self.resolvePendingRegistration(
          FlutterError(
            code: "authorization_failed",
            message: error.localizedDescription,
            details: nil
          )
        )
        return
      }

      guard granted else {
        self.resolvePendingRegistration(nil)
        return
      }

      DispatchQueue.main.async {
        UIApplication.shared.registerForRemoteNotifications()
      }
    }
  }

  private func resolvePendingRegistration(_ value: Any?) {
    let callback = pendingRegistrationResult
    pendingRegistrationResult = nil
    DispatchQueue.main.async {
      callback?(value)
    }
  }

  private func storeOpenedNotification(_ userInfo: [AnyHashable: Any]) {
    var payload: [String: Any] = [:]
    if let type = userInfo["type"] as? String, !type.isEmpty {
      payload["type"] = type
    }
    if let senderId = parseInt(userInfo["senderId"]) {
      payload["senderId"] = senderId
    }
    if let conversationUserId = parseInt(userInfo["conversationUserId"] ?? userInfo["senderId"]) {
      payload["conversationUserId"] = conversationUserId
    }
    guard !payload.isEmpty else {
      return
    }
    pendingOpenedNotification = payload
    if let channel = notificationsChannel {
      channel.invokeMethod("notificationOpened", arguments: payload)
      pendingOpenedNotification = nil
    }
  }

  private func parseInt(_ raw: Any?) -> Int? {
    if let number = raw as? NSNumber {
      return number.intValue
    }
    if let text = raw as? String {
      return Int(text)
    }
    return nil
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    latestApnsToken = deviceToken.map { String(format: "%02x", $0) }.joined()
    resolvePendingRegistration(latestApnsToken)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    resolvePendingRegistration(
      FlutterError(
        code: "registration_failed",
        message: error.localizedDescription,
        details: nil
      )
    )
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    storeOpenedNotification(response.notification.request.content.userInfo)
    completionHandler()
  }
}
