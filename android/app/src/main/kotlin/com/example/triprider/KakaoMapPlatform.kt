package com.example.triprider

import android.content.Context
import android.util.DisplayMetrics
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import com.kakao.vectormap.KakaoMap
import com.kakao.vectormap.KakaoMapReadyCallback
import com.kakao.vectormap.LatLng
import com.kakao.vectormap.MapLifeCycleCallback
import com.kakao.vectormap.MapView
import com.kakao.vectormap.camera.*
import com.kakao.vectormap.label.*
import com.kakao.vectormap.label.LabelOptions
import com.kakao.vectormap.label.LabelStyle
import com.kakao.vectormap.label.LabelStyles
import com.kakao.vectormap.label.LabelTextBuilder
import android.animation.ValueAnimator
import android.view.animation.DecelerateInterpolator
import android.graphics.Bitmap
import android.os.Environment
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date

class KakaoMapPlatform(
    context: Context,
    private val creationParams: Map<String, Any?>?,
    messenger: BinaryMessenger,
    id: Int
) : PlatformView, MethodChannel.MethodCallHandler {

    private val methodChannel: MethodChannel = MethodChannel(messenger, "map-kakao/$id")
    private val nativeView: View
    private var mapView: MapView? = null
    private var kakaoMap: KakaoMap? = null

    private val appContext: Context = context
    private var labelStyles: LabelStyles? = null
    private var userLabelStyles: LabelStyles? = null
    private var prevCameraPos: CameraPosition? = null
    private var currentZoom: Int = 16
    private val userLabelId: Int = 999999

    // 현위치 좌표 저장
    private var lastUserLat: Double? = null
    private var lastUserLon: Double? = null

    // Polyline state
    private var polylinePoints: MutableList<LatLng> = mutableListOf()
    private var polyline: Any? = null

    init {
        methodChannel.setMethodCallHandler(this)
        val inflater = LayoutInflater.from(context)
        nativeView = inflater.inflate(R.layout.layout_kakao_map, null)
    }

    override fun onFlutterViewAttached(flutterView: View) {
        mapView = nativeView.findViewById(R.id.map_kakao)
        mapView!!.start(object : MapLifeCycleCallback() {
            override fun onMapDestroy() {}
            override fun onMapPaused() {}
            override fun onMapResumed() {}
            override fun onMapError(error: Exception) {
                Log.e("KakaoMap", "error: ${error.message}")
            }
        }, object : KakaoMapReadyCallback() {
            override fun onMapReady(map: KakaoMap) {
                kakaoMap = map

                // 기본 라벨 스타일
                labelStyles = kakaoMap!!.labelManager!!.addLabelStyles(
                    LabelStyles.from(
                        LabelStyle.from()
                            .setTextStyles(dpToPx(28), 0xFF1976D2.toInt()) // 파랑
                            .setApplyDpScale(false)
                    )
                )

                // 사용자(현위치) 전용 스타일
                userLabelStyles = kakaoMap!!.labelManager!!.addLabelStyles(
                    LabelStyles.from(
                        LabelStyle.from()
                            .setTextStyles(dpToPx(28), 0xFF2962FF.toInt()) // 진한 파랑
                            .setApplyDpScale(false)
                    )
                )

                // 초기 카메라 위치
                if (prevCameraPos == null) {
                    moveCamera(
                        creationParams?.get("lat").toString().toDouble(),
                        creationParams?.get("lon").toString().toDouble(),
                        creationParams?.get("zoomLevel").toString().toInt()
                    )
                } else {
                    kakaoMap!!.moveCamera(CameraUpdateFactory.newCameraPosition(prevCameraPos!!))
                }

                // 라벨 클릭 이벤트
                kakaoMap!!.setOnLabelClickListener { _, _, clicked ->
                    val tagId = clicked?.tag as? Int ?: return@setOnLabelClickListener false
                    methodChannel.invokeMethod("onLabelTabbed", mapOf("id" to tagId))
                    true
                }

                // 카메라 이동 끝 이벤트
                kakaoMap!!.setOnCameraMoveEndListener { _, position, _ ->
                    prevCameraPos = position
                    currentZoom = position.zoomLevel
                    try {
                        methodChannel.invokeMethod(
                            "onCameraIdle",
                            mapOf(
                                "lat" to position.position.latitude,
                                "lon" to position.position.longitude,
                                "zoom" to position.zoomLevel
                            )
                        )
                    } catch (_: Exception) {}
                }

                methodChannel.invokeMethod("onMapInit", null)
            }
        })
    }

    override fun getView(): View = nativeView

    override fun dispose() {}

    private fun dpToPx(dp: Int): Int {
        val displayMetrics: DisplayMetrics = this.appContext.resources.displayMetrics
        return (dp * displayMetrics.density).toInt()
    }

    private fun moveCamera(lat: Double, lon: Double, zoomLevel: Int) {
        val cameraPos = CameraPosition.from(
            CameraPosition.Builder()
                .setZoomLevel(zoomLevel)
                .setPosition(LatLng.from(lat, lon))
        )
        kakaoMap?.moveCamera(CameraUpdateFactory.newCameraPosition(cameraPos))
    }

    private fun animateCamera(lat: Double, lon: Double, zoomLevel: Int, durationMs: Int) {
        val start = kakaoMap?.cameraPosition
        val end = CameraPosition.from(
            CameraPosition.Builder()
                .setZoomLevel(zoomLevel)
                .setPosition(LatLng.from(lat, lon))
        )
        if (start == null) {
            kakaoMap?.moveCamera(CameraUpdateFactory.newCameraPosition(end))
            return
        }
        val animator = ValueAnimator.ofFloat(0f, 1f)
        animator.duration = durationMs.toLong()
        animator.interpolator = DecelerateInterpolator()
        animator.addUpdateListener { a ->
            val t = a.animatedValue as Float
            val izoom = (start.zoomLevel + (end.zoomLevel - start.zoomLevel) * t).toInt()
            val lat = start.position.latitude + (end.position.latitude - start.position.latitude) * t
            val lon = start.position.longitude + (end.position.longitude - start.position.longitude) * t
            val pos = CameraPosition.from(
                CameraPosition.Builder()
                    .setZoomLevel(izoom)
                    .setPosition(LatLng.from(lat, lon))
            )
            kakaoMap?.moveCamera(CameraUpdateFactory.newCameraPosition(pos))
        }
        animator.start()
    }

    private fun addSpotLabel(name: String, lat: Double, lng: Double, id: Int, isUser: Boolean = false) {
        val base = LabelOptions.from(LatLng.from(lat, lng))
            .setClickable(true)
            .setTag(id)

        if (isUser) {
            base.setStyles(userLabelStyles)
            base.setTexts(LabelTextBuilder().setTexts("●"))
        } else {
            base.setStyles(labelStyles)
            base.setTexts(LabelTextBuilder().setTexts("●"))
        }
        kakaoMap?.labelManager?.layer?.addLabel(base)
    }

    private fun removeAllSpotLabel() {
        kakaoMap?.labelManager?.layer?.removeAll()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "moveCamera" -> {
                val lat = call.argument<Double>("lat")
                val lon = call.argument<Double>("lon")
                val zoomLevel = call.argument<Int>("zoomLevel")
                moveCamera(lat!!, lon!!, zoomLevel!!)
                result.success(null)
            }
            "zoomBy" -> {
                val delta = call.argument<Int>("delta") ?: 0
                val newZoom = (currentZoom + delta).coerceIn(1, 20)
                val target = CameraPosition.from(
                    CameraPosition.Builder()
                        .setZoomLevel(newZoom)
                        .setPosition(prevCameraPos?.position ?: kakaoMap?.cameraPosition?.position ?: LatLng.from(33.510414,126.491353))
                )
                kakaoMap?.moveCamera(CameraUpdateFactory.newCameraPosition(target))
                currentZoom = newZoom
                result.success(null)
            }
            "animateCamera" -> {
                val lat = call.argument<Double>("lat") ?: return result.error("151","ARG","lat")
                val lon = call.argument<Double>("lon") ?: return result.error("151","ARG","lon")
                val zoom = call.argument<Int>("zoomLevel") ?: currentZoom
                val duration = call.argument<Int>("durationMs") ?: 300
                animateCamera(lat, lon, zoom, duration)
                result.success(null)
            }
            "setUserLocation" -> {
                val lat = call.argument<Double>("lat")
                val lon = call.argument<Double>("lon")
                if (lat != null && lon != null) {
                    lastUserLat = lat
                    lastUserLon = lon
                    addSpotLabel("", lat, lon, userLabelId, isUser = true)
                }
                result.success(null)
            }
            "setLabels" -> {
                val data = call.argument<List<Map<String, Any>>>("labels")
                if (data != null) {
                    removeAllSpotLabel()
                    data.forEach { item ->
                        val name = item["name"] as? String ?: "Unknown"
                        val lon = (item["lon"] as? Number)?.toDouble() ?: 0.0
                        val lat = (item["lat"] as? Number)?.toDouble() ?: 0.0
                        val id = (item["id"] as? Number)?.toInt() ?: 0
                        addSpotLabel(name, lat, lon, id, isUser = false)
                    }
                    if (lastUserLat != null && lastUserLon != null) {
                        addSpotLabel("", lastUserLat!!, lastUserLon!!, userLabelId, isUser = true)
                    }
                }
                result.success(null)
            }
            "setMarkers" -> { // ✅ 두 번째 코드에서 추가된 기능
                val data = call.argument<List<Map<String, Any>>>("markers")
                if (data != null && data.isNotEmpty()) {
                    removeAllSpotLabel()
                    val m = data.first()
                    val name = m["title"] as? String ?: "선택한 장소"
                    val lat = (m["lat"] as? Number)?.toDouble() ?: 0.0
                    val lon = (m["lon"] as? Number)?.toDouble() ?: 0.0
                    addSpotLabel(name, lat, lon, 123456, isUser = false)
                    if (lastUserLat != null && lastUserLon != null) {
                        addSpotLabel("", lastUserLat!!, lastUserLon!!, userLabelId, isUser = true)
                    }
                }
                result.success(null)
            }
            "updatePolyline" -> {
                val pts = call.argument<List<Map<String, Any>>>("points")
                if (pts != null) {
                    polylinePoints.clear()
                    pts.forEach { p ->
                        val lat = (p["lat"] as? Number)?.toDouble() ?: return@forEach
                        val lon = (p["lon"] as? Number)?.toDouble() ?: return@forEach
                        polylinePoints.add(LatLng.from(lat, lon))
                    }
                    // TODO: polyline draw/update (SDK 지원 시)
                }
                result.success(null)
            }
            "captureSnapshot" -> {
                val file = captureMapView()
                result.success(file?.absolutePath)
            }
            else -> result.notImplemented()
        }
    }

    private fun captureMapView(): File? {
        val view = mapView ?: return null
        val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(bitmap)
        view.draw(canvas)

        // Center-crop to 4:3
        val w = bitmap.width
        val h = bitmap.height
        val targetRatio = 4f / 3f
        val currentRatio = w.toFloat() / h.toFloat()
        var cropX = 0
        var cropY = 0
        var cropW = w
        var cropH = h
        if (currentRatio > targetRatio) {
            cropW = (h * targetRatio).toInt()
            cropX = (w - cropW) / 2
        } else if (currentRatio < targetRatio) {
            cropH = (w / targetRatio).toInt()
            cropY = (h - cropH) / 2
        }
        val cropped = try {
            Bitmap.createBitmap(bitmap, cropX, cropY, cropW, cropH)
        } catch (e: Exception) {
            bitmap
        }

        val sdf = SimpleDateFormat("yyyyMMdd_HHmmss")
        val name = "kakao_map_${sdf.format(Date())}.png"
        val dir = appContext.getExternalFilesDir(Environment.DIRECTORY_PICTURES)
        if (dir != null && !dir.exists()) dir.mkdirs()
        val outFile = File(dir, name)
        FileOutputStream(outFile).use { fos ->
            cropped.compress(Bitmap.CompressFormat.PNG, 100, fos)
            fos.flush()
        }
        return outFile
    }
}
