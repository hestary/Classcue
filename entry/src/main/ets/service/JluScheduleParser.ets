import {
  CourseItem,
  COURSE_PARITY_ALL,
  COURSE_PARITY_EVEN,
  COURSE_PARITY_ODD
} from '../model/CourseItem';
import { CourseStore } from '../store/CourseStore';

type RawValue = string | number | null | undefined;

interface JluRawRow {
  KCM?: RawValue;
  SKJS?: RawValue;
  XNXQDM?: RawValue;
  XNXQDM_DISPLAY?: RawValue;
  YPSJDD?: RawValue;
  ZCMC?: RawValue;
  SKXQ?: RawValue;
  KSJC?: RawValue;
  JSJC?: RawValue;
  JASMC?: RawValue;
  JXLDM_DISPLAY?: RawValue;
}

interface JluRawTable {
  rows?: JluRawRow[] | null;
}

interface JluRawDatas {
  cxxszhxqkb?: JluRawTable | null;
  xskcb?: JluRawTable | null;
  rows?: JluRawRow[] | null;
}

interface JluRawResponse {
  datas?: JluRawDatas | null;
}

interface WeekRule {
  startWeek: number;
  endWeek: number;
  parity: string;
}

interface Meeting {
  weekday: number;
  startSection: number;
  endSection: number;
  location: string;
  rules: WeekRule[];
}

export class JluParseResult {
  courses: CourseItem[] = [];
  semesterLabel: string = '';
  semesterStartAt: number = 0;
}

const DEFAULT_WEEKS: number = 20;
const MAX_WEEK: number = 30;
const SEGMENT_PATTERN: RegExp = /^\s*(.*?)\s*星期([一二三四五六日天1-7])\s*[,，]?\s*第\s*(\d+)\s*节?\s*[-—–~～至]\s*第?\s*(\d+)\s*节?\s*(.*)$/;
const WEEK_PREFIX_PATTERN: RegExp = /(?:第?\s*\d+\s*(?:[-—–~～至]\s*\d+)?(?:\s*[,，、]\s*第?\s*\d+\s*(?:[-—–~～至]\s*\d+)?)*\s*周(?:\s*[（(]\s*[单双]\s*[)）]|\s*[单双])?|待定|[单双]周)\s*[,，]?\s*$/;
const DISCRETE_WEEKS_PATTERN: RegExp = /^第?\s*(\d+(?:\s*[,，、]\s*\d+)+)\s*周?\s*(?:[（(]\s*(单|双)\s*[)）])?\s*周?$/;

export class JluScheduleParser {
  static parse(rawContent: string): JluParseResult {
    const result: JluParseResult = new JluParseResult();
    let response: JluRawResponse;
    try {
      response = JSON.parse(rawContent) as JluRawResponse;
    } catch (error) {
      return result;
    }
    const rows: JluRawRow[] = JluScheduleParser.collectRows(response);
    const uniqueRows: JluRawRow[] = [];
    const seen: Set<string> = new Set<string>();
    rows.forEach((row: JluRawRow) => {
      const key: string = [
        JluScheduleParser.text(row.KCM), JluScheduleParser.text(row.SKJS),
        JluScheduleParser.text(row.YPSJDD), JluScheduleParser.text(row.ZCMC),
        JluScheduleParser.text(row.SKXQ), JluScheduleParser.text(row.KSJC),
        JluScheduleParser.text(row.JSJC), JluScheduleParser.text(row.JASMC)
      ].join('|');
      if (!seen.has(key)) {
        seen.add(key);
        uniqueRows.push(row);
      }
    });

    const semesterCounts: Map<string, number> = new Map<string, number>();
    let sequence: number = 0;
    const idBase: number = Date.now();
    uniqueRows.forEach((row: JluRawRow) => {
      const name: string = JluScheduleParser.text(row.KCM).trim();
      if (name.length === 0) {
        return;
      }
      const displaySemester: string = JluScheduleParser.text(row.XNXQDM_DISPLAY).trim();
      const semester: string = displaySemester.length > 0 ? displaySemester :
        JluScheduleParser.text(row.XNXQDM).trim();
      if (semester.length > 0) {
        semesterCounts.set(semester, (semesterCounts.get(semester) ?? 0) + 1);
      }
      JluScheduleParser.meetings(row).forEach((meeting: Meeting) => {
        meeting.rules.forEach((rule: WeekRule) => {
          sequence += 1;
          result.courses.push(new CourseItem(
            idBase + sequence, name, JluScheduleParser.text(row.SKJS).trim(), meeting.location,
            meeting.weekday, meeting.startSection, meeting.endSection,
            rule.startWeek, rule.endWeek, rule.parity
          ));
        });
      });
    });

    let dominantCount: number = 0;
    semesterCounts.forEach((count: number, label: string) => {
      if (count > dominantCount) {
        dominantCount = count;
        result.semesterLabel = label;
      }
    });
    result.semesterStartAt = JluScheduleParser.inferSemesterStart(result.semesterLabel);
    return result;
  }

