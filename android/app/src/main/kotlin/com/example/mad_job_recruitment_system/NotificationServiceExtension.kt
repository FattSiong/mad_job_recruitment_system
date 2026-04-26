package com.example.mad_job_recruitment_system

import android.app.PendingIntent
import android.content.Intent
import androidx.annotation.Keep
import androidx.core.app.NotificationCompat
import com.onesignal.notifications.IDisplayableMutableNotification
import com.onesignal.notifications.INotificationReceivedEvent
import com.onesignal.notifications.INotificationServiceExtension

@Keep
class NotificationServiceExtension : INotificationServiceExtension {
    override fun onNotificationReceived(event: INotificationReceivedEvent) {
        val notification: IDisplayableMutableNotification = event.notification
        val additionalData = notification.additionalData ?: return
        if (additionalData.optString("type", "") != "call") return

        val context = event.context
        val callIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("type", "call")
            putExtra("callID", additionalData.optString("callID", ""))
            putExtra("roomCode", additionalData.optString("roomCode", ""))
            putExtra("callerName", additionalData.optString("callerName", "Incoming Caller"))
            putExtra("callerProfilePic", additionalData.optString("callerProfilePic", ""))
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            additionalData.optString("callID", "incoming_call").hashCode(),
            callIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        notification.setExtender { builder ->
            builder
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setFullScreenIntent(pendingIntent, true)
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)
                .setOngoing(true)
                .setOnlyAlertOnce(false)
        }
    }
}
