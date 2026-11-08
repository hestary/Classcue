package com.classcue.android;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.AlertDialog;
import android.app.DatePickerDialog;
import android.app.NotificationManager;
import android.app.TimePickerDialog;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowInsets;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.HorizontalScrollView;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.NumberPicker;
import android.widget.PopupMenu;
import android.widget.ScrollView;
import android.widget.Spinner;
import android.widget.ArrayAdapter;
import android.widget.Switch;
import android.widget.TextView;
import android.widget.Toast;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Calendar;
import java.util.Comparator;
import java.util.Date;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

public final class MainActivity extends Activity {
    private static final int PHOTO_REQUEST = 601;
    private static final String JLU_LOGIN_URL = "https://iedu.jlu.edu.cn/";
    private static final String JLU_SCHEDULE_URL = "https://iedu.jlu.edu.cn/jwapp/sys/wdkb/*default/index.do";
    private static final String JLU_VPN_URL = "https://vpn.jlu.edu.cn/";
    private static final int[] ADVANCE_REMINDER_DAYS = {1, 2, 3, 7, 14};
    private static final String[] ADVANCE_REMINDER_LABELS = {
            "提前1天", "提前2天", "提前3天", "提前7天", "提前14天"
    };
    private static final int PRIMARY = 0xFF176B54;
    private static final int PRIMARY_DARK = 0xFF124C3E;
    private static final int BACKGROUND = 0xFFF3F5F4;
    private static final int SURFACE = 0xFFFFFFFF;
    private static final int TEXT = 0xFF17201D;
    private static final int MUTED = 0xFF6B7772;
    private static final int BORDER = 0xFFDCE3E0;
    private static final int DANGER = 0xFFC6463D;
    private static final int WARNING = 0xFFA8610A;

