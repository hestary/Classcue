package com.classcue.android;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

public final class ReminderScheduler {
    private static final int[] SUPPORTED_ADVANCE_DAYS = {1, 2, 3, 7, 14};

    public static void schedule(Context context, TodoItem item) {
        cancel(context, item.id);
        if (!item.reminderEnabled || item.completed) return;
        scheduleOne(context, item, item.dueAt, 0);
        for (int days : item.advanceReminderDays) {
            if (days <= 0) continue;
            long advanceAt = item.dueAt - days * 24L * 60L * 60L * 1000L;
            scheduleOne(context, item, advanceAt, days);
        }
    }

    private static void scheduleOne(Context context, TodoItem item, long at, int advanceDays) {
        if (at <= System.currentTimeMillis()) return;
        AlarmManager manager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        PendingIntent pending = pendingIntent(context, item, advanceDays, PendingIntent.FLAG_UPDATE_CURRENT);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !manager.canScheduleExactAlarms()) {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending);
        } else {
            manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending);
        }
    }

    public static void cancel(Context context, long itemId) {
        AlarmManager manager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        TodoItem item = new TodoItem();
        item.id = itemId;
        PendingIntent due = pendingIntent(context, item, 0, PendingIntent.FLAG_NO_CREATE);
        if (due != null) manager.cancel(due);
        for (int days : SUPPORTED_ADVANCE_DAYS) {
            PendingIntent advance = pendingIntent(context, item, days, PendingIntent.FLAG_NO_CREATE);
            if (advance != null) manager.cancel(advance);
        }
        PendingIntent legacy = pendingIntentForCode(context, item,
                baseRequestCode(item.id) + 31, -1, PendingIntent.FLAG_NO_CREATE);
        if (legacy != null) manager.cancel(legacy);
    }

    private static PendingIntent pendingIntent(Context context, TodoItem item, int advanceDays, int flag) {
        int requestCode = advanceDays == 0 ? baseRequestCode(item.id)
                : baseRequestCode(item.id) + 100 + advanceDays;
        return pendingIntentForCode(context, item, requestCode, advanceDays, flag);
    }

    private static PendingIntent pendingIntentForCode(Context context, TodoItem item, int requestCode,
                                                      int advanceDays, int flag) {
        Intent intent = new Intent(context, ReminderReceiver.class);
        intent.putExtra("id", item.id);
        intent.putExtra("title", item.title);
        intent.putExtra("note", item.note);
        intent.putExtra("location", item.location);
        intent.putExtra("advanceDays", advanceDays);
        return PendingIntent.getBroadcast(context, requestCode, intent,
                flag | PendingIntent.FLAG_IMMUTABLE);
    }

    static int baseRequestCode(long itemId) {
        return (int) (itemId ^ (itemId >>> 32));
    }

    private ReminderScheduler() {
    }
}
