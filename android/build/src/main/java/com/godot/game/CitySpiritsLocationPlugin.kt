package com.godot.game

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

class CitySpiritsLocationPlugin(godot: Godot) : GodotPlugin(godot), LocationListener {

	companion object {
		private const val TAG = "CitySpiritsLocation"
		private const val GPS_PROVIDER = "gps"
		private const val NETWORK_PROVIDER = "network"
		private const val INVALID_ACCURACY_METERS = 9999.0

		private val LOCATION_UPDATE_SIGNAL = SignalInfo(
			"location_update",
			java.lang.Double::class.java,
			java.lang.Double::class.java,
			java.lang.Double::class.java,
			String::class.java,
			java.lang.Long::class.java
		)
		private val LOCATION_STATUS_SIGNAL = SignalInfo(
			"location_status_changed",
			String::class.java,
			String::class.java,
			String::class.java
		)
		private val SIGNALS = setOf(
			LOCATION_UPDATE_SIGNAL,
			LOCATION_STATUS_SIGNAL
		)
	}

	private var locationManager: LocationManager? = null
	private var updatesActive = false

	override fun getPluginName() = "CitySpiritsLocationPlugin"

	override fun getPluginSignals() = SIGNALS

	@UsedByGodot
	fun startLocationUpdates(minTimeMillis: Int, minDistanceMeters: Float): Boolean {
		Log.d(TAG, "startLocationUpdates requested minTimeMs=$minTimeMillis minDistanceMeters=$minDistanceMeters")
		runOnHostThread {
			startLocationUpdatesOnHost(minTimeMillis.toLong(), minDistanceMeters)
		}
		return true
	}

	@UsedByGodot
	fun stopLocationUpdates() {
		Log.d(TAG, "stopLocationUpdates requested")
		runOnHostThread {
			stopLocationUpdatesOnHost()
		}
	}

	override fun onLocationChanged(location: Location) {
		Log.d(TAG, "onLocationChanged ${formatLocation(location)}")
		emitLocationUpdate(location)
	}

	override fun onProviderEnabled(provider: String) {
		Log.d(TAG, "onProviderEnabled provider=$provider")
		emitSignal("location_status_changed", "provider_enabled", "Location provider enabled", provider)
		emitLastKnownLocationIfAvailable(provider)
	}

	override fun onProviderDisabled(provider: String) {
		Log.d(TAG, "onProviderDisabled provider=$provider")
		emitSignal("location_status_changed", "provider_disabled", "Location provider disabled", provider)
	}

	@Suppress("DEPRECATION")
	override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {
	}

	override fun onMainResume() {
		super.onMainResume()
		Log.d(TAG, "onMainResume updatesActive=$updatesActive")
		if (updatesActive) {
			runOnHostThread {
				emitLastKnownLocationIfAvailable(GPS_PROVIDER)
				emitLastKnownLocationIfAvailable(NETWORK_PROVIDER)
			}
		}
	}

	override fun onGodotTerminating() {
		stopLocationUpdatesOnHost()
		super.onGodotTerminating()
	}

