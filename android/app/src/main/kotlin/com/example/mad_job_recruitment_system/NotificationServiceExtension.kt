package com.example.mad_job_recruitment_system

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.onesignal.notifications.INotificationReceivedEvent
import com.onesignal.notifications.INotificationServiceExtension

class NotificationServiceExtension : INotificationServiceExtension {
    override fun onNotificationReceived(event: INotificationReceivedEvent) {
        val additionalData = event.notification.additionalData ?: return
        val type = additionalData.optString("type", "")
        if (type != "call") return

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

        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val requestCode = additionalData.optString("callID", "incoming_call").hashCode()
        val pendingIntent = PendingIntent.getActivity(
            context,
            requestCode,
            callIntent,
            pendingIntentFlags
        )

        event.notification.setExtender { builder ->
            builder.setCategory(NotificationCompat.CATEGORY_CALL)
            builder.setPriority(NotificationCompat.PRIORITY_MAX)
            builder.setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            builder.setFullScreenIntent(pendingIntent, true)
            builder.setContentIntent(pendingIntent)
            builder.setAutoCancel(true)
            builder.setOngoing(true)
            builder.setOnlyAlertOnce(false)
        }
    }
}
