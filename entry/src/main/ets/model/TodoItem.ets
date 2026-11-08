export const TODO_KIND_GENERAL: string = 'GENERAL';
export const TODO_KIND_HOMEWORK: string = 'HOMEWORK';
export const TODO_KIND_EXAM: string = 'EXAM';
export const TODO_KIND_QUIZ: string = 'QUIZ';

export class TodoItem {
  id: number = 0;
  title: string = '';
  note: string = '';
  location: string = '';
  dueAt: number = 0;
  imageUris: string[] = [];
  completed: boolean = false;
  reminderEnabled: boolean = true;
  reminderId: number = -1;
  advanceReminderDays: number = 0;
  advanceReminderId: number = -1;
  calendarEventId: number = -1;
  createdAt: number = 0;
  courseName: string = '';
  taskKind: string = TODO_KIND_GENERAL;
  source: string = 'manual';
  sourceUrl: string = '';
  platformLabel: string = '';

  constructor(id: number, title: string, note: string, location: string, dueAt: number,
    imageUris: string[], completed: boolean, reminderEnabled: boolean, reminderId: number,
    advanceReminderDays: number, advanceReminderId: number, calendarEventId: number, createdAt: number,
    courseName: string = '', taskKind: string = TODO_KIND_GENERAL, source: string = 'manual',
    sourceUrl: string = '', platformLabel: string = '') {
    this.id = id;
    this.title = title;
    this.note = note;
    this.location = location;
    this.dueAt = dueAt;
    this.imageUris = imageUris;
    this.completed = completed;
    this.reminderEnabled = reminderEnabled;
    this.reminderId = reminderId;
    this.advanceReminderDays = advanceReminderDays;
    this.advanceReminderId = advanceReminderId;
    this.calendarEventId = calendarEventId;
    this.createdAt = createdAt;
    this.courseName = courseName;
    this.taskKind = taskKind;
    this.source = source;
    this.sourceUrl = sourceUrl;
    this.platformLabel = platformLabel;
  }

  static fromJson(item: TodoItem): TodoItem {
    return new TodoItem(
      item.id,
      item.title,
      item.note,
      item.location ?? '',
      item.dueAt,
      item.imageUris ?? [],
      item.completed,
      item.reminderEnabled ?? true,
      item.reminderId ?? -1,
      item.advanceReminderDays ?? 0,
      item.advanceReminderId ?? -1,
      item.calendarEventId ?? -1,
      item.createdAt,
      item.courseName ?? '',
      item.taskKind ?? TODO_KIND_GENERAL,
      item.source ?? 'manual',
      item.sourceUrl ?? '',
      item.platformLabel ?? ''
    );
  }
}
