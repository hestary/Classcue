import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { calendarManager } from '@kit.CalendarKit';
import { TodoItem } from '../model/TodoItem';

const CALENDAR_PERMISSIONS: Permissions[] = [
  'ohos.permission.READ_CALENDAR',
  'ohos.permission.WRITE_CALENDAR'
];

export class CalendarReminderService {
  static async requestPermission(context: common.UIAbilityContext): Promise<boolean> {
    const manager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    const result: PermissionRequestResult = await manager.requestPermissionsFromUser(context, CALENDAR_PERMISSIONS);
    return result.authResults.every((status: number) => status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED);
  }

  private static async getCalendar(context: common.UIAbilityContext): Promise<calendarManager.Calendar> {
    const manager: calendarManager.CalendarManager = calendarManager.getCalendarManager(context);
    return await manager.getCalendar();
  }

  static async schedule(context: common.UIAbilityContext, todo: TodoItem): Promise<number> {
    const calendar: calendarManager.Calendar = await CalendarReminderService.getCalendar(context);
    const currentConfig: calendarManager.CalendarConfig = calendar.getConfig();
    await calendar.setConfig({
      enableReminder: true,
      color: currentConfig.color
    });
    const reminderTime: number[] = [0];
    if (todo.advanceReminderDays > 0) {
      reminderTime.push(todo.advanceReminderDays * 24 * 60);
    }
    const event: calendarManager.Event = {
      type: calendarManager.EventType.IMPORTANT,
      title: todo.title,
      description: todo.note,
      location: todo.location.length > 0 ? { location: todo.location } : undefined,
      startTime: todo.dueAt,
      endTime: todo.dueAt + 30 * 60 * 1000,
      reminderTime: reminderTime,
      identifier: `locktodo-${todo.id}`
    };
    return await calendar.addEvent(event);
  }

  static async cancel(context: common.UIAbilityContext, eventId: number): Promise<void> {
    if (eventId < 0) {
      return;
    }
    try {
      const calendar: calendarManager.Calendar = await CalendarReminderService.getCalendar(context);
      await calendar.deleteEvent(eventId);
    } catch (error) {
      // The event may already have been removed in Calendar.
    }
  }
}
