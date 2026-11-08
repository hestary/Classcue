package com.classcue.android;

import java.util.List;

public final class JluScheduleParserSplitTest {
    public static void main(String[] args) {
        String arranged = "第1-14周 星期一 第1节-第2节 经信F3阶，"
                + "第15、16周 星期一 第1节-第2节 线上教学";
        List<String> segments = JluScheduleParser.splitSegments(arranged);
        if (segments.size() != 2) {
            throw new AssertionError("Expected 2 segments, got " + segments);
        }
        if (!segments.get(0).startsWith("第1-14周") || !segments.get(0).endsWith("经信F3阶")) {
            throw new AssertionError("Incorrect classroom segment: " + segments.get(0));
        }
        if (!segments.get(1).startsWith("第15、16周") || !segments.get(1).endsWith("线上教学")) {
            throw new AssertionError("Incorrect online segment: " + segments.get(1));
        }
        System.out.println("JLU schedule segment test passed: " + segments);
    }
}
