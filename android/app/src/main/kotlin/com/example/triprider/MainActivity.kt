package com.example.triprider

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.BinaryMessenger
import android.content.Context
import android.os.Bundle
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.common.MethodChannel
import com.kakao.vectormap.KakaoMapSdk

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Initialize Kakao Map SDK before any MapView.start()
        KakaoMapSdk.init(this, getString(R.string.kakao_native_app_key))
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "map-kakao",
                KakaoMapFactory(flutterEngine.dartExecutor.binaryMessenger)
            )
    }
}

class KakaoMapFactory(
    private val messenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, id: Int, args: Any?): PlatformView {
        val creationParams = args as? Map<String, Any?>
        return KakaoMapPlatform(context, creationParams, messenger, id)
    }
}