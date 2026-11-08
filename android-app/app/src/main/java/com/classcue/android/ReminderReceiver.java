package com.classcue.android;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.os.Build;

public final class ReminderReceiver extends BroadcastReceiver {
    public static final String CHANNEL_ID = "classcue_reminders";

    @Override
    public void onReceive(Context context, Intent intent) {
        NotificationManager manager = context.getSystemService(NotificationManager.class);
        ensureChannel(manager);
        long id = intent.getLongExtra("id", System.currentTimeMillis());
        String title = intent.getStringExtra("title");
        String note = intent.getStringExtra("note");
        String location = intent.getStringExtra("location");
        int advanceDays = intent.hasExtra("advanceDays") ? intent.getIntExtra("advanceDays", 0)
                : (intent.getBooleanExtra("advance", false) ? -1 : 0);
        StringBuilder body = new StringBuilder();
        if (advanceDays > 0) body.append("距离到期还有").append(advanceDays).append("天");
        else if (advanceDays < 0) body.append("即将到期");
        if (note != null && !note.isEmpty()) body.append(body.length() > 0 ? " · " : "").append(note);
        if (location != null && !location.isEmpty()) body.append(body.length() > 0 ? "\n" : "").append("地点：").append(location);

        Intent open = new Intent(context, MainActivity.class);
        open.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent content = PendingIntent.getActivity(context, 0, open,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        Notification notification = new Notification.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_classcue)
                .setContentTitle(title == null || title.isEmpty() ? "ClassCue 待办提醒" : title)
                .setContentText(body.length() == 0 ? "待办时间到了" : body.toString())
                .setStyle(new Notification.BigTextStyle().bigText(body.length() == 0 ? "待办时间到了" : body.toString()))
                .setCategory(Notification.CATEGORY_REMINDER)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setColor(Color.rgb(23, 107, 84))
                .setAutoCancel(true)
                .setContentIntent(content)
                .build();
        int notificationId = advanceDays == 0 ? ReminderScheduler.baseRequestCode(id)
                : ReminderScheduler.baseRequestCode(id) + (advanceDays < 0 ? 31 : 100 + advanceDays);
        manager.notify(notificationId, notification);
    }

    public static void ensureChannel(NotificationManager manager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(CHANNEL_ID, "待办提醒",
                    NotificationManager.IMPORTANCE_HIGH);
            channel.setDescription("在到期前提醒课程与待办事项");
            channel.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
            channel.enableVibration(true);
            manager.createNotificationChannel(channel);
        }
    }
}
