const std = @import("std");
const time = @import("date_time.zig");
const DateTime = time.DateTime;
const Weekday = time.Weekday;
const Allocator = std.mem.Allocator;

const ArgumentsError = error{
    NoArguments,
    TooFewArguments,
    YearOutOfRange,
    TooFewFields,
};

const Config = struct {
    billingYear: i32 = undefined,
    startWeekday: Weekday = undefined,
    table: []const u8 = "BillingCalendar",
    fields: [4][]const u8 = [_][]const u8{ "BillingYear", "BillingWeek", "StartDate", "EndDate" },
};

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    defer bw.flush() catch std.log.err("cannot flush stdout", .{});

    var config = Config{};

    readArguments(args, &config) catch |e| {
        switch (e) {
            time.DateTimeError.WeekdayParseError => {
                try stdout.print("\nInvalid format of weekday argument\n\n", .{});
            },
            error.InvalidCharacter => {
                try stdout.print("\nInvalid format of year argument\n\n", .{});
            },
            ArgumentsError.YearOutOfRange => {
                try stdout.print("\nInvalid year. Year must be between 1971 and 2999.\n\n", .{});
            },
            ArgumentsError.NoArguments, ArgumentsError.TooFewArguments => {
                try stdout.print("\nMissing or incomplete arguments\n\n", .{});
            },
            ArgumentsError.TooFewFields => {
                try stdout.print("\nError in custom fields count. Must be 4.\n\n", .{});
            },
            else => try stdout.print("{}\n", .{e}),
        }

        try printUsage(stdout);
        return 1;
    };

    var startISODate = [_]u8{0} ** 10;
    var endISODate = [_]u8{0} ** 10;

    var startDate = firstDayOfBillingYear(config.billingYear, config.startWeekday);
    var endDate: DateTime = undefined;
    var weekCount: u8 = 1;

    try stdout.print("INSERT INTO {s} ({s}, {s}, {s}, {s}) VALUES ", .{
        config.table,
        config.fields[0],
        config.fields[1],
        config.fields[2],
        config.fields[3],
    });
    while (true) {
        endDate = startDate.addDay(6);
        try stdout.print(
            "({d}, {d}, '{s}', '{s}')",
            .{
                config.billingYear,
                weekCount,
                try startDate.toISODate(&startISODate),
                try endDate.toISODate(&endISODate),
            },
        );
        if (endDate.addDay(7).year != config.billingYear) {
            try stdout.print(";\n", .{});
            break;
        } else {
            try stdout.print(",\n", .{});
        }
        startDate = endDate.addDay(1);
        weekCount += 1;
    }

    return 0;
}

fn firstDayOfBillingYear(year: i32, startWeekday: Weekday) DateTime {
    var d = DateTime.createDate(year, 1, 1);
    while (d.weekday != startWeekday) d = d.addDay(-1);
    return d;
}

fn readArguments(args: [][]u8, config: *Config) !void {
    if (args.len == 1) return ArgumentsError.NoArguments;
    if (args.len < 3) return ArgumentsError.TooFewArguments;

    config.*.billingYear = try std.fmt.parseInt(i32, args[1], 10);
    if (config.billingYear < 1971 or config.billingYear > 2999) {
        return ArgumentsError.YearOutOfRange;
    }
    config.*.startWeekday = try Weekday.parse(args[2]);

    // read custom table and fields
    if (args.len >= 4) {
        if (std.mem.count(u8, args[3], ",") != 4) {
            return ArgumentsError.TooFewFields;
        } else {
            var f = std.mem.splitSequence(u8, args[3], ",");
            config.*.table = f.next().?;
            for (0..4) |i| config.*.fields[i] = f.next().?;
        }
    }
}

fn printUsage(stdout: anytype) !void {
    try stdout.print(
        \\******************************************
        \\* Weekly billing calendar generator v1.0 *
        \\******************************************
        \\This program outputs SQL INSERT statement for all weeks of the billing calendar.
        \\
        \\Usage: bcgen year weekday-start [tableName,yearField,weekField,startField,endField]
        \\
        \\Example #1: bcgen 2024 thursday
        \\Example #2: bcgen 2024 monday calendar,billing_year,billing_week,start_date,end_date
        \\
        \\
    , .{});
}
