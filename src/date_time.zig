const std = @import("std");
const assert = std.debug.assert;
const ctime = @cImport(@cInclude("time.h"));
const lowerString = std.ascii.lowerString;
const eql = std.mem.eql;

pub const DateTimeError = error{WeekdayParseError};

const weekdayNames = [_][]const u8{ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" };
const weekdayLongNames = [_][]const u8{ "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" };

pub const Weekday = enum {
    Sunday,
    Monday,
    Tuesday,
    Wednesday,
    Thursday,
    Friday,
    Saturday,

    pub fn name(weekday: Weekday) []const u8 {
        return weekdayNames[@intFromEnum(weekday)];
    }

    pub fn longName(weekday: Weekday) []const u8 {
        return weekdayLongNames[@intFromEnum(weekday)];
    }

    pub fn fromInt(weekInt: i32) Weekday {
        return @enumFromInt(weekInt);
    }

    pub fn parse(input: []const u8) DateTimeError!Weekday {
        var bufOut: [20]u8 = undefined;
        var bufw: [20]u8 = undefined;

        const lcase_input = lowerString(&bufOut, input);
        for (weekdayNames, weekdayLongNames, 0..) |w, wl, i| {
            if (eql(u8, lcase_input, lowerString(&bufw, w)) or
                eql(u8, lcase_input, lowerString(&bufw, wl)))
            {
                return fromInt(@intCast(i));
            }
        }
        return error.WeekdayParseError;
    }
};

pub const DateTime = struct {
    year: i32,
    month: i32,
    day: i32,
    hour: i32,
    minute: i32,
    second: i32,
    millisecond: i64 = 0,
    weekday: Weekday,
    isDST: bool,
    _lt: [*c]ctime.struct_tm,
    _time_ms: i64,

    pub fn now() DateTime {
        const time_ms = std.time.milliTimestamp(); // ctime.time(null);
        return fromTimestamp(time_ms);
    }

    pub fn fromTimestamp(time_ms: i64) DateTime {
        const time_s = @divTrunc(time_ms, 1000);
        const lt = ctime.localtime(&time_s);
        return DateTime{
            .year = lt.*.tm_year + 1900,
            .month = lt.*.tm_mon + 1,
            .day = lt.*.tm_mday,
            .hour = lt.*.tm_hour,
            .minute = lt.*.tm_min,
            .second = lt.*.tm_sec,
            .weekday = Weekday.fromInt(lt.*.tm_wday),
            .millisecond = time_ms - time_s * 1000,
            .isDST = lt.*.tm_isdst == 1,
            ._lt = lt,
            ._time_ms = time_ms,
        };
    }

    pub fn createDate(year: i32, month: i32, day: i32) DateTime {
        const time_ms = std.time.milliTimestamp();
        const time_s = @divTrunc(time_ms, 1000);
        const lt = ctime.localtime(&time_s);
        lt.*.tm_year = year - 1900;
        lt.*.tm_mon = month - 1;
        lt.*.tm_mday = day;
        lt.*.tm_hour = 0;
        lt.*.tm_min = 0;
        lt.*.tm_sec = 0;
        const t = ctime.mktime(lt);
        return fromTimestamp(t * 1000);
    }

    pub fn createDateTime(year: i32, month: i32, day: i32, hour: i32, minute: i32, second: i32) DateTime {
        const time_ms = std.time.milliTimestamp();
        const time_s = @divTrunc(time_ms, 1000);
        const lt = ctime.localtime(&time_s);
        lt.*.tm_year = year - 1900;
        lt.*.tm_mon = month - 1;
        lt.*.tm_mday = day;
        lt.*.tm_hour = hour;
        lt.*.tm_min = minute;
        lt.*.tm_sec = second;
        const t = ctime.mktime(lt);
        return fromTimestamp(t * 1000);
    }

    pub fn addDay(self: DateTime, d: i64) DateTime {
        var new_time_s = @divTrunc(self._time_ms, 1000);
        new_time_s += d * 24 * 60 * 60;
        return DateTime.fromTimestamp(new_time_s * 1000);
    }

    pub fn toISODate(self: DateTime, buf: []u8) ![]u8 {
        if (buf.len < 10) return error.NoSpaceLeft;
        var fbs = std.io.fixedBufferStream(buf);
        try std.fmt.format(
            fbs.writer(),
            "{d}-{d:0>2}-{d:0>2}",
            .{ self.year, @abs(self.month), @abs(self.day) },
        );
        return buf[0..10];
    }

    pub fn toISODateTime(self: DateTime, buf: []u8) ![]u8 {
        if (buf.len < 19) return error.NoSpaceLeft;
        var fbs = std.io.fixedBufferStream(buf);
        try std.fmt.format(
            fbs.writer(),
            "{d}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}",
            .{
                self.year,
                @abs(self.month),
                @abs(self.day),
                @abs(self.hour),
                @abs(self.minute),
                @abs(self.second),
            },
        );
        return buf[0..19];
    }

    pub fn toISODateTimeMillisecond(self: DateTime, buf: []u8) ![]u8 {
        if (buf.len < 23) return error.NoSpaceLeft;
        var fbs = std.io.fixedBufferStream(buf);
        try std.fmt.format(
            fbs.writer(),
            "{d}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}",
            .{
                self.year,
                @abs(self.month),
                @abs(self.day),
                @abs(self.hour),
                @abs(self.minute),
                @abs(self.second),
                @abs(self.millisecond),
            },
        );
        return buf[0..23];
    }
};

// test with -lc param as it needs clib

test "toISODate" {
    const d = DateTime.createDate(2023, 12, 25);
    var buf = [_]u8{0} ** 10;
    assert(std.mem.eql(u8, "2023-12-25", try d.toISODate(&buf)));
}

test "toISODateTime" {
    const d = DateTime.createDateTime(2023, 12, 25, 23, 55, 42);
    var buf = [_]u8{0} ** 19;
    assert(std.mem.eql(u8, "2023-12-25 23:55:42", try d.toISODateTime(&buf)));
}

test "toISODateTimeMillisecond" {
    const d = DateTime.createDateTime(2023, 12, 25, 23, 55, 42);
    var buf = [_]u8{0} ** 23;
    assert(std.mem.eql(u8, "2023-12-25 23:55:42.000", try d.toISODateTimeMillisecond(&buf)));
}
