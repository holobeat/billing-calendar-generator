Weekly Billing Calendar Generator
=================================

This program outputs SQL INSERT statement for all weeks of the billing calendar.

- The weekday argument accepts long and short name, case agnostic (mon, Mon, Monday, MON).
- If one or more days of the billing week happen to be in the next year, that week is not part of the output.
- First billing week of the year may start at the end of the previous year if any of its days are in the requested year. For example, billing week from 2023-12-28 to 2024-01-03 is considered first billing week of year 2024.

Usage:

    bcgen year weekday-start [tableName,yearField,weekField,startField,endField]

Examples:

    bcgen 2024 thursday
    bcgen 2024 monday calendar,billing_year,billing_week,start_date,end_date

Output:

    INSERT INTO calendar (billing_year, billing_week, start_date, end_date)
    VALUES (2024, 1, '2023-12-28', '2024-01-03'), ..., ...,
    (2024, 52, '2024-12-19', '2024-12-25');

Build
-----

    zig build

or

    zig build-exe -lc -O ReleaseSmall .\src\main.zig --name bcgen

