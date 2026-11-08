import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  TodoItem,
  TODO_KIND_EXAM,
  TODO_KIND_GENERAL,
  TODO_KIND_HOMEWORK,
  TODO_KIND_QUIZ
} from '../model/TodoItem';
import { todoStore } from '../store/TodoStore';
import { courseStore } from '../store/CourseStore';
import { ReminderService } from '../service/ReminderService';
import { CalendarReminderService } from '../service/CalendarReminderService';
import { LockScreenNotificationService } from '../service/LockScreenNotificationService';
import { CoursePage } from './CoursePage';
import { CourseItem } from '../model/CourseItem';

const COLOR_BACKGROUND: string = '#F4F6F5';
const COLOR_SURFACE: string = '#FFFFFF';
const COLOR_PRIMARY: string = '#167A5B';
const COLOR_TEXT: string = '#18201D';
const COLOR_MUTED: string = '#66736E';
const COLOR_BORDER: string = '#DEE4E1';
const COLOR_DANGER: string = '#C6463D';
const COLOR_WARNING: string = '#A8610A';
const COURSE_FOLDER_OTHER: string = '__OTHER__';

@Entry
@Component
struct Index {
  @State private todos: TodoItem[] = [];
  @State private courseNames: string[] = [];
  @State private selectedCourseFolder: string = '';
  @State private folderMenuOpen: boolean = false;
  @State private mainTab: number = 0;
  @State private courseDetailOpen: boolean = false;
  @State private courseBackRequest: number = 0;
  @State private selectedTab: number = 0;
  @State private editorOpen: boolean = false;
  @State private editingId: number = -1;
  @State private draftTitle: string = '';
  @State private draftNote: string = '';
  @State private draftLocation: string = '';
  @State private draftDueAt: number = 0;
  @State private draftImages: string[] = [];
  @State private draftReminderEnabled: boolean = true;
  @State private draftAdvanceReminderDays: number = 0;
  @State private draftCourseName: string = '';
  @State private draftTaskKind: string = TODO_KIND_GENERAL;
  @State private saving: boolean = false;

  aboutToAppear(): void {
    this.loadTodos();
  }

  private closeCoursePage(): void {
    this.courseDetailOpen = false;
    this.refreshCourseFolders();
    this.mainTab = 0;
  }

  onBackPress(): boolean {
    if (this.editorOpen) {
      this.editorOpen = false;
      return true;
    }
    if (this.folderMenuOpen) {
      this.folderMenuOpen = false;
      return true;
    }
    if (this.mainTab === 1) {
      if (this.courseDetailOpen) {
        this.courseDetailOpen = false;
        this.courseBackRequest++;
        return true;
      }
      this.closeCoursePage();
      return true;
    }
    return false;
  }

  private async loadTodos(): Promise<void> {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    await todoStore.initialize(context);
    await courseStore.initialize(context);
    this.todos = await todoStore.load();
    const courses: CourseItem[] = await courseStore.loadCourses();
    this.updateCourseFolders(courses);
    if (this.migrateCourseLinks()) {
      await todoStore.save(this.todos);
    }
    await LockScreenNotificationService.restorePending(this.todos);
  }

  private migrateCourseLinks(): boolean {
    let changed: boolean = false;
    this.todos.forEach((item: TodoItem) => {
      if (item.courseName.length > 0) {
        return;
      }
      for (let index: number = 0; index < this.courseNames.length; index++) {
        const courseName: string = this.courseNames[index];
        if (item.note.indexOf(`课程：${courseName}`) >= 0) {
          item.courseName = courseName;
          if (item.taskKind === TODO_KIND_GENERAL) {
            item.taskKind = TODO_KIND_HOMEWORK;
          }
          changed = true;
          break;
        }
      }
    });
    if (changed) {
      this.todos = this.todos.slice();
    }
    return changed;
  }

  private updateCourseFolders(courses: CourseItem[]): void {
    const names: string[] = [];
    const seen: Set<string> = new Set<string>();
    courses.forEach((course: CourseItem) => {
      const name: string = course.name.trim();
      if (name.length > 0 && !seen.has(name)) {
        seen.add(name);
        names.push(name);
      }
    });
    this.courseNames = names;
  }

  private async refreshCourseFolders(): Promise<void> {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    await courseStore.initialize(context);
    this.updateCourseFolders(await courseStore.loadCourses());
  }

  private visibleTodos(): TodoItem[] {
    return this.todos
      .filter((item: TodoItem) => this.selectedTab === 0 ? !item.completed : item.completed)
      .filter((item: TodoItem) => {
        if (this.selectedCourseFolder.length === 0) {
          return true;
        }
        if (this.selectedCourseFolder === COURSE_FOLDER_OTHER) {
          return item.courseName.length === 0;
        }
        return item.courseName === this.selectedCourseFolder;
      })
      .sort((left: TodoItem, right: TodoItem) => {
        if (this.selectedTab === 0) {
          return left.dueAt - right.dueAt;
        }
        return right.createdAt - left.createdAt;
      });
  }

