import { notificationManager } from '@kit.NotificationKit';
import { TodoItem } from '../model/TodoItem';

const NOTIFICATION_ID_BASE: number = 1000000000;
const NOTIFICATION_ID_RANGE: number = 900000000;

export class LockScreenNotificationService {
  private static notificationId(todoId: number): number {
    return NOTIFICATION_ID_BASE + todoId % NOTIFICATION_ID_RANGE;
  }

  private static pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  private static formatDueAt(timestamp: number): string {
    const due: Date = new Date(timestamp);
    return `${due.getMonth() + 1}月${due.getDate()}日 ${LockScreenNotificationService.pad(due.getHours())}:${LockScreenNotificationService.pad(due.getMinutes())}`;
  }

  static async publish(todo: TodoItem): Promise<void> {
    if (todo.completed || !todo.reminderEnabled) {
      await LockScreenNotificationService.cancel(todo.id);
      return;
    }

    const dueText: string = LockScreenNotificationService.formatDueAt(todo.dueAt);
    const locationText: string = todo.location.length > 0 ? ` · ${todo.location}` : '';
    const noteText: string = todo.note.length > 0 ? `\n${todo.note}` : '';
    await notificationManager.publish({
      id: LockScreenNotificationService.notificationId(todo.id),
      notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
      tapDismissed: false,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_LONG_TEXT,
        longText: {
          title: `待办：${todo.title}`,
          text: `${dueText}${locationText}`,
          longText: `${dueText}${locationText}${noteText}`,
          briefText: dueText,
          expandedTitle: `待办：${todo.title}`
        }
      }
    });
  }

  static async cancel(todoId: number): Promise<void> {
    try {
      await notificationManager.cancel(LockScreenNotificationService.notificationId(todoId));
    } catch (error) {
      // The notification may have been cleared by the user already.
    }
  }

  static async restorePending(todos: TodoItem[]): Promise<void> {
    if (!await notificationManager.isNotificationEnabled()) {
      return;
    }
    for (const todo of todos) {
      if (todo.reminderEnabled && !todo.completed) {
        try {
          await LockScreenNotificationService.publish(todo);
        } catch (error) {
          // One failed notification must not prevent the remaining todos from loading.
        }
      }
    }
  }
}
