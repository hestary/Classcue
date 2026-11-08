package com.classcue.android;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.util.AttributeSet;
import android.view.MotionEvent;
import android.view.View;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public final class ScheduleView extends View {
    public interface Listener {
        void onCourseClick(CourseItem course);
        void onSectionClick(int sectionIndex);
        void onWeekSwipe(int direction);
    }

    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final List<CourseItem> courses = new ArrayList<>();
    private String[] ranges = AppStore.DEFAULT_RANGES.clone();
    private long semesterStart = AppStore.startOfWeek(System.currentTimeMillis());
    private int week = 1;
    private Listener listener;
    private float downX;
    private float downY;
    private final float density;
    private final float scaledDensity;

    private static final int[] FILLS = {
            0xFFE0F0EA, 0xFFE4EDF7, 0xFFFAE9DB, 0xFFF0E7F2,
            0xFFF7E5E8, 0xFFEBF0DD, 0xFFF7EED8, 0xFFE3EFF0
    };
    private static final int[] ACCENTS = {
            0xFF26745C, 0xFF416F9B, 0xFFB66735, 0xFF805C8A,
            0xFFAD5865, 0xFF6F8247, 0xFF9B782F, 0xFF4B787D
    };
    private static final String[] DAYS = {"周一", "周二", "周三", "周四", "周五", "周六", "周日"};

    public ScheduleView(Context context) {
        this(context, null);
    }

    public ScheduleView(Context context, AttributeSet attrs) {
        super(context, attrs);
        density = getResources().getDisplayMetrics().density;
        scaledDensity = getResources().getDisplayMetrics().scaledDensity;
        setBackgroundColor(Color.WHITE);
        setFocusable(true);
        setContentDescription("课程表，左右滑动切换周");
    }

    public void setData(List<CourseItem> nextCourses, String[] nextRanges, long nextSemesterStart, int nextWeek) {
        courses.clear();
        courses.addAll(nextCourses);
        ranges = nextRanges.clone();
        semesterStart = nextSemesterStart;
        week = nextWeek;
        requestLayout();
        invalidate();
    }

    public void setListener(Listener listener) {
        this.listener = listener;
    }

    public void setWeek(int nextWeek) {
        if (week == nextWeek) return;
        week = nextWeek;
        invalidate();
    }

    private float dp(float value) {
        return value * density;
    }

    private float sp(float value) {
        return value * scaledDensity;
    }

    private float headerHeight() { return dp(58); }
    private float rowHeight() { return dp(72); }
    private float leftWidth() { return dp(52); }

    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        int width = MeasureSpec.getSize(widthMeasureSpec);
        int height = Math.round(headerHeight() + rowHeight() * ranges.length);
        setMeasuredDimension(resolveSize(width, widthMeasureSpec), height);
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        float left = leftWidth();
        float header = headerHeight();
        float row = rowHeight();
        float dayWidth = (getWidth() - left) / 7f;
        long weekStart = semesterStart + (week - 1L) * 7L * 24L * 60L * 60L * 1000L;
        long todayStart = dayStart(System.currentTimeMillis());

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(0xFFF2F5F3);
        canvas.drawRect(0, 0, left, getHeight(), paint);
        paint.setTextAlign(Paint.Align.CENTER);
        paint.setColor(0xFF17201D);
        paint.setFakeBoldText(true);
        paint.setTextSize(sp(11));
        Calendar first = Calendar.getInstance();
        first.setTimeInMillis(weekStart);
        canvas.drawText((first.get(Calendar.MONTH) + 1) + "月", left / 2, dp(23), paint);
        paint.setFakeBoldText(false);
        paint.setColor(0xFF6B7772);
        paint.setTextSize(sp(8.5f));
        canvas.drawText(String.valueOf(first.get(Calendar.YEAR)), left / 2, dp(41), paint);

        for (int day = 0; day < 7; day++) {
            float x = left + day * dayWidth;
            long dateAt = weekStart + day * 24L * 60L * 60L * 1000L;
            boolean today = dayStart(dateAt) == todayStart;
            paint.setColor(today ? 0xFF124C3E : (day >= 5 ? 0xFFF6F1EB : 0xFFF8FAF9));
            canvas.drawRect(x, 0, x + dayWidth, header, paint);
            paint.setTextAlign(Paint.Align.CENTER);
            paint.setFakeBoldText(true);
            paint.setTextSize(sp(12));
            paint.setColor(today ? Color.WHITE : (day >= 5 ? 0xFF8B6547 : 0xFF17201D));
            canvas.drawText(DAYS[day], x + dayWidth / 2, dp(23), paint);
            paint.setFakeBoldText(false);
            paint.setTextSize(sp(10));
            paint.setColor(today ? 0xFFD9EEE7 : 0xFF6B7772);
            Calendar date = Calendar.getInstance();
            date.setTimeInMillis(dateAt);
            canvas.drawText(date.get(Calendar.DAY_OF_MONTH) + "日", x + dayWidth / 2, dp(43), paint);

            paint.setColor(today ? 0xFFF7FBF9 : (day >= 5 ? 0xFFFCFAF7 : Color.WHITE));
            canvas.drawRect(x, header, x + dayWidth, getHeight(), paint);
        }

        paint.setTextAlign(Paint.Align.CENTER);
        for (int i = 0; i < ranges.length; i++) {
            float top = header + i * row;
            paint.setColor(i % 2 == 0 ? 0xFFF4F7F5 : 0xFFEEF3F1);
            canvas.drawRect(0, top, left, top + row, paint);
            paint.setColor(0xFF17201D);
            paint.setFakeBoldText(true);
            paint.setTextSize(sp(12.5f));
            canvas.drawText(String.valueOf(i + 1), left / 2, top + dp(25), paint);
            paint.setFakeBoldText(false);
            paint.setColor(0xFF176B54);
            paint.setTextSize(sp(9.5f));
            String start = ranges[i].contains("-") ? ranges[i].substring(0, ranges[i].indexOf('-')) : ranges[i];
            canvas.drawText(start, left / 2, top + dp(47), paint);
        }

        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(dp(0.7f));
        paint.setColor(0xFFDDE5E1);
        canvas.drawLine(0, header, getWidth(), header, paint);
        canvas.drawLine(left, 0, left, getHeight(), paint);
        for (int i = 0; i <= ranges.length; i++) {
            float y = header + i * row;
            canvas.drawLine(0, y, getWidth(), y, paint);
        }
        for (int day = 0; day <= 7; day++) {
            float x = left + day * dayWidth;
            canvas.drawLine(x, 0, x, getHeight(), paint);
        }

        paint.setStyle(Paint.Style.FILL);
        for (CourseItem course : courses) {
            if (!course.activeInWeek(week) || course.weekday < 1 || course.weekday > 7) continue;
            int color = (course.name.hashCode() & 0x7fffffff) % FILLS.length;
            float cardLeft = left + (course.weekday - 1) * dayWidth + dp(1.5f);
            float cardTop = header + (course.startSection - 1) * row + dp(1.5f);
            float cardRight = cardLeft + dayWidth - dp(3);
            float cardBottom = header + course.endSection * row - dp(1.5f);
            RectF rect = new RectF(cardLeft, cardTop, cardRight, cardBottom);
            paint.setColor(FILLS[color]);
            canvas.drawRoundRect(rect, dp(4), dp(4), paint);
            paint.setColor(ACCENTS[color]);
            canvas.drawRoundRect(new RectF(cardLeft, cardTop, cardLeft + dp(3), cardBottom), dp(3), dp(3), paint);
            paint.setTextAlign(Paint.Align.LEFT);
            paint.setFakeBoldText(true);
            paint.setTextSize(sp(11));
            float textLeft = cardLeft + dp(6);
            float textWidth = dayWidth - dp(11);
            float nameLineHeight = sp(13);
            float cursor = cardTop + dp(5) - paint.ascent();
            int duration = Math.max(1, course.endSection - course.startSection + 1);
            int nameLines = drawWrapped(canvas, course.name, textLeft, cursor, textWidth,
                    duration >= 2 ? 3 : 1, nameLineHeight, ACCENTS[color]);
            cursor += nameLines * nameLineHeight + dp(2);
            paint.setFakeBoldText(false);
            if (!course.location.isEmpty()) {
                drawFullLocation(canvas, course.location, textLeft, cursor, textWidth,
                        cardBottom - dp(4), 0xFF45534E);
            }
        }
        paint.setFakeBoldText(false);
    }

    private int drawWrapped(Canvas canvas, String text, float x, float y, float maxWidth, int maxLines,
                            float lineHeight, int color) {
        paint.setColor(color);
        String remaining = text == null ? "" : text;
        int lines = 0;
        for (int line = 0; line < maxLines && !remaining.isEmpty(); line++) {
            int count = paint.breakText(remaining, true, maxWidth, null);
            if (count <= 0) break;
            String part = remaining.substring(0, count);
            remaining = remaining.substring(count);
            if (line == maxLines - 1 && !remaining.isEmpty() && part.length() > 1) {
                part = part.substring(0, part.length() - 1) + "…";
            }
            canvas.drawText(part, x, y + line * lineHeight, paint);
            lines++;
        }
        return lines;
    }

    private void drawFullLocation(Canvas canvas, String location, float x, float firstBaseline,
                                  float maxWidth, float bottom, int color) {
        float textSize = 9.5f;
        int lineCount;
        float lineHeight;
        while (true) {
            paint.setTextSize(sp(textSize));
            lineHeight = sp(textSize + 1.5f);
            lineCount = wrappedLineCount(location, maxWidth);
            float lastBottom = firstBaseline + Math.max(0, lineCount - 1) * lineHeight + paint.descent();
            if (lastBottom <= bottom || textSize <= 6.5f) break;
            textSize -= 0.5f;
        }
        drawWrapped(canvas, location, x, firstBaseline, maxWidth, lineCount, lineHeight, color);
    }

    private int wrappedLineCount(String text, float maxWidth) {
        String remaining = text == null ? "" : text;
        int lines = 0;
        while (!remaining.isEmpty()) {
            int count = paint.breakText(remaining, true, maxWidth, null);
            if (count <= 0) break;
            remaining = remaining.substring(count);
            lines++;
        }
        return Math.max(1, lines);
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        if (event.getAction() == MotionEvent.ACTION_DOWN) {
            downX = event.getX();
            downY = event.getY();
            return true;
        }
        if (event.getAction() == MotionEvent.ACTION_UP) {
            float dx = event.getX() - downX;
            float dy = event.getY() - downY;
            if (Math.abs(dx) > dp(55) && Math.abs(dx) > Math.abs(dy) * 1.4f) {
                if (listener != null) listener.onWeekSwipe(dx < 0 ? 1 : -1);
                return true;
            }
            if (Math.abs(dx) < dp(12) && Math.abs(dy) < dp(12)) handleTap(event.getX(), event.getY());
            performClick();
            return true;
        }
        return true;
    }

    @Override
    public boolean performClick() {
        super.performClick();
        return true;
    }

    private void handleTap(float x, float y) {
        float left = leftWidth();
        float header = headerHeight();
        float row = rowHeight();
        float dayWidth = (getWidth() - left) / 7f;
        if (x < left && y >= header) {
            int section = (int) ((y - header) / row);
            if (section >= 0 && section < ranges.length && listener != null) listener.onSectionClick(section);
            return;
        }
        if (x < left || y < header) return;
        int weekday = Math.min(7, Math.max(1, (int) ((x - left) / dayWidth) + 1));
        int section = Math.min(ranges.length, Math.max(1, (int) ((y - header) / row) + 1));
        for (int i = courses.size() - 1; i >= 0; i--) {
            CourseItem course = courses.get(i);
            if (course.weekday == weekday && course.activeInWeek(week)
                    && section >= course.startSection && section <= course.endSection) {
                if (listener != null) listener.onCourseClick(course);
                return;
            }
        }
    }

    private long dayStart(long timestamp) {
        Calendar calendar = Calendar.getInstance();
        calendar.setTimeInMillis(timestamp);
        calendar.set(Calendar.HOUR_OF_DAY, 0);
        calendar.set(Calendar.MINUTE, 0);
        calendar.set(Calendar.SECOND, 0);
        calendar.set(Calendar.MILLISECOND, 0);
        return calendar.getTimeInMillis();
    }
}
