package com.classcue.android;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public final class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        for (TodoItem item : AppStore.loadTodos(context)) {
            ReminderScheduler.schedule(context, item);
        }
    }
}
