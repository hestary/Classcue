package com.classcue.android;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

public final class TodoItem {
    public static final String GENERAL = "GENERAL";
    public static final String HOMEWORK = "HOMEWORK";
    public static final String EXAM = "EXAM";
    public static final String QUIZ = "QUIZ";

    public long id;
    public String title = "";
    public String note = "";
    public String location = "";
    public long dueAt;
    public final List<String> imageUris = new ArrayList<>();
    public boolean completed;
    public boolean reminderEnabled = true;
    public final List<Integer> advanceReminderDays = new ArrayList<>();
    public long createdAt;
    public String courseName = "";
    public String taskKind = GENERAL;

    public JSONObject toJson() {
        JSONObject json = new JSONObject();
        try {
            json.put("id", id);
            json.put("title", title);
            json.put("note", note);
            json.put("location", location);
            json.put("dueAt", dueAt);
            json.put("completed", completed);
            json.put("reminderEnabled", reminderEnabled);
            json.put("advanceReminderDays", new JSONArray(advanceReminderDays));
            json.put("createdAt", createdAt);
            json.put("courseName", courseName);
            json.put("taskKind", taskKind);
            json.put("imageUris", new JSONArray(imageUris));
        } catch (Exception ignored) {
        }
        return json;
    }

    public static TodoItem fromJson(JSONObject json) {
        TodoItem item = new TodoItem();
        item.id = json.optLong("id", System.currentTimeMillis());
        item.title = json.optString("title", "");
        item.note = json.optString("note", "");
        item.location = json.optString("location", "");
        item.dueAt = json.optLong("dueAt", System.currentTimeMillis());
        item.completed = json.optBoolean("completed", false);
        item.reminderEnabled = json.optBoolean("reminderEnabled", true);
        JSONArray reminderDays = json.optJSONArray("advanceReminderDays");
        if (reminderDays != null) {
            for (int i = 0; i < reminderDays.length(); i++) {
                int days = reminderDays.optInt(i, 0);
                if (days > 0 && !item.advanceReminderDays.contains(days)) {
                    item.advanceReminderDays.add(days);
                }
            }
        } else {
            int legacyDays = json.optInt("advanceReminderDays", 0);
            if (legacyDays > 0) item.advanceReminderDays.add(legacyDays);
        }
        item.createdAt = json.optLong("createdAt", item.id);
        item.courseName = json.optString("courseName", "");
        item.taskKind = json.optString("taskKind", GENERAL);
        JSONArray images = json.optJSONArray("imageUris");
        if (images != null) {
            for (int i = 0; i < images.length(); i++) {
                String uri = images.optString(i, "");
                if (!uri.isEmpty()) item.imageUris.add(uri);
            }
        }
        return item;
    }
}
