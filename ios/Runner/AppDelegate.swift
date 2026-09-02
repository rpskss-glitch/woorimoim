import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    /* 🔔 「알림 소리·진동 바꾸기」 — 폰의 «이 앱 설정»을 연다.
       아이폰은 앱마다 알림 화면이 따로 없고 «앱 설정»으로 들어가 알림을 누르는 구조라,
       열 수 있는 자리는 여기까지다(그 다음은 회원이 「알림」을 누른다).
       ⚠️ 안드로이드와 «같은 이름»의 길을 쓴다 — 앱 쪽 코드가 하나로 유지되게. */
    let messenger = engineBridge.applicationBinaryMessenger
    let channel = FlutterMethodChannel(name: "club/appsettings", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "openNotificationSettings" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let url = URL(string: UIApplication.openSettingsURLString),
            UIApplication.shared.canOpenURL(url) else {
        result(false)
        return
      }
      UIApplication.shared.open(url, options: [:]) { ok in result(ok) }
    }
  }
}
