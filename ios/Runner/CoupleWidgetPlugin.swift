import Flutter
import UIKit
import WidgetKit

final class CoupleWidgetPlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
    private let openChannel: FlutterMethodChannel
    private var openPending = false
    private var observers: [NSObjectProtocol] = []
    private init(messenger: FlutterBinaryMessenger) {
        openChannel = FlutterMethodChannel(name: "taiwan_brawl/couple_widget_open", binaryMessenger: messenger)
        super.init()
        for name in [NSNotification.Name.NSSystemTimeZoneDidChange, UIApplication.significantTimeChangeNotification, UIApplication.didBecomeActiveNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                WidgetCenter.shared.reloadTimelines(ofKind: CoupleWidgetStore.kind)
            })
        }
    }
    deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }
    static func register(with registrar: FlutterPluginRegistrar) {
        let plugin = CoupleWidgetPlugin(messenger: registrar.messenger())
        registrar.addMethodCallDelegate(plugin, channel: FlutterMethodChannel(name: "taiwan_brawl/couple_widget", binaryMessenger: registrar.messenger()))
        registrar.addMethodCallDelegate(plugin, channel: plugin.openChannel)
        registrar.addSceneDelegate(plugin)
        registrar.addApplicationDelegate(plugin)
        registrar.publish(plugin)
    }
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "consumeOpen" {
            let pending = openPending; openPending = false; result(pending); return
        }
        guard ["beginSession", "replace", "readCounter", "readAppearance", "setAppearance"].contains(call.method) else { result(FlutterMethodNotImplemented); return }
        do {
            if call.method == "readAppearance" { result(try CoupleWidgetContainer.appearance()); return }
            if call.method == "setAppearance" {
                guard let arguments = call.arguments as? [String: Any], let palette = arguments["palette"] as? String else { throw CoupleWidgetError.invalid }
                try CoupleWidgetContainer.setAppearance(palette)
                WidgetCenter.shared.reloadTimelines(ofKind: CoupleWidgetStore.kind)
                result(nil); return
            }
            let store = try CoupleWidgetContainer.store()
            if call.method == "readCounter" {
                result(try store.read()?.counterProjection())
                return
            }
            guard let arguments = call.arguments as? [String: Any] else { throw CoupleWidgetError.invalid }
            if call.method == "beginSession" {
                guard arguments["accountScope"] is NSNull || arguments["accountScope"] is String else { throw CoupleWidgetError.invalid }
                let generation = try store.begin(scope: arguments["accountScope"] as? String)
                WidgetCenter.shared.reloadTimelines(ofKind: CoupleWidgetStore.kind)
                result(generation)
            } else {
                guard let raw = arguments["snapshot"] as? [String: Any] else { throw CoupleWidgetError.invalid }
                let snapshot = try CoupleWidgetSnapshot.decode(JSONSerialization.data(withJSONObject: raw))
                try store.replace(snapshot)
                WidgetCenter.shared.reloadTimelines(ofKind: CoupleWidgetStore.kind)
                result(nil)
            }
        } catch {
            result(FlutterError(code: "WIDGET_WRITE_REJECTED", message: "Shared snapshot unavailable, obsolete or not persisted", details: nil))
        }
    }
    private func open(_ urls: [URL]) -> Bool {
        guard urls.contains(where: { $0.scheme == "taiwanbrawl-widget" && $0.host == "open" && $0.path.isEmpty && $0.query == nil && $0.fragment == nil }) else { return false }
        openPending = true
        openChannel.invokeMethod("open", arguments: nil)
        return true
    }
    @objc(scene:willConnectToSession:options:)
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions?) -> Bool {
        open(connectionOptions?.urlContexts.map(\.url) ?? [])
    }
    @objc(scene:openURLContexts:)
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
        open(URLContexts.map(\.url))
    }
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        open([url])
    }
}