    private final List<TodoItem> todos = new ArrayList<>();
    private final List<CourseItem> courses = new ArrayList<>();
    private final List<String> draftImages = new ArrayList<>();
    private final List<String> capturedResponses = new ArrayList<>();
    private int mainTab;
    private int todoTab;
    private String selectedFolder = "";
    private int selectedWeek = 1;
    private long semesterStart;
    private String[] sectionRanges = AppStore.DEFAULT_RANGES.clone();
    private String screen = "main";
    private FrameLayout content;
    private TodoItem editingTodo;
    private LinearLayout imageStrip;
    private ScheduleView activeScheduleView;
    private TextView activeWeekTitle;
    private TextView activeWeekRange;
    private Button activePreviousWeekButton;
    private Button activeNextWeekButton;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setStatusBarColor(BACKGROUND);
        getWindow().setNavigationBarColor(Color.WHITE);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            getWindow().setDecorFitsSystemWindows(false);
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            int flags = View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                flags |= View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR;
            }
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
                flags |= View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION;
            }
            getWindow().getDecorView().setSystemUiVisibility(flags);
        }
        todos.addAll(AppStore.loadTodos(this));
        courses.addAll(AppStore.loadCourses(this));
        semesterStart = AppStore.loadSemesterStart(this);
        sectionRanges = AppStore.loadSectionRanges(this);
        selectedWeek = currentWeek();
        ReminderReceiver.ensureChannel(getSystemService(NotificationManager.class));
        requestNotificationPermission();
        showMain(0);
    }

    private void requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= 33
                && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 501);
        }
    }

    private int dp(float value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private void setAppContent(View root) {
        root.setOnApplyWindowInsetsListener((view, insets) -> {
            int left;
            int top;
            int right;
            int bottom;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                android.graphics.Insets bars = insets.getInsets(
                        WindowInsets.Type.systemBars() | WindowInsets.Type.displayCutout());
                left = bars.left;
                top = bars.top;
                right = bars.right;
                bottom = bars.bottom;
            } else {
                left = insets.getSystemWindowInsetLeft();
                top = insets.getSystemWindowInsetTop();
                right = insets.getSystemWindowInsetRight();
                bottom = insets.getSystemWindowInsetBottom();
            }
            view.setPadding(left, top, right, bottom);
            return insets;
        });
        setContentView(root);
        root.requestApplyInsets();
    }

    private GradientDrawable bg(int color, float radius, int strokeColor, float strokeWidth) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(color);
        drawable.setCornerRadius(dp(radius));
        if (strokeWidth > 0) drawable.setStroke(dp(strokeWidth), strokeColor);
        return drawable;
    }

    private TextView text(String value, float size, int color, boolean bold) {
        TextView view = new TextView(this);
        view.setText(value);
        view.setTextSize(size);
        view.setTextColor(color);
        view.setGravity(Gravity.CENTER_VERTICAL);
        if (bold) view.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        return view;
    }

    private Button button(String label, int foreground, int background) {
        Button button = new Button(this);
        button.setText(label);
        button.setTextSize(14);
        button.setTextColor(foreground);
        button.setAllCaps(false);
        button.setMinHeight(0);
        button.setMinWidth(0);
        button.setPadding(dp(12), 0, dp(12), 0);
        button.setBackground(bg(background, 7, Color.TRANSPARENT, 0));
        return button;
    }

    private EditText input(String value, String hint, boolean multiline) {
        EditText edit = new EditText(this);
        edit.setText(value);
        edit.setHint(hint);
        edit.setTextColor(TEXT);
        edit.setHintTextColor(0xFF9AA39F);
        edit.setTextSize(16);
        edit.setSingleLine(!multiline);
        edit.setGravity(multiline ? Gravity.TOP : Gravity.CENTER_VERTICAL);
        edit.setPadding(dp(13), multiline ? dp(12) : 0, dp(13), multiline ? dp(12) : 0);
        edit.setBackground(bg(SURFACE, 7, BORDER, 1));
        if (multiline) {
            edit.setMinHeight(dp(100));
            edit.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE);
        }
        return edit;
    }

    private void addLabel(LinearLayout parent, String value) {
        TextView label = text(value, 13, MUTED, false);
        label.setPadding(0, dp(18), 0, dp(7));
        parent.addView(label, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
    }

    private LinearLayout row() {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        return row;
    }

    private LinearLayout.LayoutParams weight(float value) {
        return new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, value);
    }

    private void showMain(int tab) {
        screen = "main";
        mainTab = tab;
        clearCourseViewReferences();
        LinearLayout shell = new LinearLayout(this);
        shell.setOrientation(LinearLayout.VERTICAL);
        shell.setBackgroundColor(BACKGROUND);
        content = new FrameLayout(this);
        shell.addView(content, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
        shell.addView(bottomNavigation(), new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(62)));
        setAppContent(shell);
        View page = tab == 0 ? homePage() : coursePage();
        page.setAlpha(0f);
        content.addView(page, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        page.animate().alpha(1f).setDuration(160).start();
    }

    private void clearCourseViewReferences() {
        activeScheduleView = null;
        activeWeekTitle = null;
        activeWeekRange = null;
        activePreviousWeekButton = null;
        activeNextWeekButton = null;
    }

    private View bottomNavigation() {
        LinearLayout nav = row();
        nav.setPadding(dp(16), dp(7), dp(16), dp(7));
        nav.setBackground(bg(SURFACE, 0, BORDER, 1));
        Button todo = button("待办", mainTab == 0 ? Color.WHITE : MUTED, mainTab == 0 ? PRIMARY : Color.TRANSPARENT);
        Button course = button("课表", mainTab == 1 ? Color.WHITE : MUTED, mainTab == 1 ? PRIMARY : Color.TRANSPARENT);
        todo.setTypeface(Typeface.DEFAULT, mainTab == 0 ? Typeface.BOLD : Typeface.NORMAL);
        course.setTypeface(Typeface.DEFAULT, mainTab == 1 ? Typeface.BOLD : Typeface.NORMAL);
        todo.setOnClickListener(v -> showMain(0));
        course.setOnClickListener(v -> showMain(1));
        LinearLayout.LayoutParams first = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1);
        first.setMarginEnd(dp(5));
        nav.addView(todo, first);
        LinearLayout.LayoutParams second = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1);
        second.setMarginStart(dp(5));
        nav.addView(course, second);
        return nav;
    }

    private View homePage() {
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setBackgroundColor(BACKGROUND);

        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.VERTICAL);
        header.setPadding(dp(20), dp(20), dp(20), dp(14));
        header.addView(text("今天要做", 29, TEXT, true));
        TextView subtitle = text(todayLabel() + " · " + pendingCount() + " 项待办", 14, MUTED, false);
        subtitle.setPadding(0, dp(5), 0, 0);
        header.addView(subtitle);
        page.addView(header);

        LinearLayout tabs = row();
        tabs.setPadding(dp(4), dp(4), dp(4), dp(4));
        tabs.setBackground(bg(0xFFE7ECE9, 8, Color.TRANSPARENT, 0));
        Button pending = button("待办  " + pendingCount(), todoTab == 0 ? Color.WHITE : MUTED,
                todoTab == 0 ? PRIMARY : Color.TRANSPARENT);
        Button done = button("已完成  " + (todos.size() - pendingCount()), todoTab == 1 ? Color.WHITE : MUTED,
                todoTab == 1 ? PRIMARY : Color.TRANSPARENT);
        pending.setOnClickListener(v -> { todoTab = 0; showMain(0); });
        done.setOnClickListener(v -> { todoTab = 1; showMain(0); });
        tabs.addView(pending, weight(1));
        tabs.addView(done, weight(1));
        LinearLayout.LayoutParams tabParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(46));
        tabParams.setMargins(dp(20), 0, dp(20), dp(12));
        page.addView(tabs, tabParams);

        Button folder = button("课程文件夹    " + folderLabel() + "    " + visibleTodos().size() + " 项  ▾", TEXT, SURFACE);
        folder.setGravity(Gravity.START | Gravity.CENTER_VERTICAL);
        folder.setBackground(bg(SURFACE, 7, BORDER, 1));
        folder.setOnClickListener(this::showFolderMenu);
        LinearLayout.LayoutParams folderParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(46));
        folderParams.setMargins(dp(20), 0, dp(20), dp(12));
        page.addView(folder, folderParams);

        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        scroll.setClipToPadding(false);
        LinearLayout list = new LinearLayout(this);
        list.setOrientation(LinearLayout.VERTICAL);
        list.setPadding(dp(20), 0, dp(20), dp(14));
        List<TodoItem> visible = visibleTodos();
        if (visible.isEmpty()) {
            LinearLayout empty = new LinearLayout(this);
            empty.setOrientation(LinearLayout.VERTICAL);
            empty.setGravity(Gravity.CENTER);
            empty.setPadding(dp(20), dp(80), dp(20), dp(60));
            empty.addView(text(todoTab == 0 ? "今天从一件小事开始" : "还没有已完成的待办", 18, TEXT, true));
            TextView hint = text(todoTab == 0 ? "添加待办后，会按时通过通知提醒你。" : "完成的事项会保留在这里。", 14, MUTED, false);
            hint.setGravity(Gravity.CENTER);
            hint.setPadding(0, dp(10), 0, 0);
            empty.addView(hint);
            list.addView(empty, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(260)));
        } else {
            for (TodoItem item : visible) list.addView(todoCard(item));
        }
        scroll.addView(list);
        page.addView(scroll, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));

        Button add = button("新增待办", Color.WHITE, PRIMARY);
        add.setTextSize(16);
        add.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        add.setOnClickListener(v -> showTodoEditor(null, null, 0));
        LinearLayout.LayoutParams addParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52));
        addParams.setMargins(dp(20), dp(8), dp(20), dp(16));
        page.addView(add, addParams);
        return page;
    }

    private View todoCard(TodoItem item) {
        LinearLayout card = row();
        card.setGravity(Gravity.TOP);
        card.setPadding(dp(14), dp(14), dp(14), dp(14));
        card.setBackground(bg(SURFACE, 8, BORDER, 1));
        CheckBox check = new CheckBox(this);
        check.setChecked(item.completed);
        check.setButtonTintList(new android.content.res.ColorStateList(
                new int[][]{new int[]{android.R.attr.state_checked}, new int[]{}}, new int[]{PRIMARY, MUTED}));
        check.setOnCheckedChangeListener((buttonView, isChecked) -> {
            item.completed = isChecked;
            AppStore.saveTodos(this, todos);
            if (isChecked) ReminderScheduler.cancel(this, item.id); else ReminderScheduler.schedule(this, item);
            showMain(0);
        });
        card.addView(check, new LinearLayout.LayoutParams(dp(42), dp(42)));

        LinearLayout body = new LinearLayout(this);
        body.setOrientation(LinearLayout.VERTICAL);
        TextView badges = text(kindLabel(item.taskKind) + (item.courseName.isEmpty() ? "" : "   " + item.courseName), 11,
                kindColor(item.taskKind), true);
        badges.setPadding(0, 0, 0, dp(6));
        body.addView(badges);
        TextView title = text(item.title, 17, item.completed ? MUTED : TEXT, true);
        title.setMaxLines(2);
        body.addView(title);
        if (!item.note.isEmpty()) {
            TextView note = text(item.note, 14, MUTED, false);
            note.setMaxLines(2);
            note.setPadding(0, dp(6), 0, 0);
            body.addView(note);
        }
        if (!item.location.isEmpty()) {
            TextView location = text("地点：" + item.location, 13, 0xFF276B9A, false);
            location.setPadding(0, dp(6), 0, 0);
            body.addView(location);
        }
        String meta = formatDate(item.dueAt);
        if (item.reminderEnabled && !item.completed) {
            meta += "  ·  " + reminderMeta(item.advanceReminderDays);
        }
        if (!item.imageUris.isEmpty()) meta += "  ·  " + item.imageUris.size() + "张图片";
        TextView date = text(meta, 12, !item.completed && item.dueAt < System.currentTimeMillis() ? DANGER : MUTED, false);
        date.setPadding(0, dp(8), 0, 0);
        body.addView(date);
        card.addView(body, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        card.setOnClickListener(v -> showTodoEditor(item, null, 0));
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.setMargins(0, 0, 0, dp(10));
        card.setLayoutParams(params);
        return card;
    }

    private void showFolderMenu(View anchor) {
        PopupMenu menu = new PopupMenu(this, anchor);
        menu.getMenu().add("全部课程  ·  " + folderCount(""));
        for (String name : courseNames()) menu.getMenu().add(name + "  ·  " + folderCount(name));
        menu.getMenu().add("其他  ·  " + folderCount("__OTHER__"));
        menu.setOnMenuItemClickListener(item -> {
            String label = item.getTitle().toString();
            if (label.startsWith("全部课程")) selectedFolder = "";
            else if (label.startsWith("其他")) selectedFolder = "__OTHER__";
            else selectedFolder = label.substring(0, label.lastIndexOf("  ·  "));
            showMain(0);
            return true;
        });
        menu.show();
    }

    private void showTodoEditor(TodoItem existing, CourseItem course, long suggestedDue) {
        screen = "todo_editor";
        editingTodo = existing;
        draftImages.clear();
        if (existing != null) draftImages.addAll(existing.imageUris);
        long defaultDue = suggestedDue > 0 ? suggestedDue : tomorrowAtNine();
        final long[] dueAt = {existing == null ? defaultDue : existing.dueAt};

        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setBackgroundColor(BACKGROUND);
        LinearLayout bar = topBar("取消", existing == null ? "新建待办" : "编辑待办", "保存");
        page.addView(bar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(58)));

        ScrollView scroll = new ScrollView(this);
        LinearLayout form = new LinearLayout(this);
        form.setOrientation(LinearLayout.VERTICAL);
        form.setPadding(dp(20), 0, dp(20), dp(28));
        EditText title = input(existing == null ? (course == null ? "" : course.name + "待办") : existing.title, "要做什么？", false);
        EditText note = input(existing == null ? (course == null ? "" : course.teacher.isEmpty() ? "课程：" + course.name : "课程：" + course.name + "\n教师：" + course.teacher) : existing.note, "补充说明（可不填）", true);
        EditText location = input(existing == null ? (course == null ? "" : course.location) : existing.location, "例如：经信 F3 阶", false);
        addLabel(form, "标题"); form.addView(title, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52)));
        addLabel(form, "备注"); form.addView(note);
        addLabel(form, "地点备忘"); form.addView(location, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(50)));

        List<String> courseOptions = new ArrayList<>();
        courseOptions.add("未分类");
        courseOptions.addAll(courseNames());
        Spinner courseSpinner = spinner(courseOptions);
        String initialCourse = existing != null ? existing.courseName : course != null ? course.name : selectedFolder.equals("__OTHER__") ? "" : selectedFolder;
        int initialCourseIndex = courseOptions.indexOf(initialCourse);
        courseSpinner.setSelection(Math.max(0, initialCourseIndex));
        addLabel(form, "课程文件夹"); form.addView(courseSpinner, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(50)));

        List<String> kinds = Arrays.asList("普通待办", "作业", "考试", "测验");
        Spinner kindSpinner = spinner(kinds);
        String initialKind = existing == null ? (course == null && initialCourse.isEmpty() ? TodoItem.GENERAL : TodoItem.HOMEWORK) : existing.taskKind;
        kindSpinner.setSelection(kindIndex(initialKind));
        addLabel(form, "类型"); form.addView(kindSpinner, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(50)));

        addLabel(form, "截止时间");
        LinearLayout dateRow = row();
        Button dateButton = button(formatDay(dueAt[0]), PRIMARY_DARK, 0xFFE8F3EF);
        Button timeButton = button(formatTime(dueAt[0]), PRIMARY_DARK, 0xFFE8F3EF);
        dateButton.setOnClickListener(v -> pickDate(dueAt, dateButton));
        timeButton.setOnClickListener(v -> pickTime(dueAt, timeButton));
        LinearLayout.LayoutParams dateParams = new LinearLayout.LayoutParams(0, dp(48), 1);
        dateParams.setMarginEnd(dp(5));
        dateRow.addView(dateButton, dateParams);
        LinearLayout.LayoutParams timeParams = new LinearLayout.LayoutParams(0, dp(48), 1);
        timeParams.setMarginStart(dp(5));
        dateRow.addView(timeButton, timeParams);
        form.addView(dateRow);

        List<Integer> selectedAdvanceDays = new ArrayList<>();
        if (existing != null) selectedAdvanceDays.addAll(existing.advanceReminderDays);
        selectedAdvanceDays.sort(Integer::compareTo);
        Button advanceButton = button(advanceReminderLabel(selectedAdvanceDays), PRIMARY_DARK, 0xFFE8F3EF);
        advanceButton.setGravity(Gravity.START | Gravity.CENTER_VERTICAL);
        advanceButton.setOnClickListener(v -> showAdvanceReminderDialog(selectedAdvanceDays, advanceButton));
        addLabel(form, "提前提醒（可多选）");
        form.addView(advanceButton, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(50)));

        Switch reminder = new Switch(this);
        reminder.setText("开启系统通知提醒");
        reminder.setTextColor(TEXT);
        reminder.setTextSize(15);
        reminder.setChecked(existing == null || existing.reminderEnabled);
        reminder.setPadding(dp(4), dp(16), dp(4), dp(8));
        form.addView(reminder);

        addLabel(form, "相关图片");
        Button chooseImage = button("添加图片", PRIMARY, 0xFFE8F3EF);
        chooseImage.setOnClickListener(v -> pickImages());
        form.addView(chooseImage, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(46)));
        HorizontalScrollView imageScroll = new HorizontalScrollView(this);
        imageStrip = row();
        imageStrip.setPadding(0, dp(10), 0, 0);
        imageScroll.addView(imageStrip);
        form.addView(imageScroll, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(100)));
        refreshDraftImages();

        if (existing != null) {
            Button delete = button("删除待办", DANGER, 0xFFFCEDEB);
            delete.setOnClickListener(v -> confirmDeleteTodo(existing));
            LinearLayout.LayoutParams deleteParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(48));
            deleteParams.setMargins(0, dp(18), 0, 0);
            form.addView(delete, deleteParams);
        }
        scroll.addView(form);
        page.addView(scroll, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
        setAppContent(page);

        ((Button) bar.getChildAt(0)).setOnClickListener(v -> showMain(0));
        ((Button) bar.getChildAt(2)).setOnClickListener(v -> {
            String cleanTitle = title.getText().toString().trim();
            if (cleanTitle.isEmpty()) { toast("请填写待办标题"); return; }
            TodoItem item = existing == null ? new TodoItem() : existing;
            if (existing == null) {
                item.id = System.currentTimeMillis();
                item.createdAt = item.id;
                todos.add(item);
            } else {
                ReminderScheduler.cancel(this, item.id);
            }
            item.title = cleanTitle;
            item.note = note.getText().toString().trim();
            item.location = location.getText().toString().trim();
            item.dueAt = dueAt[0];
            item.courseName = courseSpinner.getSelectedItemPosition() == 0 ? "" : courseOptions.get(courseSpinner.getSelectedItemPosition());
            item.taskKind = kindFromIndex(kindSpinner.getSelectedItemPosition());
            item.advanceReminderDays.clear();
            item.advanceReminderDays.addAll(selectedAdvanceDays);
            item.reminderEnabled = reminder.isChecked();
            item.imageUris.clear();
            item.imageUris.addAll(draftImages);
            AppStore.saveTodos(this, todos);
            ReminderScheduler.schedule(this, item);
            toast("已保存");
            showMain(0);
        });
    }

    private LinearLayout topBar(String left, String title, String right) {
        LinearLayout bar = row();
        bar.setPadding(dp(8), dp(6), dp(8), dp(6));
        bar.setBackground(bg(SURFACE, 0, BORDER, 1));
        Button back = button(left, MUTED, Color.TRANSPARENT);
        TextView heading = text(title, 18, TEXT, true);
        heading.setGravity(Gravity.CENTER);
        Button action = button(right, PRIMARY, Color.TRANSPARENT);
        action.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        bar.addView(back, new LinearLayout.LayoutParams(dp(80), ViewGroup.LayoutParams.MATCH_PARENT));
        bar.addView(heading, weight(1));
        bar.addView(action, new LinearLayout.LayoutParams(dp(80), ViewGroup.LayoutParams.MATCH_PARENT));
        return bar;
    }

    private void showAdvanceReminderDialog(List<Integer> selectedDays, Button label) {
        boolean[] checked = new boolean[ADVANCE_REMINDER_DAYS.length];
        for (int i = 0; i < ADVANCE_REMINDER_DAYS.length; i++) {
            checked[i] = selectedDays.contains(ADVANCE_REMINDER_DAYS[i]);
        }
        new AlertDialog.Builder(this)
                .setTitle("选择提前提醒")
                .setMultiChoiceItems(ADVANCE_REMINDER_LABELS, checked,
                        (dialog, which, isChecked) -> checked[which] = isChecked)
                .setNegativeButton("取消", null)
                .setNeutralButton("清空", (dialog, which) -> {
                    selectedDays.clear();
                    label.setText(advanceReminderLabel(selectedDays));
                })
                .setPositiveButton("确定", (dialog, which) -> {
                    selectedDays.clear();
                    for (int i = 0; i < ADVANCE_REMINDER_DAYS.length; i++) {
                        if (checked[i]) selectedDays.add(ADVANCE_REMINDER_DAYS[i]);
                    }
                    label.setText(advanceReminderLabel(selectedDays));
                })
                .show();
    }

    private String advanceReminderLabel(List<Integer> days) {
        if (days.isEmpty()) return "不提前（到期时提醒）";
        StringBuilder result = new StringBuilder("提前 ");
        for (int i = 0; i < days.size(); i++) {
            if (i > 0) result.append("、");
            result.append(days.get(i));
        }
        return result.append(" 天（并在到期时提醒）").toString();
    }

    private String reminderMeta(List<Integer> days) {
        if (days.isEmpty()) return "到期提醒";
        StringBuilder result = new StringBuilder("提前");
        for (int i = 0; i < days.size(); i++) {
            if (i > 0) result.append("、");
            result.append(days.get(i));
        }
        return result.append("天 + 到期").toString();
    }

    private Spinner spinner(List<String> values) {
        Spinner spinner = new Spinner(this);
        ArrayAdapter<String> adapter = new ArrayAdapter<>(this, android.R.layout.simple_spinner_dropdown_item, values);
        spinner.setAdapter(adapter);
        spinner.setPadding(dp(10), 0, dp(10), 0);
        spinner.setBackground(bg(SURFACE, 7, BORDER, 1));
        return spinner;
    }

    private void pickDate(long[] value, Button label) {
        Calendar calendar = Calendar.getInstance();
        calendar.setTimeInMillis(value[0]);
        new DatePickerDialog(this, (view, year, month, day) -> {
            Calendar next = Calendar.getInstance();
            next.setTimeInMillis(value[0]);
            next.set(year, month, day);
            value[0] = next.getTimeInMillis();
            label.setText(formatDay(value[0]));
        }, calendar.get(Calendar.YEAR), calendar.get(Calendar.MONTH), calendar.get(Calendar.DAY_OF_MONTH)).show();
    }

    private void pickTime(long[] value, Button label) {
        Calendar calendar = Calendar.getInstance();
        calendar.setTimeInMillis(value[0]);
        new TimePickerDialog(this, (view, hour, minute) -> {
            Calendar next = Calendar.getInstance();
            next.setTimeInMillis(value[0]);
            next.set(Calendar.HOUR_OF_DAY, hour);
            next.set(Calendar.MINUTE, minute);
            next.set(Calendar.SECOND, 0);
            value[0] = next.getTimeInMillis();
            label.setText(formatTime(value[0]));
        }, calendar.get(Calendar.HOUR_OF_DAY), calendar.get(Calendar.MINUTE), true).show();
    }

    private void pickImages() {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.setType("image/*");
        intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        startActivityForResult(intent, PHOTO_REQUEST);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != PHOTO_REQUEST || resultCode != RESULT_OK || data == null) return;
        if (data.getClipData() != null) {
            for (int i = 0; i < data.getClipData().getItemCount(); i++) addImageUri(data.getClipData().getItemAt(i).getUri());
        } else if (data.getData() != null) addImageUri(data.getData());
        refreshDraftImages();
    }

    private void addImageUri(Uri uri) {
        try {
            getContentResolver().takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
        } catch (Exception ignored) {
        }
        String value = uri.toString();
        if (!draftImages.contains(value)) draftImages.add(value);
    }

    private void refreshDraftImages() {
        if (imageStrip == null) return;
        imageStrip.removeAllViews();
        for (String value : new ArrayList<>(draftImages)) {
            ImageView image = new ImageView(this);
            image.setScaleType(ImageView.ScaleType.CENTER_CROP);
            image.setImageURI(Uri.parse(value));
            image.setBackground(bg(0xFFE8ECEA, 7, BORDER, 1));
            image.setContentDescription("待办图片，长按移除");
            image.setOnLongClickListener(v -> {
                draftImages.remove(value);
                refreshDraftImages();
                return true;
            });
            LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(dp(82), dp(82));
            params.setMarginEnd(dp(8));
            imageStrip.addView(image, params);
        }
    }

    private void confirmDeleteTodo(TodoItem item) {
        new AlertDialog.Builder(this).setTitle("删除待办").setMessage("确定删除“" + item.title + "”吗？")
                .setNegativeButton("取消", null).setPositiveButton("删除", (dialog, which) -> {
                    ReminderScheduler.cancel(this, item.id);
                    todos.remove(item);
                    AppStore.saveTodos(this, todos);
                    showMain(0);
                }).show();
    }

    private View coursePage() {
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setBackgroundColor(BACKGROUND);
        LinearLayout header = row();
        header.setPadding(dp(6), dp(5), dp(6), dp(5));
        header.setBackground(bg(SURFACE, 0, BORDER, 1));
        Button previous = button("‹", PRIMARY_DARK, Color.TRANSPARENT);
        previous.setTextSize(24);
        previous.setEnabled(selectedWeek > 1);
        previous.setOnClickListener(v -> changeWeek(-1));
        activePreviousWeekButton = previous;
        header.addView(previous, new LinearLayout.LayoutParams(dp(42), dp(50)));
        LinearLayout weekInfo = new LinearLayout(this);
        weekInfo.setOrientation(LinearLayout.VERTICAL);
        weekInfo.setGravity(Gravity.CENTER);
        TextView weekTitle = text(weekTitleLabel(), 17, TEXT, true);
        weekInfo.addView(weekTitle);
        activeWeekTitle = weekTitle;
        TextView range = text(weekRangeLabel(selectedWeek), 11, MUTED, false);
        range.setGravity(Gravity.CENTER);
        weekInfo.addView(range);
        activeWeekRange = range;
        weekInfo.setOnClickListener(v -> setSelectedWeek(currentWeek()));
        header.addView(weekInfo, new LinearLayout.LayoutParams(0, dp(52), 1));
        Button next = button("›", PRIMARY_DARK, Color.TRANSPARENT);
        next.setTextSize(24);
        next.setEnabled(selectedWeek < 30);
        next.setOnClickListener(v -> changeWeek(1));
        activeNextWeekButton = next;
        header.addView(next, new LinearLayout.LayoutParams(dp(42), dp(50)));
        Button add = button("＋", PRIMARY, 0xFFE2F0EB);
        add.setTextSize(20);
        add.setOnClickListener(v -> showCourseEditor(null));
        LinearLayout.LayoutParams icon = new LinearLayout.LayoutParams(dp(42), dp(42));
        icon.setMargins(dp(2), dp(4), dp(2), dp(4));
        header.addView(add, icon);
        Button more = button("⋯", MUTED, Color.TRANSPARENT);
        more.setTextSize(20);
        more.setOnClickListener(this::showCourseMenu);
        header.addView(more, new LinearLayout.LayoutParams(dp(42), dp(50)));
        page.addView(header, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(62)));

        if (courses.isEmpty()) {
            LinearLayout empty = new LinearLayout(this);
            empty.setOrientation(LinearLayout.VERTICAL);
            empty.setGravity(Gravity.CENTER);
            empty.setPadding(dp(24), dp(20), dp(24), dp(40));
            TextView mark = text("课", 25, PRIMARY, true);
            mark.setGravity(Gravity.CENTER);
            mark.setBackground(bg(0xFFE2F0EB, 16, Color.TRANSPARENT, 0));
            empty.addView(mark, new LinearLayout.LayoutParams(dp(62), dp(62)));
            TextView title = text("还没有课程", 19, TEXT, true);
            title.setGravity(Gravity.CENTER);
            title.setPadding(0, dp(16), 0, dp(6));
            empty.addView(title);
            TextView description = text("从教务系统导入，或手动添加第一门课", 14, MUTED, false);
            description.setGravity(Gravity.CENTER);
            description.setMaxLines(2);
            empty.addView(description);
            LinearLayout actions = row();
            actions.setPadding(0, dp(18), 0, 0);
            Button importButton = button("教务导入", 0xFF315F80, 0xFFE8F0F6);
            Button manual = button("手动添加", Color.WHITE, PRIMARY);
            importButton.setOnClickListener(v -> showImportPage());
            manual.setOnClickListener(v -> showCourseEditor(null));
            LinearLayout.LayoutParams action = new LinearLayout.LayoutParams(0, dp(44), 1);
            action.setMarginEnd(dp(6));
            actions.addView(importButton, action);
            LinearLayout.LayoutParams action2 = new LinearLayout.LayoutParams(0, dp(44), 1);
            action2.setMarginStart(dp(6));
            actions.addView(manual, action2);
            empty.addView(actions, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT));
            page.addView(empty, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
        } else {
            ScrollView scroll = new ScrollView(this);
            ScheduleView schedule = new ScheduleView(this);
            schedule.setData(courses, sectionRanges, semesterStart, selectedWeek);
            activeScheduleView = schedule;
            schedule.setListener(new ScheduleView.Listener() {
                @Override public void onCourseClick(CourseItem course) { showCourseDetail(course); }
                @Override public void onSectionClick(int sectionIndex) { editSectionTime(sectionIndex); }
                @Override public void onWeekSwipe(int direction) { changeWeek(direction); }
            });
            scroll.addView(schedule);
            page.addView(scroll, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
        }
        return page;
    }

    private void changeWeek(int direction) {
        setSelectedWeek(selectedWeek + direction);
    }

    private void setSelectedWeek(int week) {
        int nextWeek = Math.max(1, Math.min(30, week));
        if (nextWeek == selectedWeek) return;
        selectedWeek = nextWeek;
        if (activeScheduleView == null) {
            showMain(1);
            return;
        }
        activeScheduleView.setWeek(selectedWeek);
        if (activeWeekTitle != null) activeWeekTitle.setText(weekTitleLabel());
        if (activeWeekRange != null) activeWeekRange.setText(weekRangeLabel(selectedWeek));
        if (activePreviousWeekButton != null) activePreviousWeekButton.setEnabled(selectedWeek > 1);
        if (activeNextWeekButton != null) activeNextWeekButton.setEnabled(selectedWeek < 30);
    }

    private String weekTitleLabel() {
        return "第" + selectedWeek + "周" + (selectedWeek == currentWeek() ? "  本周" : "");
    }

    private void showCourseMenu(View anchor) {
        PopupMenu menu = new PopupMenu(this, anchor);
        menu.getMenu().add("从吉林大学教务导入");
        menu.getMenu().add("设置学期第一周");
        menu.getMenu().add("调整每节课时间");
        menu.setOnMenuItemClickListener(item -> {
            String title = item.getTitle().toString();
            if (title.startsWith("从吉林")) showImportPage();
            else if (title.startsWith("设置学期")) chooseSemesterStart();
            else chooseSection();
            return true;
        });
        menu.show();
    }

    private void chooseSemesterStart() {
        Calendar calendar = Calendar.getInstance();
        calendar.setTimeInMillis(semesterStart);
        new DatePickerDialog(this, (view, year, month, day) -> {
            Calendar date = Calendar.getInstance();
            date.clear();
            date.set(year, month, day);
            semesterStart = AppStore.startOfWeek(date.getTimeInMillis());
            AppStore.saveSemesterStart(this, semesterStart);
            selectedWeek = currentWeek();
            showMain(1);
        }, calendar.get(Calendar.YEAR), calendar.get(Calendar.MONTH), calendar.get(Calendar.DAY_OF_MONTH)).show();
    }

    private void chooseSection() {
        String[] labels = new String[sectionRanges.length];
        for (int i = 0; i < labels.length; i++) labels[i] = "第" + (i + 1) + "节   " + sectionRanges[i];
        new AlertDialog.Builder(this).setTitle("调整上课时间").setItems(labels, (dialog, which) -> editSectionTime(which))
                .setNegativeButton("取消", null).show();
    }

    private void editSectionTime(int index) {
        String[] parts = sectionRanges[index].split("-");
        int[] start = parseClock(parts[0]);
        int[] end = parseClock(parts.length > 1 ? parts[1] : parts[0]);
        new TimePickerDialog(this, (view, hour, minute) -> {
            int startHour = hour;
            int startMinute = minute;
            new TimePickerDialog(this, (endView, endHour, endMinute) -> {
                sectionRanges[index] = two(startHour) + ":" + two(startMinute) + "-" + two(endHour) + ":" + two(endMinute);
                AppStore.saveSectionRanges(this, sectionRanges);
                showMain(1);
            }, end[0], end[1], true).show();
        }, start[0], start[1], true).show();
    }

    private void showCourseEditor(CourseItem existing) {
        screen = "course_editor";
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setBackgroundColor(BACKGROUND);
        LinearLayout bar = topBar("取消", existing == null ? "添加课程" : "编辑课程", "保存");
        page.addView(bar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(58)));
        ScrollView scroll = new ScrollView(this);
        LinearLayout form = new LinearLayout(this);
        form.setOrientation(LinearLayout.VERTICAL);
        form.setPadding(dp(20), 0, dp(20), dp(30));
        EditText name = input(existing == null ? "" : existing.name, "例如：高等数学", false);
        EditText teacher = input(existing == null ? "" : existing.teacher, "可不填", false);
        EditText location = input(existing == null ? "" : existing.location, "例如：经信 F3 阶", false);
        addLabel(form, "课程名称"); form.addView(name, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52)));
        addLabel(form, "授课教师"); form.addView(teacher, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(50)));
        addLabel(form, "上课地点"); form.addView(location, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(50)));
        Spinner weekday = spinner(Arrays.asList("周一", "周二", "周三", "周四", "周五", "周六", "周日"));
        weekday.setSelection(existing == null ? 0 : existing.weekday - 1);
        addLabel(form, "星期"); form.addView(weekday, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(50)));

        NumberPicker startSection = numberPicker(1, 12, existing == null ? 1 : existing.startSection);
        NumberPicker endSection = numberPicker(1, 12, existing == null ? 2 : existing.endSection);
        addLabel(form, "节次"); form.addView(twoPickers("开始", startSection, "结束", endSection), new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(115)));
        NumberPicker startWeek = numberPicker(1, 30, existing == null ? 1 : existing.startWeek);
        NumberPicker endWeek = numberPicker(1, 30, existing == null ? 20 : existing.endWeek);
        addLabel(form, "上课周次"); form.addView(twoPickers("开始周", startWeek, "结束周", endWeek), new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(115)));
        Spinner parity = spinner(Arrays.asList("每周", "仅单周", "仅双周"));
        parity.setSelection(existing == null || CourseItem.ALL.equals(existing.parity) ? 0 : CourseItem.ODD.equals(existing.parity) ? 1 : 2);
        addLabel(form, "单双周"); form.addView(parity, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(50)));
        scroll.addView(form);
        page.addView(scroll, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
        setAppContent(page);
        ((Button) bar.getChildAt(0)).setOnClickListener(v -> showMain(1));
        ((Button) bar.getChildAt(2)).setOnClickListener(v -> {
            String cleanName = name.getText().toString().trim();
            if (cleanName.isEmpty()) { toast("请填写课程名称"); return; }
            CourseItem item = existing == null ? new CourseItem() : existing;
            if (existing == null) { item.id = System.currentTimeMillis(); courses.add(item); }
            item.name = cleanName;
            item.teacher = teacher.getText().toString().trim();
            item.location = location.getText().toString().trim();
            item.weekday = weekday.getSelectedItemPosition() + 1;
            item.startSection = Math.min(startSection.getValue(), endSection.getValue());
            item.endSection = Math.max(startSection.getValue(), endSection.getValue());
            item.startWeek = Math.min(startWeek.getValue(), endWeek.getValue());
            item.endWeek = Math.max(startWeek.getValue(), endWeek.getValue());
            item.parity = parity.getSelectedItemPosition() == 1 ? CourseItem.ODD : parity.getSelectedItemPosition() == 2 ? CourseItem.EVEN : CourseItem.ALL;
            AppStore.saveCourses(this, courses);
            showMain(1);
        });
    }

    private NumberPicker numberPicker(int min, int max, int value) {
        NumberPicker picker = new NumberPicker(this);
        picker.setMinValue(min);
        picker.setMaxValue(max);
        picker.setValue(value);
        picker.setWrapSelectorWheel(false);
        picker.setBackground(bg(SURFACE, 7, BORDER, 1));
        return picker;
    }

    private View twoPickers(String firstLabel, NumberPicker first, String secondLabel, NumberPicker second) {
        LinearLayout container = row();
        container.addView(labeledPicker(firstLabel, first), new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1));
        View gap = new View(this);
        container.addView(gap, new LinearLayout.LayoutParams(dp(10), 1));
        container.addView(labeledPicker(secondLabel, second), new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1));
        return container;
    }

    private View labeledPicker(String label, NumberPicker picker) {
        LinearLayout column = new LinearLayout(this);
        column.setOrientation(LinearLayout.VERTICAL);
        TextView title = text(label, 12, MUTED, false);
        title.setGravity(Gravity.CENTER);
        column.addView(title, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(25)));
        column.addView(picker, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
        return column;
    }

    private void showCourseDetail(CourseItem course) {
        screen = "course_detail";
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setBackgroundColor(BACKGROUND);
        LinearLayout bar = topBar("‹", "课程详情", "编辑");
        ((Button) bar.getChildAt(0)).setOnClickListener(v -> showMain(1));
        ((Button) bar.getChildAt(2)).setOnClickListener(v -> showCourseEditor(course));
        page.addView(bar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(58)));
        ScrollView scroll = new ScrollView(this);
        LinearLayout body = new LinearLayout(this);
        body.setOrientation(LinearLayout.VERTICAL);
        body.setPadding(dp(20), dp(24), dp(20), dp(24));
        body.addView(text(course.name, 26, TEXT, true));
        detailRow(body, "教师", course.teacher.isEmpty() ? "未填写" : course.teacher);
        detailRow(body, "地点", course.location.isEmpty() ? "未填写" : course.location);
        detailRow(body, "时间", "周" + "一二三四五六日".charAt(course.weekday - 1) + " · 第" + course.startSection + "-" + course.endSection + "节");
        detailRow(body, "周次", "第" + course.startWeek + "-" + course.endWeek + "周 · " + parityLabel(course.parity));
        Button tasks = button("查看课程待办  " + courseTodoCount(course.name), PRIMARY, 0xFFE4F0EC);
        tasks.setOnClickListener(v -> { selectedFolder = course.name; todoTab = 0; showMain(0); });
        LinearLayout.LayoutParams action = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(48));
        action.setMargins(0, dp(30), 0, 0);
        body.addView(tasks, action);
        Button addTodo = button("添加课程待办", Color.WHITE, PRIMARY);
        addTodo.setOnClickListener(v -> showTodoEditor(null, course, nextOccurrence(course)));
        LinearLayout.LayoutParams action2 = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52));
        action2.setMargins(0, dp(10), 0, 0);
        body.addView(addTodo, action2);
        Button delete = button("删除课程", DANGER, 0xFFFCEDEB);
        delete.setOnClickListener(v -> new AlertDialog.Builder(this).setTitle("删除课程")
                .setMessage("确定删除“" + course.name + "”吗？").setNegativeButton("取消", null)
                .setPositiveButton("删除", (dialog, which) -> { courses.remove(course); AppStore.saveCourses(this, courses); showMain(1); }).show());
        LinearLayout.LayoutParams deleteParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(48));
        deleteParams.setMargins(0, dp(10), 0, 0);
        body.addView(delete, deleteParams);
        scroll.addView(body);
        page.addView(scroll, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
        setAppContent(page);
    }

    private void detailRow(LinearLayout parent, String label, String value) {
        LinearLayout row = row();
        row.setPadding(0, dp(18), 0, 0);
        TextView key = text(label, 14, MUTED, false);
        TextView content = text(value, 16, TEXT, false);
        row.addView(key, new LinearLayout.LayoutParams(dp(72), ViewGroup.LayoutParams.WRAP_CONTENT));
        row.addView(content, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        parent.addView(row);
    }

    @SuppressLint({"SetJavaScriptEnabled", "AddJavascriptInterface"})
    private void showImportPage() {
        screen = "import";
        capturedResponses.clear();
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setBackgroundColor(BACKGROUND);
        LinearLayout bar = topBar("‹", "吉林大学教务导入", "清除登录");
        page.addView(bar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(58)));
        TextView status = text("请在学校页面登录，然后打开“我的课表”", 12, MUTED, false);
        status.setPadding(dp(14), dp(8), dp(14), dp(8));
        status.setBackgroundColor(0xFFEDF3F0);
        page.addView(status, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(42)));
        LinearLayout controls = row();
        controls.setPadding(dp(10), dp(7), dp(10), dp(7));
        Button vpn = button("VPN入口", 0xFF805C34, 0xFFF7EED8);
        Button login = button("登录首页", PRIMARY, 0xFFE8F3EF);
        Button scheduleButton = button("我的课表", Color.WHITE, PRIMARY);
        LinearLayout.LayoutParams control = new LinearLayout.LayoutParams(0, dp(40), 1);
        control.setMarginEnd(dp(4)); controls.addView(vpn, control);
        LinearLayout.LayoutParams control2 = new LinearLayout.LayoutParams(0, dp(40), 1);
        control2.setMarginStart(dp(4)); control2.setMarginEnd(dp(4)); controls.addView(login, control2);
        LinearLayout.LayoutParams control3 = new LinearLayout.LayoutParams(0, dp(40), 1);
        control3.setMarginStart(dp(4)); controls.addView(scheduleButton, control3);
        page.addView(controls);
        WebView web = new WebView(this);
        WebSettings settings = web.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE);
        web.addJavascriptInterface(new CaptureBridge(), "ClassCueBridge");
        web.setWebChromeClient(new WebChromeClient());
        web.setWebViewClient(new WebViewClient() {
            @Override public void onPageFinished(WebView view, String url) {
                injectCapture(view);
                status.setText("已打开学校页面。进入“我的课表”并等待课程显示。" );
            }
        });
        page.addView(web, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
        Button importButton = button("导入已显示的课表", Color.WHITE, PRIMARY);
        LinearLayout.LayoutParams importParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52));
        importParams.setMargins(dp(10), dp(8), dp(10), dp(10));
        page.addView(importButton, importParams);
        setAppContent(page);
        web.loadUrl(JLU_LOGIN_URL);
        ((Button) bar.getChildAt(0)).setOnClickListener(v -> { web.destroy(); showMain(1); });
        ((Button) bar.getChildAt(2)).setOnClickListener(v -> {
            android.webkit.CookieManager.getInstance().removeAllCookies(null);
            android.webkit.CookieManager.getInstance().flush();
            web.clearHistory(); web.clearCache(true); web.loadUrl(JLU_LOGIN_URL);
            status.setText("登录信息已清除，请重新登录");
        });
        vpn.setOnClickListener(v -> {
            web.loadUrl(JLU_VPN_URL);
            status.setText("请登录吉林大学 VPN；手机已连接系统 VPN 时也会自动使用");
        });
        login.setOnClickListener(v -> {
            web.loadUrl(JLU_LOGIN_URL);
            status.setText("正在通过当前网络或 VPN 打开教务首页");
        });
        scheduleButton.setOnClickListener(v -> {
            capturedResponses.clear();
            web.loadUrl(JLU_SCHEDULE_URL);
            status.setText("正在打开我的课表，请等待课程显示");
        });
        importButton.setOnClickListener(v -> importCaptured(status));
    }

    private final class CaptureBridge {
        @JavascriptInterface public void save(String url, String payload) {
            if (payload != null && payload.contains("\"datas\"") && payload.contains("\"rows\"")) {
                synchronized (capturedResponses) {
                    capturedResponses.add(payload);
                    while (capturedResponses.size() > 8) capturedResponses.remove(0);
                }
            }
        }
    }

    private void injectCapture(WebView web) {
        String script = "(function(){if(window.__classCueHooked)return;window.__classCueHooked=true;"
                + "function ok(u){u=String(u||'').toLowerCase();return u.indexOf('cxxszhxqkb.do')>=0||u.indexOf('modules/xskcb')>=0;}"
                + "function save(u,t){try{if(ok(u)&&t&&t.indexOf('\\\"datas\\\"')>=0)ClassCueBridge.save(String(u),String(t));}catch(e){}}"
                + "var o=XMLHttpRequest.prototype.open,s=XMLHttpRequest.prototype.send;"
                + "XMLHttpRequest.prototype.open=function(m,u){this.__ccu=u||'';return o.apply(this,arguments);};"
                + "XMLHttpRequest.prototype.send=function(){this.addEventListener('load',function(){save(this.__ccu,this.responseText||'');});return s.apply(this,arguments);};"
                + "if(window.fetch){var f=window.fetch;window.fetch=function(i,n){var u=typeof i==='string'?i:((i&&i.url)||'');return f(i,n).then(function(r){if(ok(u)){try{r.clone().text().then(function(t){save(u,t);});}catch(e){}}return r;});};}})();";
        web.evaluateJavascript(script, null);
    }

    private void importCaptured(TextView status) {
        JluScheduleParser.Result best = new JluScheduleParser.Result();
        synchronized (capturedResponses) {
            for (String raw : capturedResponses) {
                JluScheduleParser.Result result = JluScheduleParser.parse(raw);
                if (result.courses.size() > best.courses.size()) best = result;
            }
        }
        if (best.courses.isEmpty()) {
            status.setText("还未读取到课表。请打开“我的课表”，看到课程后再点击导入。" );
            return;
        }
        JluScheduleParser.Result result = best;
        new AlertDialog.Builder(this).setTitle("导入课程表")
                .setMessage("已识别 " + result.courses.size() + " 条课程安排" + (result.semesterLabel.isEmpty() ? "" : "\n学期：" + result.semesterLabel))
                .setNegativeButton("追加", (dialog, which) -> finishImport(result, false))
                .setPositiveButton("覆盖当前课表", (dialog, which) -> finishImport(result, true)).show();
    }

    private void finishImport(JluScheduleParser.Result result, boolean replace) {
        if (replace) courses.clear();
        courses.addAll(result.courses);
        AppStore.saveCourses(this, courses);
        if (result.semesterStartAt > 0) {
            semesterStart = result.semesterStartAt;
            AppStore.saveSemesterStart(this, semesterStart);
        }
        selectedWeek = currentWeek();
        toast("课表已导入");
        showMain(1);
    }

    @Override
    public void onBackPressed() {
        if ("main".equals(screen)) {
            if (mainTab == 1) showMain(0); else super.onBackPressed();
        } else if ("todo_editor".equals(screen)) {
            showMain(0);
        } else {
            showMain(1);
        }
    }

    private List<TodoItem> visibleTodos() {
        List<TodoItem> result = new ArrayList<>();
        for (TodoItem item : todos) {
            if ((todoTab == 0) == item.completed) continue;
            if (selectedFolder.isEmpty()
                    || ("__OTHER__".equals(selectedFolder) && item.courseName.isEmpty())
                    || selectedFolder.equals(item.courseName)) result.add(item);
        }
        result.sort(todoTab == 0 ? Comparator.comparingLong(item -> item.dueAt)
                : (left, right) -> Long.compare(right.createdAt, left.createdAt));
        return result;
    }

    private int pendingCount() {
        int count = 0;
        for (TodoItem item : todos) if (!item.completed) count++;
        return count;
    }

    private int folderCount(String folder) {
        int count = 0;
        for (TodoItem item : todos) {
            if ((todoTab == 0) == item.completed) continue;
            if (folder.isEmpty() || ("__OTHER__".equals(folder) && item.courseName.isEmpty()) || folder.equals(item.courseName)) count++;
        }
        return count;
    }

    private List<String> courseNames() {
        Set<String> names = new LinkedHashSet<>();
        for (CourseItem course : courses) if (!course.name.trim().isEmpty()) names.add(course.name.trim());
        return new ArrayList<>(names);
    }

    private String folderLabel() {
        return selectedFolder.isEmpty() ? "全部课程" : "__OTHER__".equals(selectedFolder) ? "其他" : selectedFolder;
    }

    private int courseTodoCount(String name) {
        int count = 0;
        for (TodoItem item : todos) if (!item.completed && name.equals(item.courseName)) count++;
        return count;
    }

    private int currentWeek() {
        long difference = AppStore.startOfWeek(System.currentTimeMillis()) - semesterStart;
        return Math.max(1, Math.min(30, (int) (difference / (7L * 24L * 60L * 60L * 1000L)) + 1));
    }

    private long nextOccurrence(CourseItem course) {
        long now = System.currentTimeMillis();
        for (int week = Math.max(1, currentWeek()); week <= 30; week++) {
            if (!course.activeInWeek(week)) continue;
            long day = semesterStart + ((week - 1L) * 7L + course.weekday - 1L) * 24L * 60L * 60L * 1000L;
            int[] clock = parseClock(sectionRanges[Math.max(0, Math.min(sectionRanges.length - 1, course.startSection - 1))].split("-")[0]);
            Calendar calendar = Calendar.getInstance();
            calendar.setTimeInMillis(day);
            calendar.set(Calendar.HOUR_OF_DAY, clock[0]);
            calendar.set(Calendar.MINUTE, clock[1]);
            if (calendar.getTimeInMillis() > now) return calendar.getTimeInMillis();
        }
        return tomorrowAtNine();
    }

    private String weekRangeLabel(int week) {
        long start = semesterStart + (week - 1L) * 7L * 24L * 60L * 60L * 1000L;
        SimpleDateFormat format = new SimpleDateFormat("M月d日", Locale.CHINA);
        return format.format(new Date(start)) + " - " + format.format(new Date(start + 6L * 24L * 60L * 60L * 1000L));
    }

    private String todayLabel() {
        return new SimpleDateFormat("M月d日  EEEE", Locale.CHINA).format(new Date());
    }

    private String formatDate(long timestamp) {
        return new SimpleDateFormat("M月d日 HH:mm", Locale.CHINA).format(new Date(timestamp));
    }

    private String formatDay(long timestamp) {
        return new SimpleDateFormat("yyyy年M月d日", Locale.CHINA).format(new Date(timestamp));
    }

    private String formatTime(long timestamp) {
        return new SimpleDateFormat("HH:mm", Locale.CHINA).format(new Date(timestamp));
    }

    private long tomorrowAtNine() {
        Calendar calendar = Calendar.getInstance();
        calendar.add(Calendar.DAY_OF_MONTH, 1);
        calendar.set(Calendar.HOUR_OF_DAY, 9);
        calendar.set(Calendar.MINUTE, 0);
        calendar.set(Calendar.SECOND, 0);
        calendar.set(Calendar.MILLISECOND, 0);
        return calendar.getTimeInMillis();
    }

    private String kindLabel(String kind) {
        if (TodoItem.HOMEWORK.equals(kind)) return "作业";
        if (TodoItem.EXAM.equals(kind)) return "考试";
        if (TodoItem.QUIZ.equals(kind)) return "测验";
        return "待办";
    }

    private int kindColor(String kind) {
        if (TodoItem.HOMEWORK.equals(kind)) return 0xFF315F80;
        if (TodoItem.EXAM.equals(kind)) return 0xFFB64B46;
        if (TodoItem.QUIZ.equals(kind)) return 0xFF805C34;
        return PRIMARY;
    }

    private int kindIndex(String kind) {
        if (TodoItem.HOMEWORK.equals(kind)) return 1;
        if (TodoItem.EXAM.equals(kind)) return 2;
        if (TodoItem.QUIZ.equals(kind)) return 3;
        return 0;
    }

    private String kindFromIndex(int index) {
        return index == 1 ? TodoItem.HOMEWORK : index == 2 ? TodoItem.EXAM : index == 3 ? TodoItem.QUIZ : TodoItem.GENERAL;
    }

    private String parityLabel(String parity) {
        return CourseItem.ODD.equals(parity) ? "仅单周" : CourseItem.EVEN.equals(parity) ? "仅双周" : "每周";
    }

    private int[] parseClock(String value) {
        try {
            String[] parts = value.split(":");
            return new int[]{Integer.parseInt(parts[0]), Integer.parseInt(parts[1])};
        } catch (Exception ignored) {
            return new int[]{8, 0};
        }
    }

    private String two(int value) {
        return value < 10 ? "0" + value : String.valueOf(value);
    }

    private void toast(String value) {
        Toast.makeText(this, value, Toast.LENGTH_SHORT).show();
    }
}
