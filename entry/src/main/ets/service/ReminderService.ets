import { common } from '@kit.AbilityKit';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { TodoItem } from '../model/TodoItem';

const BUNDLE_NAME: string = 'com.example.locktodo';

export class ReminderService {
  static async requestNotificationPermission(context: common.UIAbilityContext): Promise<boolean> {
    const enabled: boolean = await notificationManager.isNotificationEnabled();
    if (enabled) {
      return true;
    }
    try {
      await notificationManager.requestEnableNotification(context);
      return await notificationManager.isNotificationEnabled();
    } catch (error) {
      return false;
    }
  }

  private static async scheduleAt(todo: TodoItem, remindAt: number, advance: boolean): Promise<number> {
    if (remindAt <= Date.now() || todo.completed) {
      return -1;
    }

    const due: Date = new Date(remindAt);
    const locationSuffix: string = todo.location.length > 0 ? ` · ${todo.location}` : '';
    const content: string = advance
      ? `${todo.title} · ${todo.advanceReminderDays}天后到期${locationSuffix}`
      : `${todo.title}${locationSuffix}`;
    const request: reminderAgentManager.ReminderRequestCalendar = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
      dateTime: {
        year: due.getFullYear(),
        month: due.getMonth() + 1,
        day: due.getDate(),
        hour: due.getHours(),
        minute: due.getMinutes(),
        second: 0
      },
      title: advance ? '待办即将到期' : '待办提醒',
      content: content,
      expiredContent: advance ? content : `${todo.title} 已到期${locationSuffix}`,
      snoozeContent: `稍后提醒：${todo.title}`,
      actionButton: [
        {
          title: '稍后提醒',
          type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_SNOOZE
        },
        {
          title: '关闭',
          type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE
        }
      ],
      wantAgent: {
        pkgName: BUNDLE_NAME,
        abilityName: 'EntryAbility'
      },
      ringDuration: 5,
      snoozeTimes: 3,
      timeInterval: 600,
      notificationId: ((todo.id % 1000000000) * 2 + (advance ? 1 : 0)) % 2147483647,
      slotType: notificationManager.SlotType.CONTENT_INFORMATION
    };

    return await reminderAgentManager.publishReminder(request);
  }

  static async schedule(todo: TodoItem): Promise<number> {
    return await ReminderService.scheduleAt(todo, todo.dueAt, false);
  }

  static async scheduleAdvance(todo: TodoItem): Promise<number> {
    if (todo.advanceReminderDays <= 0) {
      return -1;
    }
    const remindAt: number = todo.dueAt - todo.advanceReminderDays * 24 * 60 * 60 * 1000;
    return await ReminderService.scheduleAt(todo, remindAt, true);
  }

  static async cancel(reminderId: number): Promise<void> {
    if (reminderId < 0) {
      return;
    }
    try {
      await reminderAgentManager.cancelReminder(reminderId);
    } catch (error) {
      // The system may already have removed an expired reminder.
    }
  }

  static async cancelAll(): Promise<void> {
    await reminderAgentManager.cancelAllReminders();
  }
}
