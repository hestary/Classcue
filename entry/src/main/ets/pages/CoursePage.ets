import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import {
  CourseItem,
  COURSE_PARITY_ALL,
  COURSE_PARITY_EVEN,
  COURSE_PARITY_ODD
} from '../model/CourseItem';
import { courseStore, CourseStore } from '../store/CourseStore';
import { CourseImportPage } from './CourseImportPage';

const COLOR_BACKGROUND: string = '#F3F5F4';
const COLOR_SURFACE: string = '#FFFFFF';
const COLOR_PRIMARY: string = '#176B54';
const COLOR_PRIMARY_DARK: string = '#124C3E';
const COLOR_TEXT: string = '#17201D';
const COLOR_MUTED: string = '#6B7772';
const COLOR_BORDER: string = '#DCE3E0';
const COLOR_DANGER: string = '#C6463D';
const ROW_HEIGHT: number = 52;
const HEADER_HEIGHT: number = 48;
const LEFT_WIDTH: number = 41;
const DAY_WIDTH: number = 48;
const WEEKDAY_NAMES: string[] = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
const DEFAULT_SECTION_RANGES: string[] = [
  '08:00-08:45', '08:45-09:40', '10:00-10:45', '10:45-11:40',
  '13:30-14:15', '14:15-15:10', '15:30-16:15', '16:15-17:10',
  '18:20-19:05', '19:05-19:50', '20:00-20:45', '20:45-21:30'
];
const COURSE_COLORS: string[] = [
  '#E0F0EA', '#E4EDF7', '#FAE9DB', '#F0E7F2', '#F7E5E8', '#EBF0DD', '#F7EED8', '#E3EFF0'
];
const COURSE_ACCENTS: string[] = [
  '#26745C', '#416F9B', '#B66735', '#805C8A', '#AD5865', '#6F8247', '#9B782F', '#4B787D'
];

class WeekDataSource implements IDataSource {
  private count: number;
  private listeners: DataChangeListener[] = [];

  constructor(count: number) {
    this.count = count;
  }

  totalCount(): number {
    return this.count;
  }

  getData(index: number): number {
    return index + 1;
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index: number = this.listeners.indexOf(listener);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }

  setCount(count: number): void {
    if (this.count === count) {
      return;
    }
    this.count = count;
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataReloaded();
    });
  }
}

@Component
export struct CoursePage {
  onAddTodo: (course: CourseItem, dueAt: number) => void = () => {};
  onOpenCourseTodos: (course: CourseItem) => void = () => {};
  courseTodoCount: (courseName: string) => number = () => 0;
  onClose: () => void = () => {};
  onDetailStateChange: (isOpen: boolean) => void = () => {};
  @Prop showCloseButton: boolean = true;
  @Prop @Watch('handleBackRequest') backRequest: number = 0;
  @State private courses: CourseItem[] = [];
  @State private semesterStartAt: number = 0;
  @State private selectedWeek: number = 1;
  @State private currentWeek: number = 1;
  @State private editorOpen: boolean = false;
  @State private editingId: number = -1;
  @State private detailId: number = -1;
  @State private importOpen: boolean = false;
  @State private optionsOpen: boolean = false;
  @State private sectionRanges: string[] = DEFAULT_SECTION_RANGES.slice();
  @State private timeEditorSection: number = -1;
  @State private draftSectionStart: string = '08:00';
  @State private draftSectionEnd: string = '08:45';
  private weekSwiper: SwiperController = new SwiperController();
  private weekDataSource: WeekDataSource = new WeekDataSource(20);
  @State private draftName: string = '';
  @State private draftTeacher: string = '';
  @State private draftLocation: string = '';
  @State private draftWeekday: number = 1;
  @State private draftStartSection: number = 1;
  @State private draftEndSection: number = 2;
  @State private draftStartWeek: number = 1;
  @State private draftEndWeek: number = 20;
  @State private draftParity: string = COURSE_PARITY_ALL;

  aboutToAppear(): void {
    this.loadData();
  }

  private handleBackRequest(): void {
    if (this.detailId >= 0) {
      this.detailId = -1;
      this.onDetailStateChange(false);
    }
  }

  private async loadData(): Promise<void> {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    await courseStore.initialize(context);
    this.courses = await courseStore.loadCourses();
    this.semesterStartAt = await courseStore.loadSemesterStart();
    this.sectionRanges = await courseStore.loadSectionRanges(DEFAULT_SECTION_RANGES);
    this.weekDataSource.setCount(this.totalWeeks());
    this.currentWeek = this.calculateCurrentWeek();
    this.selectedWeek = this.currentWeek;
  }

  private calculateCurrentWeek(): number {
    if (this.semesterStartAt <= 0) {
      return 1;
    }
    return Math.min(30, Math.max(1, Math.floor((CourseStore.startOfWeek(Date.now()) - this.semesterStartAt) /
      (7 * 24 * 60 * 60 * 1000)) + 1));
  }

  private totalWeeks(): number {
    let weeks: number = 20;
    this.courses.forEach((course: CourseItem) => {
      weeks = Math.max(weeks, course.endWeek);
    });
    return Math.min(30, weeks);
  }