	@SuppressLint("MissingPermission")
	private fun startLocationUpdatesOnHost(minTimeMillis: Long, minDistanceMeters: Float) {
		Log.d(TAG, "startLocationUpdatesOnHost permission=${hasLocationPermission()}")
		if (!hasLocationPermission()) {
			Log.w(TAG, "Location permission missing")
			emitSignal("location_status_changed", "permission_missing", "Android location permission missing", "")
			return
		}

		val manager = ensureLocationManager()
		if (manager == null) {
			Log.w(TAG, "Location manager unavailable")
			emitSignal("location_status_changed", "providers_unavailable", "Android location manager unavailable", "")
			return
		}

		stopLocationUpdatesOnHost()

		val gpsEnabled = manager.isProviderEnabled(GPS_PROVIDER)
		val networkEnabled = manager.isProviderEnabled(NETWORK_PROVIDER)
		Log.d(TAG, "provider availability gps=$gpsEnabled network=$networkEnabled")

		var subscribedProviderCount = 0
		if (gpsEnabled) {
			manager.requestLocationUpdates(GPS_PROVIDER, minTimeMillis, minDistanceMeters, this, Looper.getMainLooper())
			Log.d(TAG, "requestLocationUpdates provider=$GPS_PROVIDER")
			emitLastKnownLocationIfAvailable(GPS_PROVIDER)
			subscribedProviderCount += 1
		}
		if (networkEnabled) {
			manager.requestLocationUpdates(NETWORK_PROVIDER, minTimeMillis, minDistanceMeters, this, Looper.getMainLooper())
			Log.d(TAG, "requestLocationUpdates provider=$NETWORK_PROVIDER")
			emitLastKnownLocationIfAvailable(NETWORK_PROVIDER)
			subscribedProviderCount += 1
		}

		updatesActive = subscribedProviderCount > 0
		if (updatesActive) {
			Log.d(TAG, "live location updates active subscribedProviders=$subscribedProviderCount")
			emitSignal("location_status_changed", "updates_started", "Android live location updates active", "")
		} else {
			Log.w(TAG, "No enabled Android location providers")
			emitSignal("location_status_changed", "providers_unavailable", "No enabled Android location providers", "")
		}
	}

	@SuppressLint("MissingPermission")
	private fun emitLastKnownLocationIfAvailable(provider: String) {
		if (!hasLocationPermission()) {
			Log.d(TAG, "emitLastKnownLocationIfAvailable skipped: permission missing provider=$provider")
			return
		}

		val manager = ensureLocationManager() ?: return
		val location = manager.getLastKnownLocation(provider)
		if (location == null) {
			Log.d(TAG, "lastKnownLocation unavailable provider=$provider")
			return
		}
		Log.d(TAG, "emitLastKnownLocationIfAvailable provider=$provider ${formatLocation(location)}")
		emitLocationUpdate(location)
	}

	private fun stopLocationUpdatesOnHost() {
		val manager = locationManager ?: return
		manager.removeUpdates(this)
		updatesActive = false
		Log.d(TAG, "stopLocationUpdatesOnHost removed listeners")
	}

	private fun ensureLocationManager(): LocationManager? {
		if (locationManager == null) {
			val hostActivity = activity
			if (hostActivity == null) {
				Log.w(TAG, "ensureLocationManager skipped: activity unavailable")
				return null
			}
			locationManager = hostActivity.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
			Log.d(TAG, "ensureLocationManager created=${locationManager != null}")
		}
		return locationManager
	}

	private fun hasLocationPermission(): Boolean {
		val hostActivity = activity
		if (hostActivity == null) {
			Log.w(TAG, "hasLocationPermission false: activity unavailable")
			return false
		}

		val fineLocationGranted = ContextCompat.checkSelfPermission(
			hostActivity,
			Manifest.permission.ACCESS_FINE_LOCATION
		) == PackageManager.PERMISSION_GRANTED
		val coarseLocationGranted = ContextCompat.checkSelfPermission(
			hostActivity,
			Manifest.permission.ACCESS_COARSE_LOCATION
		) == PackageManager.PERMISSION_GRANTED
		return fineLocationGranted || coarseLocationGranted
	}

	private fun emitLocationUpdate(location: Location) {
		val accuracy = if (location.hasAccuracy()) {
			location.accuracy.toDouble()
		} else {
			INVALID_ACCURACY_METERS
		}
		val provider = location.provider ?: ""
		emitSignal(
			"location_update",
			location.latitude,
			location.longitude,
			accuracy,
			provider,
			location.time
		)
		Log.d(TAG, "emitSignal location_update ${formatLocation(location)}")
	}

	private fun formatLocation(location: Location): String {
		val accuracy = if (location.hasAccuracy()) location.accuracy else INVALID_ACCURACY_METERS.toFloat()
		val ageMillis = System.currentTimeMillis() - location.time
		return "provider=${location.provider} lat=${location.latitude} lon=${location.longitude} acc=${accuracy}m age=${ageMillis}ms"
	}
}
