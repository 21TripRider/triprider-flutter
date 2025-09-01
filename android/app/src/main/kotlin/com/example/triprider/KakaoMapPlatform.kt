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
    // Polyline state (lazy init when first update)
    private var polylineId: Int = 10001
    private var polylinePoints: MutableList<LatLng> = mutableListOf()
    private var polyline: Any? = null // hold shape polyline handle if available
    private val appContext: Context = context

    private var labelStyles: LabelStyles? = null
    private var userLabelStyles: LabelStyles? = null
    private var prevCameraPos: CameraPosition? = null
    private var currentZoom: Int = 16
    private var userLabelId: Int = 999999

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

                // 텍스트 전용 라벨 스타일 (아이콘 리소스 없이)
                // 텍스트 크기를 키워 아이콘에 준하는 시각 효과 제공 (안정 빌드)
                labelStyles = kakaoMap!!.labelManager!!.addLabelStyles(
                    LabelStyles.from(
                        LabelStyle.from()
                            .setTextStyles(dpToPx(28), 0xFF1976D2.toInt())
                            .setApplyDpScale(false)
                    )
                )

                // 사용자 위치 전용 스타일 (푸른색 원 포인트처럼 보이게)
                userLabelStyles = kakaoMap!!.labelManager!!.addLabelStyles(
                    LabelStyles.from(
                        LabelStyle.from()
                            .setTextStyles(dpToPx(28), 0xFF2962FF.toInt())
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

    private fun addSpotLabel(name: String, lat: Double, lng: Double, id: Int) {
        val base = LabelOptions.from(LatLng.from(lat, lng))
            .setClickable(true)
            .setTag(id)
        if (id == userLabelId) {
            base.setStyles(userLabelStyles)
            base.setTexts(LabelTextBuilder().setTexts("●"))
        } else {
            base.setStyles(labelStyles)
            // 가게 라벨은 텍스트 없이 아이콘처럼 (스타일만 적용)
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
                            .setPosition(prevCameraPos?.position ?: kakaoMap?.cameraPosition?.position ?: LatLng.from(33.510414,126.491353))
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
                        val lat = (p["lat"] as? Number)?.toDouble() ?: return@forEach
                        val lon = (p["lon"] as? Number)?.toDouble() ?: return@forEach
                        list.add(LatLng.from(lat, lon))
                    }
                    val bounds = fromMethod.invoke(null, list, padding)
                    val updateFactory = Class.forName("com.kakao.vectormap.camera.CameraUpdateFactory")
                    val newBounds = updateFactory.getMethod("newBounds", builderClass)
                    val update = newBounds.invoke(null, bounds)
                    kakaoMap?.moveCamera(update as com.kakao.vectormap.camera.CameraUpdate)
                    result.success(null)
                } catch (e: Exception) {
                    // Fallback: move to center & heuristic zoom
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
            "addSpotLabel" -> {
                val lat = call.argument<Double>("lat")
                val lon = call.argument<Double>("lon")
                val name = call.argument<String>("name")
                val id = call.argument<Int>("id")
                try {
                    addSpotLabel(name!!, lat!!, lon!!, id!!)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("110", "METHOD ERROR", "add spot label error occur")
                }
            }
            "removeAllSpotLabel" -> {
                removeAllSpotLabel()
                result.success(null)
            }
            "setLabels" -> {
                val data = call.argument<List<Map<String, Any>>>("labels")
                if (data == null) {
                    result.error("121", "METHOD ERROR", "data null error occur")
                    return
                }
                try {
                    removeAllSpotLabel()
                    data.forEach { item ->
                        val name = item["name"] as? String ?: "Unknown"
                        val lon = (item["lon"] as? Number)?.toDouble() ?: 0.0
                        val lat = (item["lat"] as? Number)?.toDouble() ?: 0.0
                        val id = (item["id"] as? Number)?.toInt() ?: 0
                        addSpotLabel(name, lat, lon, id)
                    }
                    result.success(null)
                } catch (e: Exception) {
                    result.error("120", "METHOD ERROR", "setLabels error occur")
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
                        val lat = (p["lat"] as? Number)?.toDouble() ?: return@forEach
                        val lon = (p["lon"] as? Number)?.toDouble() ?: return@forEach
                        polylinePoints.add(LatLng.from(lat, lon))
                    }

                    // Try shape Polyline first (SDK 2.12+)
                    try {
                        val layer = kakaoMap?.shapeManager?.layer
                        if (layer != null) {
                            val optionsClass = Class.forName("com.kakao.vectormap.shape.PolylineOptions")
                            val fromMethod = optionsClass.getMethod("from", MutableList::class.java)
                            val options = fromMethod.invoke(null, polylinePoints)
                            // try to set width/color if available
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
                                // update points
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

                    // Fallback: no-op to avoid re-adding text labels
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
                        // 사용자 위치 라벨(아이콘처럼 보이는 점)
                        addSpotLabel("", lat, lon, userLabelId)
                    }
                    result.success(null)
                } catch (e: Exception) {
                    result.error("170", "METHOD ERROR", "setUserLocation error")
                }
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
            // too wide -> crop width
            cropW = (h * targetRatio).toInt()
            cropX = (w - cropW) / 2
        } else if (currentRatio < targetRatio) {
            // too tall -> crop height
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