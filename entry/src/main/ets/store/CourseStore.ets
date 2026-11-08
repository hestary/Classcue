import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { CourseItem } from '../model/CourseItem';

const STORE_NAME: string = 'course_schedule_store';
const COURSES_KEY: string = 'courses';
const SEMESTER_START_KEY: string = 'semester_start';
const SECTION_RANGES_KEY: string = 'section_ranges';

export class CourseStore {
  private store?: preferences.Preferences;

  async initialize(context: common.UIAbilityContext): Promise<void> {
    if (!this.store) {
      this.store = await preferences.getPreferences(context, { name: STORE_NAME });
    }
  }

  async loadCourses(): Promise<CourseItem[]> {
    if (!this.store) {
      return [];
    }
    const raw: preferences.ValueType = await this.store.get(COURSES_KEY, '[]');
    try {
      const parsed: CourseItem[] = JSON.parse(String(raw)) as CourseItem[];
      return parsed.map((item: CourseItem) => CourseItem.fromJson(item));
    } catch (error) {
      return [];
    }
  }

  async saveCourses(courses: CourseItem[]): Promise<void> {
    if (!this.store) {
      return;
    }
    await this.store.put(COURSES_KEY, JSON.stringify(courses));
    await this.store.flush();
  }

  async loadSemesterStart(): Promise<number> {
    const fallback: number = CourseStore.startOfWeek(Date.now());
    if (!this.store) {
      return fallback;
    }
    const value: preferences.ValueType = await this.store.get(SEMESTER_START_KEY, fallback);
    return CourseStore.startOfWeek(Number(value));
  }

  async saveSemesterStart(timestamp: number): Promise<void> {
    if (!this.store) {
      return;
    }
    await this.store.put(SEMESTER_START_KEY, CourseStore.startOfWeek(timestamp));
    await this.store.flush();
  }

  async loadSectionRanges(defaultRanges: string[]): Promise<string[]> {
    if (!this.store) {
      return defaultRanges.slice();
    }
    const raw: preferences.ValueType = await this.store.get(SECTION_RANGES_KEY, JSON.stringify(defaultRanges));
    try {
      const parsed: string[] = JSON.parse(String(raw)) as string[];
      if (parsed.length !== defaultRanges.length) {
        return defaultRanges.slice();
      }
      return parsed;
    } catch (error) {
      return defaultRanges.slice();
    }
  }

  async saveSectionRanges(ranges: string[]): Promise<void> {
    if (!this.store) {
      return;
    }
    await this.store.put(SECTION_RANGES_KEY, JSON.stringify(ranges));
    await this.store.flush();
  }

  static startOfWeek(timestamp: number): number {
    const date: Date = new Date(timestamp);
    const weekday: number = date.getDay() === 0 ? 7 : date.getDay();
    return new Date(date.getFullYear(), date.getMonth(), date.getDate() - weekday + 1, 0, 0, 0).getTime();
  }
}

export const courseStore: CourseStore = new CourseStore();