  private isActiveInWeek(course: CourseItem, week: number): boolean {
    if (week < course.startWeek || week > course.endWeek) {
      return false;
    }
    if (course.parity === COURSE_PARITY_ODD) {
      return week % 2 === 1;
    }
    if (course.parity === COURSE_PARITY_EVEN) {
      return week % 2 === 0;
    }
    return true;
  }

  private dayCourses(weekday: number, week: number = this.selectedWeek): CourseItem[] {
    const candidates: CourseItem[] = this.courses
      .filter((course: CourseItem) => course.weekday === weekday && this.isActiveInWeek(course, week))
      .sort((left: CourseItem, right: CourseItem) => left.startSection - right.startSection);
    const visible: CourseItem[] = [];
    const occupied: boolean[] = new Array<boolean>(13).fill(false);
    candidates.forEach((course: CourseItem) => {
      let overlaps: boolean = false;
      for (let section: number = course.startSection; section <= course.endSection; section++) {
        if (occupied[section]) {
          overlaps = true;
        }
      }
      if (!overlaps) {
        visible.push(course);
        for (let section: number = course.startSection; section <= course.endSection; section++) {
          occupied[section] = true;
        }
      }
    });
    return visible;
  }

  private weekStartAt(week: number = this.selectedWeek): number {
    return this.semesterStartAt + (week - 1) * 7 * 24 * 60 * 60 * 1000;
  }

  private dateForDay(dayIndex: number, week: number = this.selectedWeek): Date {
    return new Date(this.weekStartAt(week) + dayIndex * 24 * 60 * 60 * 1000);
  }

  private pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  private formatMonthDay(timestamp: number): string {
    const date: Date = new Date(timestamp);
    return `${date.getMonth() + 1}/${date.getDate()}`;
  }

