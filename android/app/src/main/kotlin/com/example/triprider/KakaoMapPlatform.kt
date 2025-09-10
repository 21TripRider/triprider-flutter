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
// Additional Kakao Vector Map namespaces
import com.kakao.vectormap.animation.*
import com.kakao.vectormap.camera.*
import com.kakao.vectormap.label.*
import com.kakao.vectormap.label.animation.*
import com.kakao.vectormap.mapwidget.*
import com.kakao.vectormap.mapwidget.component.*
import com.kakao.vectormap.route.*
import com.kakao.vectormap.shape.*
import com.kakao.vectormap.shape.animation.*
import android.animation.ValueAnimator
import android.view.animation.DecelerateInterpolator
import android.graphics.Bitmap
import android.os.Environment
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import com.kakao.vectormap.camera.CameraPosition
import com.kakao.vectormap.camera.CameraUpdateFactory
import com.kakao.vectormap.label.LabelOptions
import com.kakao.vectormap.label.LabelStyle
import com.kakao.vectormap.label.LabelStyles
import com.kakao.vectormap.label.LabelTextBuilder
import com.example.triprider.R

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

    // Polyline state (as-is)
    private var polylineId: Int = 10001
    private var polylinePoints: MutableList<LatLng> = mutableListOf()
    private var polyline: Any? = null
    private val appContext: Context = context

    private var prevCameraPos: CameraPosition? = null
    private var currentZoom: Int = 16

    // ▼ POI 마커/라벨 상태
    private val markerLabels: MutableList<com.kakao.vectormap.label.Label> = mutableListOf()
    private var markerStyleBlue: LabelStyles? = null
    private var markerStyleRed: LabelStyles? = null
    private var markerStyleGreen: LabelStyles? = null

    // ▼ 사용자 위치 전용 라벨(Glow / Ring / Core)
    private var userGlowLabel: com.kakao.vectormap.label.Label? = null
    private var userRingLabel: com.kakao.vectormap.label.Label? = null
    private var userCoreLabel: com.kakao.vectormap.label.Label? = null

    // ▼ 사용자 위치 스타일
    private var userStyleGlow: LabelStyles? = null        // 연핑크 글로우
    private var userStyleRingWhite: LabelStyles? = null   // 하얀 링(디스크)
    private var userStyleCorePink: LabelStyles? = null    // 코어 핑크

    // ▼ 터치 상호작용 제어 (기본: 가능)
    private var isTouchable: Boolean = true

    init {
        methodChannel.setMethodCallHandler(this)
        val inflater = LayoutInflater.from(context)
        nativeView = inflater.inflate(R.layout.layout_kakao_map, null)
    }

    override fun onFlutterViewAttached(flutterView: View) {
        mapView = nativeView.findViewById(R.id.map_kakao)

        // ✅ 지도 터치 차단용 리스너: isTouchable=false면 모든 터치 소비
        mapView!!.setOnTouchListener { _, _ -> !isTouchable }

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

                // ▼ 마커 색상별 스타일
                markerStyleBlue = kakaoMap!!.labelManager!!.addLabelStyles(
                    LabelStyles.from(
                        LabelStyle.from()
                            .setTextStyles(dpToPx(30), 0xFF1E88E5.toInt())
                            .setApplyDpScale(false)
                    )
                )
                markerStyleRed = kakaoMap!!.labelManager!!.addLabelStyles(
                    LabelStyles.from(
                        LabelStyle.from()
                            .setTextStyles(dpToPx(30), 0xFFE53935.toInt())
                            .setApplyDpScale(false)
                    )
                )
                markerStyleGreen = kakaoMap!!.labelManager!!.addLabelStyles(
                    LabelStyles.from(
                        LabelStyle.from()
                            .setTextStyles(dpToPx(30), 0xFF43A047.toInt())
                            .setApplyDpScale(false)
                    )
                )

                // ▼ 사용자 위치(핑크 코어 + 하얀 링 + 핑크 글로우) 스타일
                userStyleGlow = kakaoMap!!.labelManager!!.addLabelStyles(
                    LabelStyles.from(
                        LabelStyle.from()
                            .setTextStyles(dpToPx(34), 0x44FF4E6B.toInt()) // 연핑크 오라
                            .setApplyDpScale(false)
                    )
                )
                userStyleRingWhite = kakaoMap!!.labelManager!!.addLabelStyles(
                    LabelStyles.from(
                        LabelStyle.from()
                            .setTextStyles(dpToPx(26), 0xFFFFFFFF.toInt()) // 흰 디스크(링 효과)
                            .setApplyDpScale(false)
                    )
                )
                userStyleCorePink = kakaoMap!!.labelManager!!.addLabelStyles(
                    LabelStyles.from(
                        LabelStyle.from()
                            .setTextStyles(dpToPx(18), 0xFFFF4E6B.toInt()) // 코어 핑크
                            .setApplyDpScale(false)
                    )
                )

                if (prevCameraPos == null) {
                    moveCamera(
                        creationParams?.get("lat").toString().toDouble(),
                        creationParams?.get("lon").toString().toDouble(),
                        creationParams?.get("zoomLevel").toString().toInt()
                    )
                } else {
                    kakaoMap!!.moveCamera(CameraUpdateFactory.newCameraPosition(prevCameraPos!!))
                }

                kakaoMap!!.setOnLabelClickListener { _, _, clicked ->
                    val tagId = clicked?.tag as? Int ?: return@setOnLabelClickListener false
                    methodChannel.invokeMethod("onLabelTabbed", mapOf("id" to tagId))
                    true
                }

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
            val latI = start.position.latitude + (end.position.latitude - start.position.latitude) * t
            val lonI = start.position.longitude + (end.position.longitude - start.position.longitude) * t
            val pos = CameraPosition.from(
                CameraPosition.Builder()
                    .setZoomLevel(izoom)
                    .setPosition(LatLng.from(latI, lonI))
            )
            kakaoMap?.moveCamera(CameraUpdateFactory.newCameraPosition(pos))
        }
        animator.start()
    }

    // ▼ 스타일 선택(POI)
    private fun styleForColor(name: String?): LabelStyles? = when (name?.lowercase()) {
        "red" -> markerStyleRed
        "green" -> markerStyleGreen
        else -> markerStyleBlue
    }

    private fun addMarker(lat: Double, lon: Double, id: Int, color: String?) {
        val opt = LabelOptions.from(LatLng.from(lat, lon))
            .setClickable(true)
            .setTag(id)
            .setStyles(styleForColor(color))
            .setTexts(LabelTextBuilder().setTexts("\uD83D\uDCCD")) // 📍
        kakaoMap?.labelManager?.layer?.addLabel(opt)?.let { markerLabels.add(it) }
    }

    private fun clearMarkersOnly() {
        for (lb in markerLabels.toList()) {
            runCatching { lb.javaClass.getMethod("remove").invoke(lb) }
                .onFailure { runCatching { kakaoMap?.labelManager?.layer?.remove(lb) } }
        }
        markerLabels.clear()
    }

    // ▼ 사용자 위치 라벨(Glow → Ring → Core) 고정 순서로 항상 재생성
    private fun upsertUserLabel(lat: Double, lon: Double) {
        val layer = kakaoMap?.labelManager?.layer ?: return
        val pos = LatLng.from(lat, lon)
        val dot = "\u25CF" // ●

        fun removeIfExists(label: com.kakao.vectormap.label.Label?) {
            if (label == null) return
            runCatching { label.javaClass.getMethod("remove").invoke(label) }
                .onFailure { runCatching { layer.remove(label) } }
        }

        // 순서가 섞이지 않도록 전부 지우고 같은 순서로 다시 추가
        removeIfExists(userGlowLabel)
        removeIfExists(userRingLabel)
        removeIfExists(userCoreLabel)

        userGlowLabel = layer.addLabel(
            LabelOptions.from(pos)
                .setClickable(false)
                .setStyles(userStyleGlow)
                .setTexts(LabelTextBuilder().setTexts(dot))
        )
        userRingLabel = layer.addLabel(
            LabelOptions.from(pos)
                .setClickable(false)
                .setStyles(userStyleRingWhite)
                .setTexts(LabelTextBuilder().setTexts(dot))
        )
        userCoreLabel = layer.addLabel(
            LabelOptions.from(pos)
                .setClickable(false)
                .setStyles(userStyleCorePink)
                .setTexts(LabelTextBuilder().setTexts(dot))
        )
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "moveCamera" -> {
                val lat = call.argument<Double>("lat")
                val lon = call.argument<Double>("lon")
                val zoomLevel = call.argument<Int>("zoomLevel")
                try {
                    moveCamera(lat!!, lon!!, zoomLevel!!)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("100", "METHOD ERROR", "moveCamera error occur")
                }
            }
            "zoomBy" -> {
                val delta = call.argument<Int>("delta") ?: 0
                try {
                    val newZoom = (currentZoom + delta).coerceIn(1, 20)
                    val target = CameraPosition.from(
                        CameraPosition.Builder()
                            .setZoomLevel(newZoom)
                            .setPosition(
                                prevCameraPos?.position
                                    ?: kakaoMap?.cameraPosition?.position
                                    ?: LatLng.from(33.510414, 126.491353)
                            )
                    )
                    kakaoMap?.moveCamera(CameraUpdateFactory.newCameraPosition(target))
                    currentZoom = newZoom
                    result.success(null)
                } catch (e: Exception) {
                    result.error("150", "METHOD ERROR", "zoomBy error")
                }
            }
            "animateCamera" -> {
                val lat = call.argument<Double>("lat") ?: return result.error("151","ARG","lat")
                val lon = call.argument<Double>("lon") ?: return result.error("151","ARG","lon")
                val zoom = call.argument<Int>("zoomLevel") ?: currentZoom
                val duration = call.argument<Int>("durationMs") ?: 300
                try {
                    animateCamera(lat, lon, zoom, duration)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("152", "METHOD ERROR", "animateCamera error")
                }
            }
            "fitBounds" -> {
                val pts = call.argument<List<Map<String, Any>>>("points")
                val padding = call.argument<Int>("padding") ?: 24
                if (pts == null || pts.isEmpty()) {
                    result.error("161", "ARG", "empty points")
                    return
                }
                try {
                    val builderClass = Class.forName("com.kakao.vectormap.camera.CameraBounds")
                    val fromMethod = builderClass.getMethod("from", MutableList::class.java, Int::class.javaPrimitiveType)
                    val list: MutableList<LatLng> = mutableListOf()
                    pts.forEach { p ->
                        val la = (p["lat"] as? Number)?.toDouble() ?: return@forEach
                        val lo = (p["lon"] as? Number)?.toDouble() ?: return@forEach
                        list.add(LatLng.from(la, lo))
                    }
                    val bounds = fromMethod.invoke(null, list, padding)
                    val updateFactory = Class.forName("com.kakao.vectormap.camera.CameraUpdateFactory")
                    val newBounds = updateFactory.getMethod("newBounds", builderClass)
                    val update = newBounds.invoke(null, bounds)
                    kakaoMap?.moveCamera(update as com.kakao.vectormap.camera.CameraUpdate)
                    result.success(null)
                } catch (e: Exception) {
                    try {
                        var minLat = 90.0; var maxLat = -90.0; var minLon = 180.0; var maxLon = -180.0
                        listOf(pts).flatten().forEach { p ->
                            val la = (p["lat"] as Number).toDouble(); val lo = (p["lon"] as Number).toDouble()
                            if (la < minLat) minLat = la; if (la > maxLat) maxLat = la
                            if (lo < minLon) minLon = lo; if (lo > maxLon) maxLon = lo
                        }
                        val cLat = (minLat + maxLat) / 2.0
                        val cLon = (minLon + maxLon) / 2.0
                        val span = maxOf(maxLat - minLat, maxLon - minLon)
                        var zoom = 16
                        if (span > 0.5) zoom = 9 else if (span > 0.25) zoom = 10 else if (span > 0.1) zoom = 11 else if (span > 0.05) zoom = 12 else if (span > 0.02) zoom = 13 else if (span > 0.01) zoom = 14 else if (span > 0.005) zoom = 15 else zoom = 16
                        moveCamera(cLat, cLon, zoom)
                        result.success(null)
                    } catch (_: Exception) {
                        result.error("160", "METHOD ERROR", "fitBounds error")
                    }
                }
            }
            "updatePolyline" -> {
                val pts = call.argument<List<Map<String, Any>>>("points")
                if (pts == null) {
                    result.error("131", "METHOD ERROR", "points null")
                    return
                }
                try {
                    polylinePoints.clear()
                    pts.forEach { p ->
                        val la = (p["lat"] as? Number)?.toDouble() ?: return@forEach
                        val lo = (p["lon"] as? Number)?.toDouble() ?: return@forEach
                        polylinePoints.add(LatLng.from(la, lo))
                    }

                    try {
                        val layer = kakaoMap?.shapeManager?.layer
                        if (layer != null) {
                            val optionsClass = Class.forName("com.kakao.vectormap.shape.PolylineOptions")
                            val fromMethod = optionsClass.getMethod("from", MutableList::class.java)
                            val options = fromMethod.invoke(null, polylinePoints)
                            runCatching {
                                optionsClass.getMethod("setWidth", Int::class.javaPrimitiveType).invoke(options, dpToPx(4))
                            }
                            runCatching {
                                optionsClass.getMethod("setColor", Int::class.javaPrimitiveType).invoke(options, 0xFF1976D2.toInt())
                            }

                            if (polyline == null) {
                                val addMethod = layer.javaClass.getMethod("addPolyline", optionsClass)
                                polyline = addMethod.invoke(layer, options)
                            } else {
                                runCatching {
                                    val setMethod = polyline!!::class.java.getMethod("setCoords", MutableList::class.java)
                                    setMethod.invoke(polyline, polylinePoints)
                                }.onFailure {
                                    runCatching {
                                        val setMethod2 = polyline!!::class.java.getMethod("setPoints", MutableList::class.java)
                                        setMethod2.invoke(polyline, polylinePoints)
                                    }
                                }
                            }
                            result.success(null)
                            return
                        }
                    } catch (_: Exception) {}

                    result.success(null)
                } catch (e: Exception) {
                    result.error("130", "METHOD ERROR", "updatePolyline error")
                }
            }
            "captureSnapshot" -> {
                try {
                    val file = captureMapView()
                    result.success(file?.absolutePath)
                } catch (e: Exception) {
                    result.error("140", "METHOD ERROR", "captureSnapshot error")
                }
            }
            "setUserLocation" -> {
                val lat = call.argument<Double>("lat")
                val lon = call.argument<Double>("lon")
                try {
                    if (lat != null && lon != null) {
                        // ✅ 사용자 위치 마커(Glow + Ring + Core) 갱신 — 순서 고정
                        upsertUserLabel(lat, lon)
                    }
                    result.success(null)
                } catch (e: Exception) {
                    result.error("170", "METHOD ERROR", "setUserLocation error")
                }
            }
            "setLabels" -> {
                val items = call.argument<List<Map<String, Any>>>("labels") ?: emptyList()
                try {
                    clearMarkersOnly()
                    items.forEach { m ->
                        val la = (m["lat"] as? Number)?.toDouble() ?: return@forEach
                        val lo = (m["lon"] as? Number)?.toDouble() ?: return@forEach
                        val id  = (m["id"] as? Number)?.toInt() ?: 0
                        addMarker(la, lo, id, "blue")
                    }
                    result.success(null)
                } catch (e: Exception) {
                    result.error("190", "METHOD ERROR", "setLabels error")
                }
            }
            "setMarkers" -> {
                val items = call.argument<List<Map<String, Any>>>("markers") ?: emptyList()
                try {
                    clearMarkersOnly()
                    items.forEach { m ->
                        val la = (m["lat"] as? Number)?.toDouble() ?: return@forEach
                        val lo = (m["lon"] as? Number)?.toDouble() ?: return@forEach
                        val id  = (m["id"] as? Number)?.toInt() ?: 0
                        val color = (m["color"] as? String)
                        addMarker(la, lo, id, color)
                    }
                    result.success(null)
                } catch (e: Exception) {
                    result.error("180", "METHOD ERROR", "setMarkers error")
                }
            }
            "clearMarkers" -> {
                clearMarkersOnly()
                result.success(null)
            }
            "removeAllSpotLabel" -> { // ✅ 필터 해제 시 POI 마커 전체 삭제
                clearMarkersOnly()
                result.success(null)
            }
            // ✅ 새로 추가: 터치 상호작용 on/off
            "setInteractive" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                isTouchable = enabled
                mapView?.setOnTouchListener { _, _ -> !isTouchable }
                result.success(null)
            }
            // ✅ Dart에서 호출해도 에러 안 나게 no-op 처리
            "setUserLocationVisible" -> {
                result.success(null)
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
