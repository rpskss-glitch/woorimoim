package com.taejinsoft.woorimoim

import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 🔔 「알림 소리·진동 바꾸기」 — 폰의 «이 앱 알림 설정»을 연다.
 *
 * ⚠️ 왜 꾸러미(app_settings) 를 안 쓰고 여기서 직접 여는가:
 *    그 꾸러미는 화면(activity)을 못 찾으면 **아무것도 안 하고 «됐다»고 돌려준다.**
 *    그러면 회원은 눌러도 아무 일이 없는데 앱은 안내조차 못 한다
 *    (2026-09-03 사장님: 「알림 눌러도 안 되네」). 여기서는 우리 화면에서 직접 열고,
 *    안 되면 «안 됐다»고 알려 준다 — 그래야 앱이 다른 길을 안내할 수 있다.
 *
 * ⚠️ 안드로이드는 «알림 묶음»을 한 번 만들면 앱이 소리를 못 바꾼다. 폰 설정에서 고르는 것이
 *    정석이라, 그 자리를 열어 주는 것이 이 앱이 할 수 있는 전부다.
 */
class MainActivity : FlutterActivity() {
    private val channel = "club/appsettings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openNotificationSettings" -> openNotificationSettings(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun openNotificationSettings(result: MethodChannel.Result) {
        try {
            /* 안드로이드 8 이상은 «이 앱 알림» 화면이 따로 있다 — 거기가 소리·진동을 고르는 자리다.
               그 아래 판에서는 앱 정보 화면으로 보낸다(거기서 알림으로 들어갈 수 있다). */
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(android.net.Uri.fromParts("package", packageName, null))
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            // 못 열었으면 «못 열었다»고 한다 — 앱이 「설정 → 앱 → 알림」 길을 안내한다
            result.success(false)
        }
    }
}