  private pendingCount(): number {
    return this.todos.filter((item: TodoItem) => !item.completed).length;
  }

  private folderCount(courseName: string): number {
    return this.todos.filter((item: TodoItem) => {
      const tabMatches: boolean = this.selectedTab === 0 ? !item.completed : item.completed;
      if (!tabMatches) {
        return false;
      }
      if (courseName.length === 0) {
        return true;
      }
      if (courseName === COURSE_FOLDER_OTHER) {
        return item.courseName.length === 0;
      }
      return item.courseName === courseName;
    }).length;
  }

  private pendingCourseCount(courseName: string): number {
    return this.todos.filter((item: TodoItem) => !item.completed && item.courseName === courseName).length;
  }

  private selectedFolderLabel(): string {
    if (this.selectedCourseFolder.length === 0) {
      return '全部课程';
    }
    if (this.selectedCourseFolder === COURSE_FOLDER_OTHER) {
      return '其他';
    }
    return this.selectedCourseFolder;
  }

  private taskKindLabel(kind: string): string {
    if (kind === TODO_KIND_HOMEWORK) {
      return '作业';
    }
    if (kind === TODO_KIND_EXAM) {
      return '考试';
    }
    if (kind === TODO_KIND_QUIZ) {
      return '测验';
    }
    return '待办';
  }

  private taskKindColor(kind: string): string {
    if (kind === TODO_KIND_EXAM) {
      return '#B64B46';
    }
    if (kind === TODO_KIND_HOMEWORK) {
      return '#315F80';
    }
    if (kind === TODO_KIND_QUIZ) {
      return '#805C34';
    }
    return COLOR_PRIMARY;
  }

  private courseOptions(): SelectOption[] {
    const options: SelectOption[] = [{ value: '未分类' } as SelectOption];
    this.courseNames.forEach((courseName: string) => {
      options.push({ value: courseName } as SelectOption);
    });
    return options;
  }

  private selectedCourseIndex(): number {
    if (this.draftCourseName.length === 0) {
      return 0;
    }
    const index: number = this.courseNames.indexOf(this.draftCourseName);
    return index >= 0 ? index + 1 : 0;
  }

  private taskKindOptions(): SelectOption[] {
    return [
      { value: '普通待办' } as SelectOption,
      { value: '作业' } as SelectOption,
      { value: '考试' } as SelectOption,
      { value: '测验' } as SelectOption
    ];
  }

  private selectedTaskKindIndex(): number {
    if (this.draftTaskKind === TODO_KIND_HOMEWORK) {
      return 1;
    }
    if (this.draftTaskKind === TODO_KIND_EXAM) {
      return 2;
    }
    if (this.draftTaskKind === TODO_KIND_QUIZ) {
      return 3;
    }
    return 0;
  }

  private taskKindFromIndex(index: number): string {
    if (index === 1) {
      return TODO_KIND_HOMEWORK;
    }
    if (index === 2) {
      return TODO_KIND_EXAM;
    }
    if (index === 3) {
      return TODO_KIND_QUIZ;
    }
    return TODO_KIND_GENERAL;
  }

