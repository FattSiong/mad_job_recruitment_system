package com.example.mad_job_recruitment_system

import android.app.NotificationChannel
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

		val incomingCallsChannel = NotificationChannel(
			"incoming_calls",
			"Incoming Calls",
			NotificationManager.IMPORTANCE_HIGH
		).apply {
			description = "High priority notifications for incoming calls"
			enableVibration(true)
			setShowBadge(true)
		}

		val chatMessagesChannel = NotificationChannel(
			"chat_messages",
			"Chat Messages",
			NotificationManager.IMPORTANCE_HIGH
		).apply {
			description = "High priority notifications for chat messages"
			enableVibration(true)
			setShowBadge(true)
		}

		manager.createNotificationChannel(incomingCallsChannel)
		manager.createNotificationChannel(chatMessagesChannel)
	}
}