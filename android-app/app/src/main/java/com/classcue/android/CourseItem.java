package com.classcue.android;

import org.json.JSONObject;

public final class CourseItem {
    public static final String ALL = "ALL";
    public static final String ODD = "ODD";
    public static final String EVEN = "EVEN";

    public long id;
    public String name = "";
    public String teacher = "";
    public String location = "";
    public int weekday = 1;
    public int startSection = 1;
    public int endSection = 2;
    public int startWeek = 1;
    public int endWeek = 20;
    public String parity = ALL;

    public JSONObject toJson() {
        JSONObject json = new JSONObject();
        try {
            json.put("id", id);
            json.put("name", name);
            json.put("teacher", teacher);
            json.put("location", location);
            json.put("weekday", weekday);
            json.put("startSection", startSection);
            json.put("endSection", endSection);
            json.put("startWeek", startWeek);
            json.put("endWeek", endWeek);
            json.put("parity", parity);
        } catch (Exception ignored) {
        }
        return json;
    }

    public static CourseItem fromJson(JSONObject json) {
        CourseItem item = new CourseItem();
        item.id = json.optLong("id", System.currentTimeMillis());
        item.name = json.optString("name", "");
        item.teacher = json.optString("teacher", "");
        item.location = json.optString("location", "");
        item.weekday = json.optInt("weekday", 1);
        item.startSection = json.optInt("startSection", 1);
        item.endSection = json.optInt("endSection", 2);
        item.startWeek = json.optInt("startWeek", 1);
        item.endWeek = json.optInt("endWeek", 20);
        item.parity = json.optString("parity", ALL);
        return item;
    }

    public boolean activeInWeek(int week) {
        if (week < startWeek || week > endWeek) return false;
        if (ODD.equals(parity)) return week % 2 == 1;
        if (EVEN.equals(parity)) return week % 2 == 0;
        return true;
    }
}
