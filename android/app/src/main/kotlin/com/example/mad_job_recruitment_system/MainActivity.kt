package com.example.mad_job_recruitment_system

import android.app.NotificationChannel
import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity: FlutterFragmentActivity() {
	override fun onCreate(savedInstanceState: android.os.Bundle?) {
		createNotificationChannels()
		super.onCreate(savedInstanceState)
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
}
