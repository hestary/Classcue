package com.classcue.android;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class JluScheduleParser {
    public static final class Result {
        public final List<CourseItem> courses = new ArrayList<>();
        public String semesterLabel = "";
        public long semesterStartAt;
    }

    private static final Pattern SEGMENT = Pattern.compile(
            "^\\s*(.*?)\\s*星期([一二三四五六日天1-7])\\s*[,，]?\\s*第\\s*(\\d+)\\s*节?\\s*[-—–~～至]\\s*第?\\s*(\\d+)\\s*节?\\s*(.*)$");
    private static final Pattern WEEK_PREFIX = Pattern.compile(
            "(?:第?\\s*\\d+\\s*(?:[-—–~～至]\\s*\\d+)?(?:\\s*[,，、]\\s*第?\\s*\\d+\\s*(?:[-—–~～至]\\s*\\d+)?)*\\s*周(?:\\s*[（(]\\s*[单双]\\s*[)）]|\\s*[单双])?|待定|[单双]周)\\s*[,，]?\\s*$");
    private static final Pattern DISCRETE_WEEKS = Pattern.compile(
            "^第?\\s*(\\d+(?:\\s*[,，、]\\s*\\d+)+)\\s*周?\\s*(?:[（(]\\s*(单|双)\\s*[)）])?\\s*周?$");
    private static final Pattern WEEK_ITEM = Pattern.compile(
            "第?(\\d+)\\s*(?:[-—–~～至]\\s*(\\d+))?\\s*周(?:\\s*[（(]\\s*(单|双)\\s*[)）]|\\s*(单|双))?");

    public static Result parse(String raw) {
        Result result = new Result();
        try {
            JSONObject root = new JSONObject(raw);
            JSONObject datas = root.optJSONObject("datas");
            if (datas == null) return result;
            List<JSONObject> rows = new ArrayList<>();
            addRows(rows, datas.optJSONObject("cxxszhxqkb"));
            addRows(rows, datas.optJSONObject("xskcb"));
            addArray(rows, datas.optJSONArray("rows"));
            Set<String> seen = new HashSet<>();
            Map<String, Integer> semesterCounts = new LinkedHashMap<>();
            long id = System.currentTimeMillis();
            int sequence = 0;
            for (JSONObject row : rows) {
                String name = text(row, "KCM").trim();
                if (name.isEmpty()) continue;
                String key = name + "|" + text(row, "SKJS") + "|" + text(row, "YPSJDD")
                        + "|" + text(row, "ZCMC") + "|" + text(row, "SKXQ")
                        + "|" + text(row, "KSJC") + "|" + text(row, "JSJC")
                        + "|" + text(row, "JASMC") + "|" + text(row, "JXLDM_DISPLAY");
                if (!seen.add(key)) continue;
                String semester = text(row, "XNXQDM_DISPLAY").trim();
                if (semester.isEmpty()) semester = text(row, "XNXQDM").trim();
                if (!semester.isEmpty()) semesterCounts.put(semester, semesterCounts.getOrDefault(semester, 0) + 1);
                for (Meeting meeting : meetings(row)) {
                    for (WeekRule rule : meeting.rules) {
                        CourseItem course = new CourseItem();
                        course.id = id + (++sequence);
                        course.name = name;
                        course.teacher = text(row, "SKJS").trim();
                        course.location = meeting.location;
                        course.weekday = meeting.weekday;
                        course.startSection = meeting.startSection;
                        course.endSection = meeting.endSection;
                        course.startWeek = rule.start;
                        course.endWeek = rule.end;
                        course.parity = rule.parity;
                        result.courses.add(course);
                    }
                }
            }
            int dominant = 0;
            for (Map.Entry<String, Integer> entry : semesterCounts.entrySet()) {
                if (entry.getValue() > dominant) {
                    dominant = entry.getValue();
                    result.semesterLabel = entry.getKey();
                }
            }
            result.semesterStartAt = inferSemesterStart(result.semesterLabel);
        } catch (Exception ignored) {
        }
        return result;
    }

    private static void addRows(List<JSONObject> rows, JSONObject table) {
        if (table != null) addArray(rows, table.optJSONArray("rows"));
    }

    private static void addArray(List<JSONObject> rows, JSONArray array) {
        if (array == null) return;
        for (int i = 0; i < array.length(); i++) {
            JSONObject row = array.optJSONObject(i);
            if (row != null) rows.add(row);
        }
    }

    private static String text(JSONObject row, String key) {
        Object value = row.opt(key);
        return value == null || value == JSONObject.NULL ? "" : String.valueOf(value);
    }

    private static int number(JSONObject row, String key) {
        try {
            return Integer.parseInt(text(row, key));
        } catch (Exception ignored) {
            return -1;
        }
    }

    private static List<Meeting> meetings(JSONObject row) {
        String arranged = text(row, "YPSJDD").trim();
        List<Meeting> result = new ArrayList<>();
        if (!arranged.isEmpty()) {
            for (String segment : splitSegments(arranged)) {
                Meeting meeting = parseSegment(segment, row);
                if (meeting != null) result.add(meeting);
            }
        }
        if (result.isEmpty()) {
            Meeting fallback = fallbackMeeting(row);
            if (fallback != null) result.add(fallback);
        }
        return result;
    }

    static List<String> splitSegments(String text) {
        List<Integer> markers = new ArrayList<>();
        List<Integer> markerEnds = new ArrayList<>();
        Matcher matcher = Pattern.compile("星期[一二三四五六日天1-7]").matcher(text);
        while (matcher.find()) {
            markers.add(matcher.start());
            markerEnds.add(matcher.end());
        }
        List<String> result = new ArrayList<>();
        if (markers.size() <= 1) {
            result.add(trim(text));
            return result;
        }
        List<Integer> starts = new ArrayList<>();
        starts.add(0);
        for (int i = 1; i < markers.size(); i++) {
            int betweenStart = markerEnds.get(i - 1);
            String between = text.substring(betweenStart, markers.get(i));
            Matcher weekPrefix = WEEK_PREFIX.matcher(between);
            if (weekPrefix.find()) {
                starts.add(betweenStart + weekPrefix.start());
            } else {
                int semicolon = Math.max(between.lastIndexOf(';'),
                        Math.max(between.lastIndexOf('；'), between.lastIndexOf('\n')));
                starts.add(semicolon >= 0 ? betweenStart + semicolon + 1 : markers.get(i));
            }
        }
        for (int i = 0; i < starts.size(); i++) {
            int end = i + 1 < starts.size() ? starts.get(i + 1) : text.length();
            String segment = trim(text.substring(starts.get(i), end));
            if (!segment.isEmpty()) result.add(segment);
        }
        return result;
    }

    private static Meeting parseSegment(String segment, JSONObject row) {
        Matcher match = SEGMENT.matcher(segment);
        if (!match.matches()) return null;
        int weekday = weekday(match.group(2));
        int first = Integer.parseInt(match.group(3));
        int last = Integer.parseInt(match.group(4));
        if (weekday < 1 || first < 1 || last < 1) return null;
        String location = trim(match.group(5));
        if (location.isEmpty()) location = fallbackLocation(row);
        Meeting meeting = new Meeting();
        meeting.weekday = weekday;
        meeting.startSection = Math.min(first, last);
        meeting.endSection = Math.max(first, last);
        meeting.location = location;
        String weekText = trim(match.group(1));
        if (weekText.isEmpty()) weekText = text(row, "ZCMC");
        meeting.rules.addAll(weekRules(weekText));
        return meeting;
    }

    private static Meeting fallbackMeeting(JSONObject row) {
        int weekday = number(row, "SKXQ");
        int first = number(row, "KSJC");
        int last = number(row, "JSJC");
        if (weekday < 1 || weekday > 7 || first < 1 || last < 1) return null;
        Meeting meeting = new Meeting();
        meeting.weekday = weekday;
        meeting.startSection = Math.min(first, last);
        meeting.endSection = Math.max(first, last);
        meeting.location = fallbackLocation(row);
        meeting.rules.addAll(weekRules(text(row, "ZCMC")));
        return meeting;
    }

    private static String fallbackLocation(JSONObject row) {
        String value = text(row, "JASMC").trim();
        return value.isEmpty() ? text(row, "JXLDM_DISPLAY").trim() : value;
    }

    private static int weekday(String value) {
        if ("天".equals(value) || "日".equals(value)) return 7;
        String labels = "一二三四五六";
        int index = labels.indexOf(value);
        if (index >= 0) return index + 1;
        try {
            int number = Integer.parseInt(value);
            return number >= 1 && number <= 7 ? number : -1;
        } catch (Exception ignored) {
            return -1;
        }
    }

    private static List<WeekRule> weekRules(String text) {
        List<WeekRule> result = new ArrayList<>();
        String value = text == null ? "" : text.trim();
        String fallbackParity = value.contains("单") ? CourseItem.ODD : value.contains("双") ? CourseItem.EVEN : CourseItem.ALL;
        Matcher discrete = DISCRETE_WEEKS.matcher(value);
        if (discrete.matches()) {
            String parityText = discrete.group(2);
            String parity = "单".equals(parityText) ? CourseItem.ODD
                    : "双".equals(parityText) ? CourseItem.EVEN : CourseItem.ALL;
            for (String part : discrete.group(1).split("[,，、]")) {
                int week = Integer.parseInt(part.trim());
                if (week >= 1 && week <= 30) result.add(new WeekRule(week, week, parity));
            }
            if (!result.isEmpty()) return result;
        }
        Matcher matcher = WEEK_ITEM.matcher(value);
        while (matcher.find()) {
            int first = Integer.parseInt(matcher.group(1));
            int last = matcher.group(2) == null ? first : Integer.parseInt(matcher.group(2));
            String parityText = matcher.group(3) != null ? matcher.group(3) : matcher.group(4);
            String parity = "单".equals(parityText) ? CourseItem.ODD : "双".equals(parityText) ? CourseItem.EVEN : CourseItem.ALL;
            if (first >= 1 && first <= 30 && last >= 1 && last <= 30) {
                result.add(new WeekRule(Math.min(first, last), Math.max(first, last), parity));
            }
        }
        if (result.isEmpty()) result.add(new WeekRule(1, 20, fallbackParity));
        return result;
    }

    private static long inferSemesterStart(String label) {
        Matcher matcher = Pattern.compile("(20\\d{2})\\D+(20\\d{2})\\D*([12])").matcher(label == null ? "" : label);
        if (!matcher.find()) return 0;
        int firstYear = Integer.parseInt(matcher.group(1));
        int secondYear = Integer.parseInt(matcher.group(2));
        int term = Integer.parseInt(matcher.group(3));
        Calendar date = Calendar.getInstance();
        date.clear();
        date.set(term == 1 ? firstYear : secondYear, term == 1 ? Calendar.SEPTEMBER : Calendar.FEBRUARY,
                term == 1 ? 1 : 24);
        return AppStore.startOfWeek(date.getTimeInMillis());
    }

    private static String trim(String value) {
        return value == null ? "" : value.replaceAll("^[\\s,，;；]+|[\\s,，;；]+$", "");
    }

    private static final class Meeting {
        int weekday;
        int startSection;
        int endSection;
        String location = "";
        final List<WeekRule> rules = new ArrayList<>();
    }

    private static final class WeekRule {
        final int start;
        final int end;
        final String parity;

        WeekRule(int start, int end, String parity) {
            this.start = start;
            this.end = end;
            this.parity = parity;
        }
    }

    private JluScheduleParser() {
    }
}