  private static collectRows(response: JluRawResponse): JluRawRow[] {
    const rows: JluRawRow[] = [];
    const datas: JluRawDatas | null | undefined = response.datas;
    if (!datas) {
      return rows;
    }
    if (datas.cxxszhxqkb && datas.cxxszhxqkb.rows) {
      rows.push(...datas.cxxszhxqkb.rows);
    }
    if (datas.xskcb && datas.xskcb.rows) {
      rows.push(...datas.xskcb.rows);
    }
    if (datas.rows) {
      rows.push(...datas.rows);
    }
    return rows;
  }

  private static text(value: RawValue): string {
    if (value === null || value === undefined) {
      return '';
    }
    return String(value);
  }

  private static number(value: RawValue): number {
    const parsed: number = Number(value);
    return Number.isFinite(parsed) ? Math.trunc(parsed) : -1;
  }

  private static groups(match: RegExpExecArray): string[] {
    return Array.from(match);
  }

  private static trimSeparators(value: string): string {
    return value.replace(/^[\s,，;；]+|[\s,，;；]+$/g, '');
  }

  private static meetings(row: JluRawRow): Meeting[] {
    const arranged: string = JluScheduleParser.text(row.YPSJDD).trim();
    if (arranged.length === 0) {
      const fallback: Meeting | null = JluScheduleParser.fallbackMeeting(row);
      return fallback ? [fallback] : [];
    }
    const parsed: Meeting[] = [];
    JluScheduleParser.splitSegments(arranged).forEach((segment: string) => {
      const meeting: Meeting | null = JluScheduleParser.parseSegment(segment, row);
      if (meeting !== null) {
        parsed.push(meeting);
      }
    });
    if (parsed.length > 0) {
      return parsed;
    }
    const fallback: Meeting | null = JluScheduleParser.fallbackMeeting(row);
    return fallback ? [fallback] : [];
  }

  private static splitSegments(text: string): string[] {
    const markerPattern: RegExp = /星期[一二三四五六日天1-7]/g;
    const markers: number[] = [];
    const markerEnds: number[] = [];
    let match: RegExpExecArray | null = markerPattern.exec(text);
    while (match !== null) {
      const values: string[] = JluScheduleParser.groups(match);
      markers.push(match.index);
      markerEnds.push(match.index + values[0].length);
      match = markerPattern.exec(text);
    }
    if (markers.length <= 1) {
      return [JluScheduleParser.trimSeparators(text)];
    }
    const starts: number[] = [0];
    for (let index: number = 1; index < markers.length; index++) {
      const betweenStart: number = markerEnds[index - 1];
      const between: string = text.substring(betweenStart, markers[index]);
      const weekPrefix: RegExpExecArray | null = WEEK_PREFIX_PATTERN.exec(between);
      if (weekPrefix !== null) {
        starts.push(betweenStart + weekPrefix.index);
      } else {
        const semicolon: number = Math.max(between.lastIndexOf(';'), between.lastIndexOf('；'), between.lastIndexOf('\n'));
        starts.push(semicolon >= 0 ? betweenStart + semicolon + 1 : markers[index]);
      }
    }
    const segments: string[] = [];
    starts.forEach((start: number, index: number) => {
      const end: number = index + 1 < starts.length ? starts[index + 1] : text.length;
      const segment: string = JluScheduleParser.trimSeparators(text.substring(start, end));
      if (segment.length > 0) {
        segments.push(segment);
      }
    });
    return segments;
  }

  private static parseSegment(segment: string, row: JluRawRow): Meeting | null {
    const match: RegExpExecArray | null = SEGMENT_PATTERN.exec(segment);
    if (!match) {
      return null;
    }
    const values: string[] = JluScheduleParser.groups(match);
    const weekday: number = JluScheduleParser.weekday(values[2]);
    const firstSection: number = Number(values[3]);
    const lastSection: number = Number(values[4]);
    if (weekday < 1 || firstSection < 1 || lastSection < 1) {
      return null;
    }
    const parsedLocation: string = JluScheduleParser.trimSeparators(values[5]);
    const classroom: string = JluScheduleParser.text(row.JASMC).trim();
    const fallbackLocation: string = classroom.length > 0 ? classroom :
      JluScheduleParser.text(row.JXLDM_DISPLAY).trim();
    const arrangedWeekText: string = JluScheduleParser.trimSeparators(values[1]);
    const weekText: string = arrangedWeekText.length > 0 ? arrangedWeekText : JluScheduleParser.text(row.ZCMC);
    return {
      weekday,
      startSection: Math.min(firstSection, lastSection),
      endSection: Math.max(firstSection, lastSection),
      location: parsedLocation.length > 0 ? parsedLocation : fallbackLocation,
      rules: JluScheduleParser.weekRules(weekText)
    };
  }

