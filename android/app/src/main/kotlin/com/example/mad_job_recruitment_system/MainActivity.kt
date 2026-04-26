package com.example.mad_job_recruitment_system

import android.app.NotificationChannel
import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
	private var incomingCallChannel: MethodChannel? = null
	private var pendingIncomingCallPayload: HashMap<String, Any>? = null

	override fun onCreate(savedInstanceState: android.os.Bundle?) {
		createNotificationChannels()
		super.onCreate(savedInstanceState)
		collectIncomingCallPayload(intent)
		applyIncomingCallWindowFlags(intent)
		dispatchPendingIncomingCall()
	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		setIntent(intent)
		collectIncomingCallPayload(intent)
		applyIncomingCallWindowFlags(intent)
		dispatchPendingIncomingCall()
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		incomingCallChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "incoming_call_bridge")
		incomingCallChannel?.setMethodCallHandler { call, result ->
			when (call.method) {
				"getInitialIncomingCall" -> {
					result.success(pendingIncomingCallPayload)
					pendingIncomingCallPayload = null
				}
				else -> result.notImplemented()
			}
		}
		dispatchPendingIncomingCall()
	}

	private fun createNotificationChannels() {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

		val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
		val channelIds = listOf("3e4bd85b-81e9-4907-b42b-34dea3a5de8f", "a0d1ce94-07ac-4bbf-95ab-dc7482dce5ee")
		channelIds.forEach { channelId ->
			val existingChannel = manager.getNotificationChannel(channelId)
			if (existingChannel != null && existingChannel.importance != NotificationManager.IMPORTANCE_HIGH) {
				manager.deleteNotificationChannel(channelId)
			}
		}

		val incomingCallsChannel = NotificationChannel(
			"3e4bd85b-81e9-4907-b42b-34dea3a5de8f",
			"Incoming Calls",
			NotificationManager.IMPORTANCE_HIGH
		).apply {
			description = "High priority notifications for incoming calls"
			enableVibration(true)
			setShowBadge(true)
			lockscreenVisibility = Notification.VISIBILITY_PUBLIC
		}

		val chatMessagesChannel = NotificationChannel(
			"a0d1ce94-07ac-4bbf-95ab-dc7482dce5ee",
			"Chat Messages",
			NotificationManager.IMPORTANCE_HIGH
		).apply {
			description = "High priority notifications for chat messages"
			enableVibration(true)
			setShowBadge(true)
			lockscreenVisibility = Notification.VISIBILITY_PUBLIC
		}

		manager.createNotificationChannel(incomingCallsChannel)
		manager.createNotificationChannel(chatMessagesChannel)
	}

	private fun collectIncomingCallPayload(intent: Intent?) {
		val extras = intent?.extras ?: return
		val type = extras.getString("type") ?: return
		if (type != "call") return

		val payload = hashMapOf<String, Any>()
		extras.getString("callID")?.let { payload["callID"] = it }
		extras.getString("roomCode")?.let { payload["roomCode"] = it }
		extras.getString("callerName")?.let { payload["callerName"] = it }
		extras.getString("callerProfilePic")?.let { payload["callerProfilePic"] = it }
		payload["type"] = "call"
		pendingIncomingCallPayload = payload
	}

	private fun applyIncomingCallWindowFlags(intent: Intent?) {
		val type = intent?.extras?.getString("type") ?: return
		if (type != "call") return

		window.addFlags(
			android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
				android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
				android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
		)
	}

	private fun dispatchPendingIncomingCall() {
		val payload = pendingIncomingCallPayload ?: return
		val channel = incomingCallChannel ?: return

		Handler(Looper.getMainLooper()).post {
			try {
				channel.invokeMethod("showIncomingCall", payload)
				pendingIncomingCallPayload = null
			} catch (_: Exception) {
			}
		}
	}
}