  private formatFullDate(timestamp: number): string {
    const date: Date = new Date(timestamp);
    return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日`;
  }

  private currentSection(): number {
    const now: Date = new Date();
    const nowText: string = `${this.pad(now.getHours())}:${this.pad(now.getMinutes())}`;
    for (let index: number = 0; index < this.sectionRanges.length; index++) {
      const range: string[] = this.sectionRanges[index].split('-');
      if (range[0] <= nowText && nowText < range[1]) {
        return index + 1;
      }
    }
    return -1;
  }

  private isToday(dayIndex: number, week: number = this.selectedWeek): boolean {
    return this.dateForDay(dayIndex, week).toDateString() === new Date().toDateString();
  }

  private currentTimeOffset(): number {
    const section: number = this.currentSection();
    if (section < 1) {
      return -1;
    }
    const range: string[] = this.sectionRanges[section - 1].split('-');
    const start: string[] = range[0].split(':');
    const end: string[] = range[1].split(':');
    const now: Date = new Date();
    const currentMinutes: number = now.getHours() * 60 + now.getMinutes();
    const startMinutes: number = Number(start[0]) * 60 + Number(start[1]);
    const endMinutes: number = Number(end[0]) * 60 + Number(end[1]);
    const progress: number = (currentMinutes - startMinutes) / (endMinutes - startMinutes);
    return (section - 1 + progress) * ROW_HEIGHT;
  }

  private courseColorIndex(course: CourseItem): number {
    return Math.abs(course.id) % COURSE_COLORS.length;
  }

  private gridCellColor(sectionIndex: number, dayIndex: number, week: number): string {
    if (this.isToday(dayIndex, week)) {
      return sectionIndex % 2 === 0 ? '#ECF6F1' : '#F1F8F4';
    }
    if (dayIndex >= 5) {
      return sectionIndex % 2 === 0 ? '#FBF8F3' : '#F8F5F0';
    }
    return sectionIndex % 2 === 0 ? '#F7F9F8' : '#F3F6F5';
  }

  private timeCellColor(sectionIndex: number): string {
    return sectionIndex % 2 === 0 ? '#EEF2F0' : '#E9EEEC';
  }

  private openSectionTimeEditor(index: number): void {
    const range: string[] = this.sectionRanges[index].split('-');
    this.timeEditorSection = index;
    this.draftSectionStart = range[0];
    this.draftSectionEnd = range[1];
  }

  private timeToMinutes(value: string): number {
    const parts: string[] = value.split(':');
    return Number(parts[0]) * 60 + Number(parts[1]);
  }

  private showSectionTimePicker(isStart: boolean): void {
    const value: string = isStart ? this.draftSectionStart : this.draftSectionEnd;
    const parts: string[] = value.split(':');
    TimePickerDialog.show({
      selected: new Date(2020, 0, 1, Number(parts[0]), Number(parts[1]), 0),
      useMilitaryTime: true,
      onAccept: (result: TimePickerResult) => {
        const next: string = `${this.pad(result.hour)}:${this.pad(result.minute)}`;
        if (isStart) {
          this.draftSectionStart = next;
        } else {
          this.draftSectionEnd = next;
        }
      }
    });
  }

  private async saveSectionTime(): Promise<void> {
    if (this.timeToMinutes(this.draftSectionEnd) <= this.timeToMinutes(this.draftSectionStart)) {
      promptAction.showToast({ message: '结束时间必须晚于开始时间' });
      return;
    }
    const next: string[] = this.sectionRanges.slice();
    next[this.timeEditorSection] = `${this.draftSectionStart}-${this.draftSectionEnd}`;
    this.sectionRanges = next;
    await courseStore.saveSectionRanges(next);
    this.timeEditorSection = -1;
    promptAction.showToast({ message: '上课时间已保存' });
  }

  private openNewCourse(): void {
    this.editingId = -1;
    this.draftName = '';
    this.draftTeacher = '';
    this.draftLocation = '';
    this.draftWeekday = 1;
    this.draftStartSection = 1;
    this.draftEndSection = 2;
    this.draftStartWeek = this.currentWeek;
    this.draftEndWeek = Math.max(this.currentWeek, 20);
    this.draftParity = COURSE_PARITY_ALL;
    this.editorOpen = true;
  }

  private openCourseEditor(course: CourseItem): void {
    this.editingId = course.id;
    this.draftName = course.name;
    this.draftTeacher = course.teacher;
    this.draftLocation = course.location;
    this.draftWeekday = course.weekday;
    this.draftStartSection = course.startSection;
    this.draftEndSection = course.endSection;
    this.draftStartWeek = course.startWeek;
    this.draftEndWeek = course.endWeek;
    this.draftParity = course.parity;
    this.detailId = -1;
    this.editorOpen = true;
  }

  private async saveCourse(): Promise<void> {
    const name: string = this.draftName.trim();
    if (name.length === 0) {
      promptAction.showToast({ message: '请填写课程名称' });
      return;
    }
    if (this.draftEndSection < this.draftStartSection) {
      promptAction.showToast({ message: '结束节次不能早于开始节次' });
      return;
    }
    if (this.draftEndWeek < this.draftStartWeek) {
      promptAction.showToast({ message: '结束周不能早于开始周' });
      return;
    }
    const old: CourseItem | undefined = this.courses.find((item: CourseItem) => item.id === this.editingId);
    const course: CourseItem = new CourseItem(
      old ? old.id : Date.now(),
      name,
      this.draftTeacher.trim(),
      this.draftLocation.trim(),
      this.draftWeekday,
      this.draftStartSection,
      this.draftEndSection,
      this.draftStartWeek,
      this.draftEndWeek,
      this.draftParity
    );
    const next: CourseItem[] = this.courses.filter((item: CourseItem) => item.id !== course.id);
    next.push(course);
    this.courses = next;
    this.weekDataSource.setCount(this.totalWeeks());
    await courseStore.saveCourses(this.courses);
    this.editorOpen = false;
    this.selectedWeek = this.currentWeek;
  }

  private async deleteCourse(course: CourseItem): Promise<void> {
    this.courses = this.courses.filter((item: CourseItem) => item.id !== course.id);
    this.weekDataSource.setCount(this.totalWeeks());
    await courseStore.saveCourses(this.courses);
    this.detailId = -1;
    this.onDetailStateChange(false);
    promptAction.showToast({ message: '课程已删除' });
  }

  private courseKey(course: CourseItem): string {
    return `${course.name}|${course.teacher}|${course.location}|${course.weekday}|` +
      `${course.startSection}-${course.endSection}|${course.startWeek}-${course.endWeek}|${course.parity}`;
  }

  private async importCourses(imported: CourseItem[], semesterStartAt: number, replace: boolean): Promise<void> {
    if (replace) {
      this.courses = imported;
    } else {
      const merged: CourseItem[] = this.courses.slice();
      const keys: Set<string> = new Set<string>();
      merged.forEach((course: CourseItem) => keys.add(this.courseKey(course)));
      imported.forEach((course: CourseItem) => {
        const key: string = this.courseKey(course);
        if (!keys.has(key)) {
          keys.add(key);
          merged.push(course);
        }
      });
      this.courses = merged;
    }
    this.weekDataSource.setCount(this.totalWeeks());
    await courseStore.saveCourses(this.courses);
    if (semesterStartAt > 0) {
      this.semesterStartAt = semesterStartAt;
      await courseStore.saveSemesterStart(semesterStartAt);
    }
    this.currentWeek = this.calculateCurrentWeek();
    this.selectedWeek = this.currentWeek;
    this.importOpen = false;
    promptAction.showToast({ message: `已导入 ${imported.length} 条课程安排` });
  }

  private showSemesterPicker(): void {
    DatePickerDialog.show({
      start: new Date(2020, 0, 1),
      end: new Date(new Date().getFullYear() + 5, 11, 31),
      selected: new Date(this.semesterStartAt),
      onAccept: async (result: DatePickerResult) => {
        const selected: number = new Date(result.year, result.month, result.day, 0, 0, 0).getTime();
        this.semesterStartAt = CourseStore.startOfWeek(selected);
        await courseStore.saveSemesterStart(this.semesterStartAt);
        this.currentWeek = this.calculateCurrentWeek();
        this.selectedWeek = this.currentWeek;
      }
    });
  }

  private sectionStartAt(section: number, dateAt: number): number {
    const start: string[] = this.sectionRanges[section - 1].split('-')[0].split(':');
    const date: Date = new Date(dateAt);
    return new Date(date.getFullYear(), date.getMonth(), date.getDate(), Number(start[0]), Number(start[1]), 0).getTime();
  }

  private nextOccurrenceAt(course: CourseItem): number {
    const now: number = Date.now();
    const fromWeek: number = Math.max(1, this.calculateCurrentWeek());
    for (let week: number = fromWeek; week <= course.endWeek; week++) {
      if (!this.isActiveInWeek(course, week)) {
        continue;
      }
      const dayAt: number = this.semesterStartAt + ((week - 1) * 7 + course.weekday - 1) * 24 * 60 * 60 * 1000;
      const occurrence: number = this.sectionStartAt(course.startSection, dayAt);
      if (occurrence > now) {
        return occurrence;
      }
    }
    const tomorrow: Date = new Date();
    return new Date(tomorrow.getFullYear(), tomorrow.getMonth(), tomorrow.getDate() + 1, 9, 0, 0).getTime();
  }

  @Builder
  private MainPage() {
    Column() {
      Row() {
        if (this.showCloseButton) {
          Button('←', { type: ButtonType.Normal })
            .width(38)
            .height(38)
            .fontSize(20)
            .fontColor(COLOR_TEXT)
            .backgroundColor(Color.Transparent)
            .border({ width: { right: 1 }, color: COLOR_BORDER })
            .onClick(() => {
              this.onClose();
            });
        }

        Button('‹', { type: ButtonType.Normal })
          .width(34)
          .height(38)
          .fontSize(22)
          .fontColor(COLOR_PRIMARY_DARK)
          .backgroundColor(Color.Transparent)
          .enabled(this.selectedWeek > 1)
          .onClick(() => {
            this.weekSwiper.showPrevious();
          });

        Column({ space: 2 }) {
          Row({ space: 5 }) {
            Text(`第${this.selectedWeek}周`)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_TEXT);
            if (this.selectedWeek === this.currentWeek) {
              Text('本周')
                .fontSize(9)
                .fontWeight(FontWeight.Medium)
                .fontColor(COLOR_PRIMARY)
                .backgroundColor('#E2F0EB')
                .borderRadius(4)
                .padding({ left: 4, right: 4, top: 2, bottom: 2 });
            }
          }
          Text(`${this.formatMonthDay(this.weekStartAt())} - ${this.formatMonthDay(this.weekStartAt() + 6 * 24 * 60 * 60 * 1000)}`)
            .fontSize(11)
            .fontColor(COLOR_MUTED);
        }
        .layoutWeight(1)
        .height(52)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.weekSwiper.changeIndex(this.currentWeek - 1, true);
        });

        Button('›', { type: ButtonType.Normal })
          .width(34)
          .height(38)
          .fontSize(22)
          .fontColor(COLOR_PRIMARY_DARK)
          .backgroundColor(Color.Transparent)
          .enabled(this.selectedWeek < this.totalWeeks())
          .onClick(() => {
            this.weekSwiper.showNext();
          });

        Button('+', { type: ButtonType.Circle })
          .width(38)
          .height(38)
          .fontSize(22)
          .fontColor(COLOR_PRIMARY)
          .backgroundColor('#E2F0EB')
          .margin({ left: 2 })
          .onClick(() => {
            this.openNewCourse();
          });

        Button('⋯', { type: ButtonType.Circle })
          .width(38)
          .height(38)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_MUTED)
          .backgroundColor(Color.Transparent)
          .margin({ left: 2 })
          .onClick(() => {
            this.optionsOpen = true;
          });
      }
      .width('100%')
      .height(62)
      .padding({ left: 6, right: 6 })
      .backgroundColor(COLOR_SURFACE)
      .border({ width: { bottom: 1 }, color: COLOR_BORDER });

      if (this.courses.length === 0) {
        Column({ space: 14 }) {
          Text('课')
            .width(60)
            .height(60)
            .fontSize(23)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_PRIMARY)
            .textAlign(TextAlign.Center)
            .backgroundColor('#E2F0EB')
            .borderRadius(16);
          Text('这一周还没有课程')
            .fontSize(19)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_TEXT);
          Text('从教务系统导入，或手动添加第一门课')
            .fontSize(14)
            .fontColor(COLOR_MUTED)
            .textAlign(TextAlign.Center);
          Row({ space: 10 }) {
            Button('教务导入', { type: ButtonType.Normal })
              .height(42)
              .fontSize(14)
              .fontColor('#315F80')
              .backgroundColor('#E8F0F6')
              .borderRadius(8)
              .onClick(() => {
                this.importOpen = true;
              });
            Button('手动添加', { type: ButtonType.Normal })
              .height(42)
              .fontSize(14)
              .fontColor(Color.White)
              .backgroundColor(COLOR_PRIMARY)
              .borderRadius(8)
              .onClick(() => {
                this.openNewCourse();
              });
          }
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ left: 24, right: 24, bottom: 72 });
      } else {
        Swiper(this.weekSwiper) {
          LazyForEach(this.weekDataSource, (week: number) => {
            this.WeekTable(week);
          }, (week: number) => week.toString());
        }
        .layoutWeight(1)
        .width('100%')
        .index(this.selectedWeek - 1)
        .loop(false)
        .indicator(false)
        .duration(220)
        .cachedCount(1)
        .onChange((index: number) => {
          this.selectedWeek = index + 1;
        });
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BACKGROUND);
  }

  @Builder
  private WeekTable(week: number) {
    Column() {
      Row() {
        Column({ space: 1 }) {
          Text(`${new Date(this.weekStartAt(week)).getMonth() + 1}月`)
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_TEXT);
          Text(`${new Date(this.weekStartAt(week)).getFullYear()}`)
            .fontSize(8)
            .fontColor(COLOR_MUTED);
        }
        .width(LEFT_WIDTH)
        .height(HEADER_HEIGHT)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#F2F5F3')
        .border({ width: { right: 1, bottom: 1 }, color: COLOR_BORDER });

        Row() {
          ForEach([0, 1, 2, 3, 4, 5, 6], (dayIndex: number) => {
            this.DayHeader(dayIndex, week);
          }, (dayIndex: number) => dayIndex.toString());
        }
      }
      .width('100%');

      Scroll() {
        Row() {
          Column() {
            ForEach(this.sectionRanges, (range: string, index: number) => {
              Column({ space: 1 }) {
                Text(`${index + 1}`)
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(COLOR_TEXT);
                Text(range.split('-')[0])
                  .fontSize(8)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(COLOR_PRIMARY);
              }
              .width('100%')
              .height(ROW_HEIGHT)
              .justifyContent(FlexAlign.Center)
              .backgroundColor(this.timeCellColor(index))
              .border({ width: { right: 1, bottom: 1 }, color: '#DDE5E1' })
              .onClick(() => {
                this.openSectionTimeEditor(index);
              });
            }, (range: string) => range);
          }
          .width(LEFT_WIDTH)
          .backgroundColor('#F2F5F3');

          Row() {
            ForEach([0, 1, 2, 3, 4, 5, 6], (dayIndex: number) => {
              this.DayColumn(dayIndex, week);
            }, (dayIndex: number) => dayIndex.toString());
          }
        }
        .alignItems(VerticalAlign.Top);
      }
      .layoutWeight(1)
      .width('100%')
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .align(Alignment.Top);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_SURFACE)
    .clip(true);
  }

  @Builder
  private DayHeader(dayIndex: number, week: number) {
    Column({ space: 2 }) {
      Text(WEEKDAY_NAMES[dayIndex])
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isToday(dayIndex, week) ? Color.White : (dayIndex >= 5 ? '#8B6547' : COLOR_TEXT));
      Text(`${this.dateForDay(dayIndex, week).getDate()}日`)
        .fontSize(9)
        .fontWeight(this.isToday(dayIndex, week) ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.isToday(dayIndex, week) ? '#D9EEE7' : COLOR_MUTED);
    }
    .width(DAY_WIDTH)
    .height(HEADER_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.isToday(dayIndex, week) ? COLOR_PRIMARY_DARK : (dayIndex >= 5 ? '#F6F1EB' : '#F8FAF9'))
    .border({ width: { right: 1, bottom: 1 }, color: COLOR_BORDER });
  }

  @Builder
  private DayColumn(dayIndex: number, week: number) {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        ForEach(this.sectionRanges, (range: string, index: number) => {
          Row()
            .width('100%')
            .height(ROW_HEIGHT)
            .backgroundColor(this.gridCellColor(index, dayIndex, week))
            .border({
              width: { right: 1, bottom: 1 },
              color: '#DDE5E1'
            });
        }, (range: string) => range);
      }
      ForEach(this.dayCourses(dayIndex + 1, week), (course: CourseItem) => {
        this.CourseCard(course);
      }, (course: CourseItem) => course.id.toString());
      if (week === this.currentWeek && this.isToday(dayIndex, week) && this.currentTimeOffset() >= 0) {
        Row() {
          Row()
            .width(6)
            .height(6)
            .backgroundColor(COLOR_DANGER)
            .borderRadius(3);
          Divider()
            .layoutWeight(1)
            .strokeWidth(2)
            .color(COLOR_DANGER);
        }
        .width('100%')
        .height(6)
        .offset({ x: 0, y: this.currentTimeOffset() - 3 });
      }
    }
    .width(DAY_WIDTH)
    .height(ROW_HEIGHT * 12)
    .backgroundColor(this.isToday(dayIndex, week) ? '#F7FBF9' : (dayIndex >= 5 ? '#FCFAF7' : Color.White))
    .clip(true);
  }

  @Builder
  private CourseCard(course: CourseItem) {
    Column({ space: 2 }) {
      Text(course.name)
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor(COURSE_ACCENTS[this.courseColorIndex(course)])
        .maxLines(Math.min(3, Math.max(2, course.endSection - course.startSection + 1)))
        .textOverflow({ overflow: TextOverflow.Ellipsis });
      if (course.location.length > 0) {
        Text(course.location)
          .fontSize(8)
          .fontColor('#53615C')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
    }
    .width(DAY_WIDTH - 2)
    .height((course.endSection - course.startSection + 1) * ROW_HEIGHT - 2)
    .padding({ left: 4, right: 2, top: 4, bottom: 3 })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(COURSE_COLORS[this.courseColorIndex(course)])
    .borderRadius(4)
    .border({ width: { left: 3 }, color: COURSE_ACCENTS[this.courseColorIndex(course)] })
    .offset({ x: 1, y: (course.startSection - 1) * ROW_HEIGHT + 1 })
    .onClick(() => {
      this.detailId = course.id;
      this.onDetailStateChange(true);
    });
  }

  @Builder
  private OptionsPage() {
    Column() {
      Row() {
        Button('‹', { type: ButtonType.Normal })
          .width(42)
          .height(42)
          .fontSize(24)
          .fontColor(COLOR_MUTED)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.optionsOpen = false;
          });
        Text('课表管理')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT);
        Blank();
      }
      .width('100%')
      .height(58)
      .padding({ left: 8, right: 12 })
      .backgroundColor(COLOR_SURFACE)
      .border({ width: { bottom: 1 }, color: COLOR_BORDER });

      Column() {
        Row() {
          Column({ space: 4 }) {
            Text('从教务系统导入')
              .fontSize(16)
              .fontColor(COLOR_TEXT);
            Text('登录吉林大学教务系统更新课程')
              .fontSize(12)
              .fontColor(COLOR_MUTED);
          }
          .alignItems(HorizontalAlign.Start);
          Blank();
          Text('›')
            .fontSize(22)
            .fontColor(COLOR_MUTED);
        }
        .width('100%')
        .height(72)
        .padding({ left: 16, right: 16 })
        .onClick(() => {
          this.optionsOpen = false;
          this.importOpen = true;
        });

        Divider().color(COLOR_BORDER).strokeWidth(1).margin({ left: 16 });

        Row() {
          Column({ space: 4 }) {
            Text('学期第一周')
              .fontSize(16)
              .fontColor(COLOR_TEXT);
            Text(this.formatFullDate(this.semesterStartAt))
              .fontSize(12)
              .fontColor(COLOR_MUTED);
          }
          .alignItems(HorizontalAlign.Start);
          Blank();
          Text('›')
            .fontSize(22)
            .fontColor(COLOR_MUTED);
        }
        .width('100%')
        .height(72)
        .padding({ left: 16, right: 16 })
        .onClick(() => {
          this.showSemesterPicker();
        });
      }
      .width('calc(100% - 32vp)')
      .margin({ left: 16, right: 16, top: 18 })
      .backgroundColor(COLOR_SURFACE)
      .borderRadius(8)
      .border({ width: 1, color: COLOR_BORDER });
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BACKGROUND);
  }

  @Builder
  private TimeEditorPage() {
    Column() {
      Row() {
        Button('取消', { type: ButtonType.Normal })
          .fontSize(15)
          .fontColor(COLOR_MUTED)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.timeEditorSection = -1;
          });
        Blank();
        Text(`第 ${this.timeEditorSection + 1} 节时间`)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT);
        Blank();
        Button('保存', { type: ButtonType.Normal })
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_PRIMARY)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.saveSectionTime();
          });
      }
      .width('100%')
      .height(58)
      .padding({ left: 12, right: 12 })
      .backgroundColor(COLOR_SURFACE)
      .border({ width: { bottom: 1 }, color: COLOR_BORDER });

      Column({ space: 18 }) {
        Column({ space: 6 }) {
          Text(`${this.timeEditorSection + 1}`)
            .width(58)
            .height(58)
            .fontSize(25)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_PRIMARY)
            .textAlign(TextAlign.Center)
            .backgroundColor('#E2F0EB')
            .borderRadius(16);
          Text('调整上课时间')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_TEXT);
        }

        Column() {
          Row() {
            Column({ space: 3 }) {
              Text('开始时间')
                .fontSize(16)
                .fontColor(COLOR_TEXT);
              Text('本节课程开始')
                .fontSize(12)
                .fontColor(COLOR_MUTED);
            }
            .alignItems(HorizontalAlign.Start);
            Blank();
            Button(this.draftSectionStart, { type: ButtonType.Normal })
              .width(92)
              .height(40)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(COLOR_PRIMARY_DARK)
              .backgroundColor('#E9F2EE')
              .borderRadius(8)
              .onClick(() => {
                this.showSectionTimePicker(true);
              });
          }
          .width('100%')
          .height(70)
          .padding({ left: 16, right: 16 });

          Divider().color(COLOR_BORDER).strokeWidth(1).margin({ left: 16 });

          Row() {
            Column({ space: 3 }) {
              Text('结束时间')
                .fontSize(16)
                .fontColor(COLOR_TEXT);
              Text('本节课程结束')
                .fontSize(12)
                .fontColor(COLOR_MUTED);
            }
            .alignItems(HorizontalAlign.Start);
            Blank();
            Button(this.draftSectionEnd, { type: ButtonType.Normal })
              .width(92)
              .height(40)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor('#315F80')
              .backgroundColor('#E8F0F6')
              .borderRadius(8)
              .onClick(() => {
                this.showSectionTimePicker(false);
              });
          }
          .width('100%')
          .height(70)
          .padding({ left: 16, right: 16 });
        }
        .width('100%')
        .backgroundColor(COLOR_SURFACE)
        .borderRadius(8)
        .border({ width: 1, color: COLOR_BORDER });

        Button('恢复该节默认时间', { type: ButtonType.Normal })
          .height(42)
          .fontSize(14)
          .fontColor(COLOR_MUTED)
          .backgroundColor('#E9EDEA')
          .borderRadius(8)
          .onClick(() => {
            const range: string[] = DEFAULT_SECTION_RANGES[this.timeEditorSection].split('-');
            this.draftSectionStart = range[0];
            this.draftSectionEnd = range[1];
          });
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 20, right: 20, top: 34 });
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BACKGROUND);
  }

  @Builder
  private DetailPage(course: CourseItem) {
    Column() {
      Row() {
        Button('‹', { type: ButtonType.Normal })
          .width(42)
          .height(42)
          .fontSize(24)
          .fontColor(COLOR_MUTED)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.detailId = -1;
            this.onDetailStateChange(false);
          });
        Text('课程详情')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT);
        Blank();
        Button('编辑', { type: ButtonType.Normal })
          .height(38)
          .fontColor(COLOR_PRIMARY)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.openCourseEditor(course);
          });
      }
      .width('100%')
      .height(58)
      .padding({ left: 8, right: 12 })
      .border({ width: { bottom: 1 }, color: COLOR_BORDER });

      Column({ space: 18 }) {
        Text(course.name)
          .width('100%')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT);
        this.DetailRow('教师', course.teacher.length > 0 ? course.teacher : '未填写');
        this.DetailRow('地点', course.location.length > 0 ? course.location : '未填写');
        this.DetailRow('时间', `${WEEKDAY_NAMES[course.weekday - 1]} · 第${course.startSection}-${course.endSection}节`);
        this.DetailRow('周次', `第${course.startWeek}-${course.endWeek}周 · ${this.parityLabel(course.parity)}`);
        this.DetailRow('下一次上课', this.formatFullDate(this.nextOccurrenceAt(course)));
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 22, right: 22, top: 28 });

      Blank();
      Button(`查看课程待办  ${this.courseTodoCount(course.name)}`, { type: ButtonType.Normal })
        .width('calc(100% - 40vp)')
        .height(48)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_PRIMARY)
        .backgroundColor('#E4F0EC')
        .borderRadius(8)
        .onClick(() => {
          this.onOpenCourseTodos(course);
        });
      Button('添加课程待办', { type: ButtonType.Normal })
        .width('calc(100% - 40vp)')
        .height(52)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor(COLOR_PRIMARY)
        .borderRadius(8)
        .margin({ top: 10 })
        .onClick(() => {
          this.onAddTodo(course, this.nextOccurrenceAt(course));
        });
      Button('删除课程', { type: ButtonType.Normal })
        .width('calc(100% - 40vp)')
        .height(46)
        .fontSize(14)
        .fontColor(COLOR_DANGER)
        .backgroundColor('#FCEDEB')
        .borderRadius(8)
        .margin({ top: 10, bottom: 20 })
        .onClick(() => {
          this.getUIContext().showAlertDialog({
            title: '删除课程',
            message: `确定删除“${course.name}”吗？`,
            buttons: [
              { value: '取消', action: () => {} },
              { value: '删除', fontColor: COLOR_DANGER, action: () => { this.deleteCourse(course); } }
            ]
          });
        });
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BACKGROUND);
  }

  @Builder
  private DetailRow(label: string, value: string) {
    Row() {
      Text(label).width(72).fontSize(14).fontColor(COLOR_MUTED);
      Text(value).layoutWeight(1).fontSize(16).fontColor(COLOR_TEXT).maxLines(3);
    }
    .width('100%')
    .alignItems(VerticalAlign.Top);
  }

  private parityLabel(parity: string): string {
    if (parity === COURSE_PARITY_ODD) {
      return '仅单周';
    }
    if (parity === COURSE_PARITY_EVEN) {
      return '仅双周';
    }
    return '每周';
  }

  @Builder
  private EditorPage() {
    Column() {
      Row() {
        Button('取消', { type: ButtonType.Normal })
          .fontColor(COLOR_MUTED)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.editorOpen = false;
          });
        Blank();
        Text(this.editingId < 0 ? '添加课程' : '编辑课程')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT);
        Blank();
        Button('保存', { type: ButtonType.Normal })
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_PRIMARY)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.saveCourse();
          });
      }
      .width('100%')
      .height(58)
      .padding({ left: 12, right: 12 })
      .border({ width: { bottom: 1 }, color: COLOR_BORDER });

      Scroll() {
        Column({ space: 0 }) {
          this.FieldLabel('课程名称');
          TextInput({ text: this.draftName, placeholder: '例如：高等数学' })
            .height(52)
            .fontSize(17)
            .backgroundColor(COLOR_SURFACE)
            .borderRadius(6)
            .onChange((value: string) => { this.draftName = value; });
          this.FieldLabel('授课教师');
          TextInput({ text: this.draftTeacher, placeholder: '可不填' })
            .height(50)
            .backgroundColor(COLOR_SURFACE)
            .borderRadius(6)
            .onChange((value: string) => { this.draftTeacher = value; });
          this.FieldLabel('上课地点');
          TextInput({ text: this.draftLocation, placeholder: '例如：经信 F3 阶' })
            .height(50)
            .backgroundColor(COLOR_SURFACE)
            .borderRadius(6)
            .onChange((value: string) => { this.draftLocation = value; });

          this.FieldLabel('星期');
          Select(WEEKDAY_NAMES.map((label: string) => ({ value: label } as SelectOption)))
            .selected(this.draftWeekday - 1)
            .value(WEEKDAY_NAMES[this.draftWeekday - 1])
            .width('100%')
            .height(48)
            .backgroundColor(COLOR_SURFACE)
            .onSelect((index: number) => { this.draftWeekday = index + 1; });

          this.FieldLabel('节次');
          Row({ space: 10 }) {
            this.Stepper('开始', this.draftStartSection, () => {
              if (this.draftStartSection > 1) this.draftStartSection--;
            }, () => {
              if (this.draftStartSection < 12) this.draftStartSection++;
            });
            this.Stepper('结束', this.draftEndSection, () => {
              if (this.draftEndSection > 1) this.draftEndSection--;
            }, () => {
              if (this.draftEndSection < 12) this.draftEndSection++;
            });
          }

          this.FieldLabel('上课周次');
          Row({ space: 10 }) {
            this.Stepper('开始周', this.draftStartWeek, () => {
              if (this.draftStartWeek > 1) this.draftStartWeek--;
            }, () => {
              if (this.draftStartWeek < 30) this.draftStartWeek++;
            });
            this.Stepper('结束周', this.draftEndWeek, () => {
              if (this.draftEndWeek > 1) this.draftEndWeek--;
            }, () => {
              if (this.draftEndWeek < 30) this.draftEndWeek++;
            });
          }

          this.FieldLabel('单双周');
          Select([
            { value: '每周' }, { value: '仅单周' }, { value: '仅双周' }
          ])
            .selected(this.draftParity === COURSE_PARITY_ALL ? 0 :
              (this.draftParity === COURSE_PARITY_ODD ? 1 : 2))
            .value(this.parityLabel(this.draftParity))
            .width('100%')
            .height(48)
            .backgroundColor(COLOR_SURFACE)
            .onSelect((index: number) => {
              this.draftParity = index === 0 ? COURSE_PARITY_ALL :
                (index === 1 ? COURSE_PARITY_ODD : COURSE_PARITY_EVEN);
            });
          Blank().height(30);
        }
        .width('100%')
        .padding({ left: 20, right: 20 });
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
  private FieldLabel(label: string) {
    Text(label)
      .width('100%')
      .fontSize(13)
      .fontColor(COLOR_MUTED)
      .padding({ top: 18, bottom: 7 });
  }

  @Builder
  private Stepper(label: string, value: number, decrease: () => void, increase: () => void) {
    Column({ space: 7 }) {
      Text(label).fontSize(12).fontColor(COLOR_MUTED);
      Row() {
        Button('-', { type: ButtonType.Normal })
          .width(38).height(36).fontSize(20)
          .fontColor(COLOR_PRIMARY).backgroundColor('#E8F3EF').borderRadius(6)
          .onClick(decrease);
        Text(`${value}`).layoutWeight(1).fontSize(16).fontColor(COLOR_TEXT).textAlign(TextAlign.Center);
        Button('+', { type: ButtonType.Normal })
          .width(38).height(36).fontSize(20)
          .fontColor(COLOR_PRIMARY).backgroundColor('#E8F3EF').borderRadius(6)
          .onClick(increase);
      }
      .width('100%');
    }
    .layoutWeight(1)
    .padding(10)
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(6)
    .border({ width: 1, color: COLOR_BORDER });
  }

  private selectedCourse(): CourseItem {
    return this.courses.find((item: CourseItem) => item.id === this.detailId) ??
      new CourseItem(-1, '', '', '', 1, 1, 2, 1, 20, COURSE_PARITY_ALL);
  }

  build() {
    if (this.timeEditorSection >= 0) {
      this.TimeEditorPage();
    } else if (this.optionsOpen) {
      this.OptionsPage();
    } else if (this.importOpen) {
      CourseImportPage({
        onClose: () => {
          this.importOpen = false;
        },
        onImported: (courses: CourseItem[], semesterStartAt: number, replace: boolean) => {
          this.importCourses(courses, semesterStartAt, replace);
        }
      });
    } else if (this.editorOpen) {
      this.EditorPage();
    } else {
      if (this.detailId >= 0) {
        this.DetailPage(this.selectedCourse());
      } else {
        this.MainPage();
      }
    }
  }
}