  private static fallbackMeeting(row: JluRawRow): Meeting | null {
    const weekday: number = JluScheduleParser.number(row.SKXQ);
    const firstSection: number = JluScheduleParser.number(row.KSJC);
    const lastSection: number = JluScheduleParser.number(row.JSJC);
    if (weekday < 1 || weekday > 7 || firstSection < 1 || lastSection < 1) {
      return null;
    }
    const classroom: string = JluScheduleParser.text(row.JASMC).trim();
    const location: string = classroom.length > 0 ? classroom : JluScheduleParser.text(row.JXLDM_DISPLAY).trim();
    return {
      weekday,
      startSection: Math.min(firstSection, lastSection),
      endSection: Math.max(firstSection, lastSection),
      location,
      rules: JluScheduleParser.weekRules(JluScheduleParser.text(row.ZCMC))
    };
  }

  private static weekday(value: string): number {
    const labels: string[] = ['一', '二', '三', '四', '五', '六', '日'];
    if (value === '天') {
      return 7;
    }
    const numeric: number = Number(value);
    if (Number.isInteger(numeric) && numeric >= 1 && numeric <= 7) {
      return numeric;
    }
    const index: number = labels.indexOf(value);
    return index >= 0 ? index + 1 : -1;
  }

  private static weekRules(weekText: string): WeekRule[] {
    const value: string = weekText.trim();
    const defaultParity: string = value.includes('单') ? COURSE_PARITY_ODD :
      (value.includes('双') ? COURSE_PARITY_EVEN : COURSE_PARITY_ALL);
    if (!/[0-9]/.test(value)) {
      return [{ startWeek: 1, endWeek: DEFAULT_WEEKS, parity: defaultParity }];
    }
    const discrete: RegExpExecArray | null = DISCRETE_WEEKS_PATTERN.exec(value);
    if (discrete) {
      const values: string[] = JluScheduleParser.groups(discrete);
      const parity: string = values[2] === '单' ? COURSE_PARITY_ODD :
        (values[2] === '双' ? COURSE_PARITY_EVEN : COURSE_PARITY_ALL);
      const rules: WeekRule[] = [];
      values[1].split(/[,，、]/).forEach((part: string) => {
        const week: number = Number(part.trim());
        if (Number.isInteger(week) && week >= 1 && week <= MAX_WEEK) {
          rules.push({ startWeek: week, endWeek: week, parity });
        }
      });
      if (rules.length > 0) {
        return rules;
      }
    }
    const rules: WeekRule[] = [];
    const itemPattern: RegExp = /第?(\d+)\s*(?:[-—–~～至]\s*(\d+))?\s*周(?:\s*[（(]\s*(单|双)\s*[)）]|\s*(单|双))?/g;
    let match: RegExpExecArray | null = itemPattern.exec(value);
    while (match !== null) {
      const values: string[] = JluScheduleParser.groups(match);
      const first: number = Number(values[1]);
      const second: number = values[2] ? Number(values[2]) : first;
      const parityText: string = values[3] || values[4] || '';
      const parity: string = parityText === '单' ? COURSE_PARITY_ODD :
        (parityText === '双' ? COURSE_PARITY_EVEN : COURSE_PARITY_ALL);
      if (first >= 1 && first <= MAX_WEEK && second >= 1 && second <= MAX_WEEK) {
        rules.push({ startWeek: Math.min(first, second), endWeek: Math.max(first, second), parity });
      }
      match = itemPattern.exec(value);
    }
    return rules.length > 0 ? rules : [{ startWeek: 1, endWeek: DEFAULT_WEEKS, parity: defaultParity }];
  }

  private static inferSemesterStart(label: string): number {
    const match: RegExpExecArray | null = /(20\d{2})\D+(20\d{2})\D*([12])/.exec(label);
    if (!match) {
      return 0;
    }
    const values: string[] = JluScheduleParser.groups(match);
    const firstYear: number = Number(values[1]);
    const secondYear: number = Number(values[2]);
    const term: number = Number(values[3]);
    const estimate: number = term === 1 ? new Date(firstYear, 8, 1, 0, 0, 0).getTime() :
      new Date(secondYear, 1, 24, 0, 0, 0).getTime();
    return CourseStore.startOfWeek(estimate);
  }
}