  private pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  private formatDate(timestamp: number): string {
    const date: Date = new Date(timestamp);
    const today: Date = new Date();
    const tomorrow: Date = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1);
    const dayStart: number = new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
    const todayStart: number = new Date(today.getFullYear(), today.getMonth(), today.getDate()).getTime();
    const tomorrowStart: number = tomorrow.getTime();
    let prefix: string = `${date.getMonth() + 1}月${date.getDate()}日`;
    if (dayStart === todayStart) {
      prefix = '今天';
    } else if (dayStart === tomorrowStart) {
      prefix = '明天';
    }
    return `${prefix} ${this.pad(date.getHours())}:${this.pad(date.getMinutes())}`;
  }

  private todayLabel(): string {
    const date: Date = new Date();
    const weekdays: string[] = ['日', '一', '二', '三', '四', '五', '六'];
    return `${date.getMonth() + 1}月${date.getDate()}日  星期${weekdays[date.getDay()]}`;
  }

  private openNewTodo(): void {
    const now: Date = new Date();
    const defaultDue: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 9, 0, 0);
    this.editingId = -1;
    this.draftTitle = '';
    this.draftNote = '';
    this.draftLocation = '';
    this.draftDueAt = defaultDue.getTime();
    this.draftImages = [];
    this.draftReminderEnabled = true;
    this.draftAdvanceReminderDays = 0;
    this.draftCourseName = this.selectedCourseFolder !== COURSE_FOLDER_OTHER ? this.selectedCourseFolder : '';
    this.draftTaskKind = this.draftCourseName.length > 0 ? TODO_KIND_HOMEWORK : TODO_KIND_GENERAL;
    this.editorOpen = true;
  }

  private openCourseTodo(course: CourseItem, dueAt: number): void {
    this.editingId = -1;
    this.draftTitle = `${course.name}待办`;
    this.draftNote = course.teacher.length > 0 ? `课程：${course.name}\n教师：${course.teacher}` : `课程：${course.name}`;
    this.draftLocation = course.location;
    this.draftDueAt = dueAt;
    this.draftImages = [];
    this.draftReminderEnabled = true;
    this.draftAdvanceReminderDays = 0;
    this.draftCourseName = course.name;
    this.draftTaskKind = TODO_KIND_HOMEWORK;
    this.courseDetailOpen = false;
    this.closeCoursePage();
    this.editorOpen = true;
  }

  private openEditor(item: TodoItem): void {
    this.editingId = item.id;
    this.draftTitle = item.title;
    this.draftNote = item.note;
    this.draftLocation = item.location;
    this.draftDueAt = item.dueAt;
    this.draftImages = item.imageUris.slice();
    this.draftReminderEnabled = item.reminderEnabled;
    this.draftAdvanceReminderDays = item.advanceReminderDays;
    this.draftCourseName = item.courseName;
    this.draftTaskKind = item.taskKind;
    this.editorOpen = true;
  }

  private showDatePicker(): void {
    const selected: Date = new Date(this.draftDueAt);
    DatePickerDialog.show({
      start: new Date(2000, 0, 1),
      end: new Date(new Date().getFullYear() + 10, 11, 31),
      selected: selected,
      onAccept: (result: DatePickerResult) => {
        const current: Date = new Date(this.draftDueAt);
        this.draftDueAt = new Date(
          result.year,
          result.month,
          result.day,
          current.getHours(),
          current.getMinutes(),
          0
        ).getTime();
      }
    });
  }

  private showTimePicker(): void {
    TimePickerDialog.show({
      selected: new Date(this.draftDueAt),
      useMilitaryTime: true,
      onAccept: (result: TimePickerResult) => {
        const current: Date = new Date(this.draftDueAt);
        this.draftDueAt = new Date(
          current.getFullYear(),
          current.getMonth(),
          current.getDate(),
          result.hour,
          result.minute,
          0
        ).getTime();
      }
    });
  }

  private async selectImages(): Promise<void> {
    try {
      const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 6 - this.draftImages.length;
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(options);
      this.draftImages = this.draftImages.concat(result.photoUris);
    } catch (error) {
      promptAction.showToast({ message: '没有选择图片' });
    }
  }

  private removeImage(uri: string): void {
    this.draftImages = this.draftImages.filter((item: string) => item !== uri);
  }

  private async saveTodo(): Promise<void> {
    const title: string = this.draftTitle.trim();
    if (title.length === 0) {
      promptAction.showToast({ message: '请填写待办标题' });
      return;
    }
    if (this.draftReminderEnabled && this.draftDueAt <= Date.now()) {
      promptAction.showToast({ message: '提醒时间需要晚于现在' });
      return;
    }
    const advanceAt: number = this.draftDueAt - this.draftAdvanceReminderDays * 24 * 60 * 60 * 1000;
    if (this.draftReminderEnabled && this.draftAdvanceReminderDays > 0 && advanceAt <= Date.now()) {
      promptAction.showToast({ message: '提前提醒时间已经过去，请减少提前天数' });
      return;
    }

    this.saving = true;
    const oldItem: TodoItem | undefined = this.todos.find((item: TodoItem) => item.id === this.editingId);
    const now: number = Date.now();
    const item: TodoItem = new TodoItem(
      oldItem ? oldItem.id : now,
      title,
      this.draftNote.trim(),
      this.draftLocation.trim(),
      this.draftDueAt,
      this.draftImages.slice(),
      oldItem ? oldItem.completed : false,
      this.draftReminderEnabled,
      -1,
      this.draftAdvanceReminderDays,
      -1,
      -1,
      oldItem ? oldItem.createdAt : now,
      this.draftCourseName,
      this.draftTaskKind,
      oldItem ? oldItem.source : 'manual',
      oldItem ? oldItem.sourceUrl : '',
      oldItem ? oldItem.platformLabel : ''
    );

    if (item.reminderEnabled && !item.completed) {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const enabled: boolean = await ReminderService.requestNotificationPermission(context);
      if (!enabled) {
        this.saving = false;
        promptAction.showToast({ message: '需要允许通知，待办才能显示在锁屏' });
        return;
      }
    }

    if (oldItem) {
      await ReminderService.cancel(oldItem.reminderId);
      await ReminderService.cancel(oldItem.advanceReminderId);
      await LockScreenNotificationService.cancel(oldItem.id);
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      await CalendarReminderService.cancel(context, oldItem.calendarEventId);
    }

    if (item.reminderEnabled && !item.completed) {
      let useAgentReminder: boolean = true;
      try {
        item.reminderId = await ReminderService.schedule(item);
      } catch (error) {
        const reminderError: BusinessError = error as BusinessError;
        if (reminderError.code === 1700002) {
          useAgentReminder = false;
          try {
            const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
            const granted: boolean = await CalendarReminderService.requestPermission(context);
            if (!granted) {
              promptAction.showToast({ message: '需要允许日历权限，系统才能按时提醒' });
            } else {
              item.calendarEventId = await CalendarReminderService.schedule(context, item);
              promptAction.showToast({ message: '已改用系统日历提醒' });
            }
          } catch (calendarError) {
            const eventError: BusinessError = calendarError as BusinessError;
            promptAction.showToast({ message: `日历提醒失败（${eventError.code}）：请允许日历权限` });
          }
        } else {
          promptAction.showToast({ message: `提醒登记失败（${reminderError.code}）：${reminderError.message}` });
        }
      }
      if (useAgentReminder) {
        try {
          item.advanceReminderId = await ReminderService.scheduleAdvance(item);
        } catch (error) {
          const reminderError: BusinessError = error as BusinessError;
          promptAction.showToast({ message: `提前提醒失败（${reminderError.code}）：${reminderError.message}` });
        }
      }
    }

    const next: TodoItem[] = this.todos.filter((todo: TodoItem) => todo.id !== item.id);
    next.push(item);
    this.todos = next;
    await todoStore.save(this.todos);
    if (item.reminderEnabled && !item.completed) {
      try {
        await LockScreenNotificationService.publish(item);
      } catch (error) {
        const notificationError: BusinessError = error as BusinessError;
        promptAction.showToast({ message: `锁屏通知发送失败（${notificationError.code}）` });
      }
    }
    this.saving = false;
    this.editorOpen = false;
  }

  private async toggleComplete(item: TodoItem, completed: boolean): Promise<void> {
    item.completed = completed;
    if (completed) {
      await ReminderService.cancel(item.reminderId);
      await ReminderService.cancel(item.advanceReminderId);
      await LockScreenNotificationService.cancel(item.id);
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      await CalendarReminderService.cancel(context, item.calendarEventId);
      item.reminderId = -1;
      item.advanceReminderId = -1;
      item.calendarEventId = -1;
    } else if (item.reminderEnabled && item.dueAt > Date.now()) {
      try {
        item.reminderId = await ReminderService.schedule(item);
        item.advanceReminderId = await ReminderService.scheduleAdvance(item);
      } catch (error) {
        const reminderError: BusinessError = error as BusinessError;
        if (reminderError.code === 1700002) {
          try {
            const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
            const granted: boolean = await CalendarReminderService.requestPermission(context);
            if (granted) {
              item.calendarEventId = await CalendarReminderService.schedule(context, item);
            }
          } catch (calendarError) {
            item.calendarEventId = -1;
          }
        }
      }
      try {
        await LockScreenNotificationService.publish(item);
      } catch (error) {
        promptAction.showToast({ message: '锁屏通知发送失败，请检查应用通知设置' });
      }
    }
    this.todos = this.todos.slice();
    await todoStore.save(this.todos);
  }

  private async deleteTodo(item: TodoItem): Promise<void> {
    await ReminderService.cancel(item.reminderId);
    await ReminderService.cancel(item.advanceReminderId);
    await LockScreenNotificationService.cancel(item.id);
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    await CalendarReminderService.cancel(context, item.calendarEventId);
    this.todos = this.todos.filter((todo: TodoItem) => todo.id !== item.id);
    await todoStore.save(this.todos);
    this.editorOpen = false;
    promptAction.showToast({ message: '已删除' });
  }

  @Builder
  private TabButton(label: string, tab: number) {
    Button(`${label}  ${tab === 0 ? this.pendingCount() : this.todos.length - this.pendingCount()}`,
      { type: ButtonType.Normal })
      .height(38)
      .layoutWeight(1)
      .fontSize(14)
      .fontWeight(this.selectedTab === tab ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.selectedTab === tab ? COLOR_SURFACE : COLOR_MUTED)
      .backgroundColor(this.selectedTab === tab ? COLOR_PRIMARY : Color.Transparent)
      .borderRadius(6)
      .onClick(() => {
        this.selectedTab = tab;
      });
  }

  @Builder
  private FolderMenuItem(label: string, folder: string) {
    Row({ space: 8 }) {
      Text(label)
        .layoutWeight(1)
        .fontSize(14)
        .fontWeight(this.selectedCourseFolder === folder ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.selectedCourseFolder === folder ? COLOR_PRIMARY : COLOR_TEXT)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
      Text(`${this.folderCount(folder)} 项`)
        .fontSize(12)
        .fontColor(COLOR_MUTED);
      if (this.selectedCourseFolder === folder) {
        Text('✓')
          .width(20)
          .fontSize(14)
          .fontColor(COLOR_PRIMARY)
          .textAlign(TextAlign.Center);
      } else {
        Blank().width(20);
      }
    }
    .width('100%')
    .height(46)
    .padding({ left: 14, right: 14 })
    .backgroundColor(this.selectedCourseFolder === folder ? '#E8F3EF' : COLOR_SURFACE)
    .border({ width: { bottom: 1 }, color: COLOR_BORDER })
    .onClick(() => {
      this.selectedCourseFolder = folder;
      this.folderMenuOpen = false;
    });
  }

  @Builder
  private TodoRow(item: TodoItem) {
    Row({ space: 12 }) {
      Toggle({ type: ToggleType.Checkbox, isOn: item.completed })
        .width(26)
        .height(26)
        .selectedColor(COLOR_PRIMARY)
        .onChange((isOn: boolean) => {
          this.toggleComplete(item, isOn);
        });

      Column({ space: 7 }) {
        Row({ space: 6 }) {
          Text(this.taskKindLabel(item.taskKind))
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.taskKindColor(item.taskKind))
            .backgroundColor('#EEF3F1')
            .borderRadius(4)
            .padding({ left: 6, right: 6, top: 3, bottom: 3 });
          if (item.courseName.length > 0) {
            Text(item.courseName)
              .fontSize(11)
              .fontColor(COLOR_PRIMARY)
              .backgroundColor('#E4F0EC')
              .borderRadius(4)
              .padding({ left: 6, right: 6, top: 3, bottom: 3 })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
          }
        }
        .width('100%');

        Text(item.title)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(item.completed ? COLOR_MUTED : COLOR_TEXT)
          .decoration({ type: item.completed ? TextDecorationType.LineThrough : TextDecorationType.None })
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');

        if (item.note.length > 0) {
          Text(item.note)
            .fontSize(14)
            .fontColor(COLOR_MUTED)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%');
        }

        if (item.location.length > 0) {
          Text(`地点：${item.location}`)
            .fontSize(13)
            .fontColor('#276B9A')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%');
        }

        Row({ space: 7 }) {
          Text(this.formatDate(item.dueAt))
            .fontSize(13)
            .fontColor(!item.completed && item.dueAt < Date.now() ? COLOR_DANGER : COLOR_MUTED);
          if (item.reminderEnabled && !item.completed) {
            Text(item.calendarEventId > 0 ? '日历提醒' :
              (item.advanceReminderDays > 0 ? `提前${item.advanceReminderDays}天` : '锁屏提醒'))
              .fontSize(11)
              .fontColor(COLOR_WARNING)
              .backgroundColor('#FFF4DE')
              .borderRadius(4)
              .padding({ left: 6, right: 6, top: 3, bottom: 3 });
          }
          if (item.imageUris.length > 0) {
            Text(`${item.imageUris.length} 张图片`)
              .fontSize(12)
              .fontColor('#276B9A');
          }
        }
        .width('100%');
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .constraintSize({ minHeight: 96 })
    .padding(16)
    .alignItems(VerticalAlign.Top)
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(8)
    .border({ width: 1, color: COLOR_BORDER })
    .onClick(() => {
      this.openEditor(item);
    });
  }

  @Builder
  private EmptyState() {
    Column({ space: 12 }) {
      Text(this.selectedTab === 0 ? '今天从一件小事开始' : '还没有已完成的待办')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT);
      Text(this.selectedTab === 0 ? '添加待办后，系统会按时在锁屏提醒你。' : '完成的事项会保留在这里。')
        .fontSize(14)
        .fontColor(COLOR_MUTED)
        .textAlign(TextAlign.Center)
        .maxLines(2);
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ top: 80, left: 28, right: 28 });
  }

  @Builder
  private HomePage() {
    Column() {
      Column({ space: 7 }) {
        Text('今天要做')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT);
        Text(`${this.todayLabel()} · ${this.pendingCount()} 项待办`)
          .fontSize(14)
          .fontColor(COLOR_MUTED);
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 20, right: 20, top: 22, bottom: 18 });

      Row({ space: 4 }) {
        this.TabButton('待办', 0);
        this.TabButton('已完成', 1);
      }
      .width('calc(100% - 40vp)')
      .padding(4)
      .margin({ left: 20, right: 20, bottom: 14 })
      .backgroundColor('#E7ECE9')
      .borderRadius(8);

      Row({ space: 10 }) {
        Text('课程文件夹')
          .fontSize(13)
          .fontColor(COLOR_MUTED);
        Text(this.selectedFolderLabel())
          .layoutWeight(1)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        Text(`${this.folderCount(this.selectedCourseFolder)} 项`)
          .fontSize(12)
          .fontColor(COLOR_MUTED);
        Text(this.folderMenuOpen ? '⌃' : '⌄')
          .width(24)
          .fontSize(18)
          .fontColor(COLOR_PRIMARY)
          .textAlign(TextAlign.Center);
      }
      .width('calc(100% - 40vp)')
      .height(44)
      .padding({ left: 14, right: 10 })
      .margin({ left: 20, right: 20, bottom: this.folderMenuOpen ? 0 : 14 })
      .backgroundColor(COLOR_SURFACE)
      .borderRadius(7)
      .border({ width: 1, color: COLOR_BORDER })
      .onClick(() => {
        this.folderMenuOpen = !this.folderMenuOpen;
      });

      if (this.folderMenuOpen) {
        Scroll() {
          Column() {
            this.FolderMenuItem('全部课程', '');
            ForEach(this.courseNames, (courseName: string) => {
              this.FolderMenuItem(courseName, courseName);
            }, (courseName: string) => courseName);
            this.FolderMenuItem('其他', COURSE_FOLDER_OTHER);
          }
          .width('100%');
        }
        .width('calc(100% - 40vp)')
        .height(Math.min(276, (this.courseNames.length + 2) * 46))
        .margin({ left: 20, right: 20, bottom: 14 })
        .backgroundColor(COLOR_SURFACE)
        .border({ width: { left: 1, right: 1, bottom: 1 }, color: COLOR_BORDER })
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Auto);
      }

      if (this.visibleTodos().length === 0) {
        this.EmptyState();
      } else {
        List({ space: 10 }) {
          ForEach(this.visibleTodos(), (item: TodoItem) => {
            ListItem() {
              this.TodoRow(item);
            }
          }, (item: TodoItem) => item.id.toString());
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 10 })
        .scrollBar(BarState.Off);
      }

      Button('新增待办', { type: ButtonType.Normal })
        .width('calc(100% - 40vp)')
        .height(52)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_SURFACE)
        .backgroundColor(COLOR_PRIMARY)
        .borderRadius(8)
        .margin({ left: 20, right: 20, top: 10, bottom: 18 })
        .onClick(() => {
          this.openNewTodo();
        });
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BACKGROUND);
  }

  @Builder
  private EditorPage() {
    Column() {
      Row() {
        Button('取消', { type: ButtonType.Normal })
          .fontSize(15)
          .fontColor(COLOR_MUTED)
          .backgroundColor(Color.Transparent)
          .borderRadius(6)
          .onClick(() => {
            this.editorOpen = false;
          });
        Blank();
        Text(this.editingId < 0 ? '新建待办' : '编辑待办')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT);
        Blank();
        Button(this.saving ? '保存中' : '保存', { type: ButtonType.Normal })
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_PRIMARY)
          .backgroundColor(Color.Transparent)
          .borderRadius(6)
          .enabled(!this.saving)
          .onClick(() => {
            this.saveTodo();
          });
      }
      .width('100%')
      .height(58)
      .padding({ left: 12, right: 12 })
      .border({ width: { bottom: 1 }, color: COLOR_BORDER });

      Scroll() {
        Column({ space: 0 }) {
          TextInput({ placeholder: '要做什么？', text: this.draftTitle })
            .width('100%')
            .height(62)
            .fontSize(21)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_TEXT)
            .placeholderColor('#96A19C')
            .backgroundColor(COLOR_SURFACE)
            .borderRadius(0)
            .padding({ left: 20, right: 20 })
            .onChange((value: string) => {
              this.draftTitle = value;
            });

          TextArea({ placeholder: '添加备注', text: this.draftNote })
            .width('100%')
            .height(118)
            .fontSize(15)
            .fontColor(COLOR_TEXT)
            .placeholderColor('#96A19C')
            .backgroundColor(COLOR_SURFACE)
            .borderRadius(0)
            .padding({ left: 20, right: 20, top: 14, bottom: 14 })
            .border({ width: { top: 1 }, color: COLOR_BORDER })
            .onChange((value: string) => {
              this.draftNote = value;
            });

          TextInput({ placeholder: '添加地点，如：公司会议室', text: this.draftLocation })
            .width('100%')
            .height(56)
            .fontSize(15)
            .fontColor(COLOR_TEXT)
            .placeholderColor('#96A19C')
            .backgroundColor(COLOR_SURFACE)
            .borderRadius(0)
            .padding({ left: 20, right: 20 })
            .border({ width: { top: 1 }, color: COLOR_BORDER })
            .onChange((value: string) => {
              this.draftLocation = value;
            });

          Text('课程归档')
            .width('100%')
            .fontSize(13)
            .fontColor(COLOR_MUTED)
            .padding({ left: 20, right: 20, top: 24, bottom: 8 });

          Column() {
            Row() {
              Text('课程文件夹')
                .fontSize(16)
                .fontColor(COLOR_TEXT);
              Blank();
              Select(this.courseOptions())
                .selected(this.selectedCourseIndex())
                .value(this.draftCourseName.length > 0 ? this.draftCourseName : '未分类')
                .width(190)
                .height(42)
                .fontColor(COLOR_PRIMARY)
                .backgroundColor('#E8F3EF')
                .onSelect((index: number) => {
                  this.draftCourseName = index === 0 ? '' : this.courseNames[index - 1];
                });
            }
            .width('100%')
            .height(58)
            .padding({ left: 20, right: 20 });

            Row() {
              Text('任务类型')
                .fontSize(16)
                .fontColor(COLOR_TEXT);
              Blank();
              Select(this.taskKindOptions())
                .selected(this.selectedTaskKindIndex())
                .value(this.taskKindLabel(this.draftTaskKind))
                .width(140)
                .height(42)
                .fontColor(this.taskKindColor(this.draftTaskKind))
                .backgroundColor('#EEF3F1')
                .onSelect((index: number) => {
                  this.draftTaskKind = this.taskKindFromIndex(index);
                });
            }
            .width('100%')
            .height(58)
            .padding({ left: 20, right: 20 })
            .border({ width: { top: 1 }, color: COLOR_BORDER });
          }
          .width('100%')
          .backgroundColor(COLOR_SURFACE);

          Text('时间与提醒')
            .width('100%')
            .fontSize(13)
            .fontColor(COLOR_MUTED)
            .padding({ left: 20, right: 20, top: 24, bottom: 8 });

          Column() {
            Row() {
              Text('日期')
                .fontSize(16)
                .fontColor(COLOR_TEXT);
              Blank();
              Button(this.formatDate(this.draftDueAt).split(' ')[0], { type: ButtonType.Normal })
                .fontSize(15)
                .fontColor(COLOR_PRIMARY)
                .backgroundColor('#E8F3EF')
                .borderRadius(6)
                .onClick(() => {
                  this.showDatePicker();
                });
            }
            .width('100%')
            .height(56)
            .padding({ left: 20, right: 20 });

            Row() {
              Text('时间')
                .fontSize(16)
                .fontColor(COLOR_TEXT);
              Blank();
              Button(this.formatDate(this.draftDueAt).split(' ')[1], { type: ButtonType.Normal })
                .fontSize(15)
                .fontColor(COLOR_PRIMARY)
                .backgroundColor('#E8F3EF')
                .borderRadius(6)
                .onClick(() => {
                  this.showTimePicker();
                });
            }
            .width('100%')
            .height(56)
            .padding({ left: 20, right: 20 })
            .border({ width: { top: 1 }, color: COLOR_BORDER });

            Row() {
              Column({ space: 4 }) {
                Text('提前提醒')
                  .fontSize(16)
                  .fontColor(this.draftReminderEnabled ? COLOR_TEXT : COLOR_MUTED);
                Text('到期提醒仍会保留，最多提前30天')
                  .fontSize(12)
                  .fontColor(COLOR_MUTED);
              }
              .alignItems(HorizontalAlign.Start);
              Blank();
              Row({ space: 8 }) {
                Button('-', { type: ButtonType.Normal })
                  .width(38)
                  .height(36)
                  .fontSize(20)
                  .fontColor(COLOR_PRIMARY)
                  .backgroundColor('#E8F3EF')
                  .borderRadius(6)
                  .enabled(this.draftReminderEnabled && this.draftAdvanceReminderDays > 0)
                  .onClick(() => {
                    if (this.draftAdvanceReminderDays > 0) {
                      this.draftAdvanceReminderDays--;
                    }
                  });
                Text(this.draftAdvanceReminderDays === 0 ? '不提前' : `${this.draftAdvanceReminderDays}天`)
                  .width(52)
                  .fontSize(14)
                  .fontColor(this.draftReminderEnabled ? COLOR_TEXT : COLOR_MUTED)
                  .textAlign(TextAlign.Center);
                Button('+', { type: ButtonType.Normal })
                  .width(38)
                  .height(36)
                  .fontSize(20)
                  .fontColor(COLOR_PRIMARY)
                  .backgroundColor('#E8F3EF')
                  .borderRadius(6)
                  .enabled(this.draftReminderEnabled && this.draftAdvanceReminderDays < 30)
                  .onClick(() => {
                    if (this.draftAdvanceReminderDays < 30) {
                      this.draftAdvanceReminderDays++;
                    }
                  });
              }
            }
            .width('100%')
            .height(72)
            .padding({ left: 20, right: 20 })
            .border({ width: { top: 1 }, color: COLOR_BORDER });

            Row() {
              Column({ space: 4 }) {
                Text('锁屏提醒')
                  .fontSize(16)
                  .fontColor(COLOR_TEXT);
                Text('保存后显示待办，到时间后再次提醒')
                  .fontSize(12)
                  .fontColor(COLOR_MUTED);
              }
              .alignItems(HorizontalAlign.Start);
              Blank();
              Toggle({ type: ToggleType.Switch, isOn: this.draftReminderEnabled })
                .selectedColor(COLOR_PRIMARY)
                .onChange((isOn: boolean) => {
                  this.draftReminderEnabled = isOn;
                });
            }
            .width('100%')
            .height(68)
            .padding({ left: 20, right: 20 })
            .border({ width: { top: 1 }, color: COLOR_BORDER });
          }
          .width('100%')
          .backgroundColor(COLOR_SURFACE);

          Row() {
            Text('图片')
              .fontSize(13)
              .fontColor(COLOR_MUTED);
            Blank();
            Text(`${this.draftImages.length}/6`)
              .fontSize(12)
              .fontColor(COLOR_MUTED);
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 24, bottom: 8 });

          if (this.draftImages.length > 0) {
            Scroll() {
              Row({ space: 10 }) {
                ForEach(this.draftImages, (uri: string) => {
                  Column({ space: 6 }) {
                    Image(uri)
                      .width(92)
                      .height(92)
                      .objectFit(ImageFit.Cover)
                      .borderRadius(6);
                    Button('移除', { type: ButtonType.Normal })
                      .width(92)
                      .height(30)
                      .fontSize(12)
                      .fontColor(COLOR_DANGER)
                      .backgroundColor('#FCEDEB')
                      .borderRadius(6)
                      .onClick(() => {
                        this.removeImage(uri);
                      });
                  }
                }, (uri: string) => uri);
              }
              .padding({ left: 20, right: 20 });
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%');
          }

          if (this.draftImages.length < 6) {
            Button('选择图片', { type: ButtonType.Normal })
              .width('calc(100% - 40vp)')
              .height(48)
              .fontSize(15)
              .fontColor('#276B9A')
              .backgroundColor('#EAF2F8')
              .borderRadius(8)
              .margin({ left: 20, right: 20, top: 10 })
              .onClick(() => {
                this.selectImages();
              });
          }

          if (this.editingId >= 0) {
            Button('删除待办', { type: ButtonType.Normal })
              .width('calc(100% - 40vp)')
              .height(48)
              .fontSize(15)
              .fontColor(COLOR_DANGER)
              .backgroundColor('#FCEDEB')
              .borderRadius(8)
              .margin({ left: 20, right: 20, top: 30, bottom: 22 })
              .onClick(() => {
                const item: TodoItem | undefined = this.todos.find((todo: TodoItem) => todo.id === this.editingId);
                if (item) {
                  this.deleteTodo(item);
                }
              });
          } else {
            Blank().height(24);
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BACKGROUND);
  }

  @Builder
  private MainTabLabel(label: string) {
    Text(label)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(COLOR_TEXT);
  }

  build() {
    if (this.editorOpen) {
      this.EditorPage();
    } else {
      Tabs({ barPosition: BarPosition.End, index: this.mainTab }) {
        TabContent() {
          this.HomePage();
        }
        .tabBar(this.MainTabLabel('待办'));

        TabContent() {
          CoursePage({
            showCloseButton: false,
            backRequest: this.courseBackRequest,
            onClose: () => {
              this.closeCoursePage();
            },
            onDetailStateChange: (isOpen: boolean) => {
              this.courseDetailOpen = isOpen;
            },
            onAddTodo: (course: CourseItem, dueAt: number) => {
              this.openCourseTodo(course, dueAt);
            },
            onOpenCourseTodos: (course: CourseItem) => {
              this.courseDetailOpen = false;
              this.selectedCourseFolder = course.name;
              this.folderMenuOpen = false;
              this.selectedTab = 0;
              this.closeCoursePage();
            },
            courseTodoCount: (courseName: string): number => {
              return this.pendingCourseCount(courseName);
            }
          });
        }
        .tabBar(this.MainTabLabel('课表'));
      }
      .barHeight(54)
      .animationDuration(220)
      .barBackgroundColor(COLOR_SURFACE)
      .backgroundColor(COLOR_BACKGROUND)
      .onChange((index: number) => {
        this.mainTab = index;
      });
    }
  }
}
