package com.classcue.android;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.List;

public final class AppStore {
    private static final String PREFS = "classcue_store";
    private static final String TODOS = "todos";
    private static final String COURSES = "courses";
    private static final String SEMESTER_START = "semester_start";
    private static final String SECTION_RANGES = "section_ranges";

    public static final String[] DEFAULT_RANGES = {
            "08:00-08:45", "08:45-09:40", "10:00-10:45", "10:45-11:40",
            "13:30-14:15", "14:15-15:10", "15:30-16:15", "16:15-17:10",
            "18:20-19:05", "19:05-19:50", "20:00-20:45", "20:45-21:30"
    };

    private static SharedPreferences prefs(Context context) {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    public static List<TodoItem> loadTodos(Context context) {
        List<TodoItem> result = new ArrayList<>();
        try {
            JSONArray array = new JSONArray(prefs(context).getString(TODOS, "[]"));
            for (int i = 0; i < array.length(); i++) result.add(TodoItem.fromJson(array.getJSONObject(i)));
        } catch (Exception ignored) {
        }
        return result;
    }

    public static void saveTodos(Context context, List<TodoItem> items) {
        JSONArray array = new JSONArray();
        for (TodoItem item : items) array.put(item.toJson());
        prefs(context).edit().putString(TODOS, array.toString()).apply();
    }

    public static List<CourseItem> loadCourses(Context context) {
        List<CourseItem> result = new ArrayList<>();
        try {
            JSONArray array = new JSONArray(prefs(context).getString(COURSES, "[]"));
            for (int i = 0; i < array.length(); i++) result.add(CourseItem.fromJson(array.getJSONObject(i)));
        } catch (Exception ignored) {
        }
        return result;
    }

    public static void saveCourses(Context context, List<CourseItem> items) {
        JSONArray array = new JSONArray();
        for (CourseItem item : items) array.put(item.toJson());
        prefs(context).edit().putString(COURSES, array.toString()).apply();
    }

    public static long loadSemesterStart(Context context) {
        long saved = prefs(context).getLong(SEMESTER_START, 0L);
        return saved > 0 ? startOfWeek(saved) : startOfWeek(System.currentTimeMillis());
    }

    public static void saveSemesterStart(Context context, long value) {
        prefs(context).edit().putLong(SEMESTER_START, startOfWeek(value)).apply();
    }

    public static String[] loadSectionRanges(Context context) {
        String raw = prefs(context).getString(SECTION_RANGES, "");
        if (raw == null || raw.isEmpty()) return DEFAULT_RANGES.clone();
        try {
            JSONArray array = new JSONArray(raw);
            if (array.length() != DEFAULT_RANGES.length) return DEFAULT_RANGES.clone();
            String[] result = new String[array.length()];
            for (int i = 0; i < result.length; i++) result[i] = array.getString(i);
            return result;
        } catch (Exception ignored) {
            return DEFAULT_RANGES.clone();
        }
    }

    public static void saveSectionRanges(Context context, String[] ranges) {
        JSONArray array = new JSONArray();
        for (String range : ranges) array.put(range);
        prefs(context).edit().putString(SECTION_RANGES, array.toString()).apply();
    }

    public static long startOfWeek(long timestamp) {
        Calendar calendar = Calendar.getInstance();
        calendar.setTimeInMillis(timestamp);
        int day = calendar.get(Calendar.DAY_OF_WEEK);
        int offset = day == Calendar.SUNDAY ? -6 : Calendar.MONDAY - day;
        calendar.add(Calendar.DAY_OF_MONTH, offset);
        calendar.set(Calendar.HOUR_OF_DAY, 0);
        calendar.set(Calendar.MINUTE, 0);
        calendar.set(Calendar.SECOND, 0);
        calendar.set(Calendar.MILLISECOND, 0);
        return calendar.getTimeInMillis();
    }

    private AppStore() {
    }
}
