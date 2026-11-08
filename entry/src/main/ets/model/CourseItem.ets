export const COURSE_PARITY_ALL: string = 'ALL';
export const COURSE_PARITY_ODD: string = 'ODD';
export const COURSE_PARITY_EVEN: string = 'EVEN';

export class CourseItem {
  id: number = 0;
  name: string = '';
  teacher: string = '';
  location: string = '';
  weekday: number = 1;
  startSection: number = 1;
  endSection: number = 2;
  startWeek: number = 1;
  endWeek: number = 20;
  parity: string = COURSE_PARITY_ALL;

  constructor(id: number, name: string, teacher: string, location: string, weekday: number,
    startSection: number, endSection: number, startWeek: number, endWeek: number, parity: string) {
    this.id = id;
    this.name = name;
    this.teacher = teacher;
    this.location = location;
    this.weekday = weekday;
    this.startSection = startSection;
    this.endSection = endSection;
    this.startWeek = startWeek;
    this.endWeek = endWeek;
    this.parity = parity;
  }

  static fromJson(item: CourseItem): CourseItem {
    return new CourseItem(
      item.id,
      item.name,
      item.teacher ?? '',
      item.location ?? '',
      item.weekday ?? 1,
      item.startSection ?? 1,
      item.endSection ?? 2,
      item.startWeek ?? 1,
      item.endWeek ?? 20,
      item.parity ?? COURSE_PARITY_ALL
    );
  }
}
