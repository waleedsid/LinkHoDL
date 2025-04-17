import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ActivityChart extends StatelessWidget {
  final Map<DateTime, int> activityData;
  final String filterMode;
  final int? customDays;

  const ActivityChart({
    super.key,
    required this.activityData,
    this.filterMode = 'all',
    this.customDays,
  });

  @override
  Widget build(BuildContext context) {
    // Sort the dates
    final dates = activityData.keys.toList()..sort((a, b) => a.compareTo(b));

    if (dates.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.analytics_outlined,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                'No activity data available',
                style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Find the maximum count for scaling - ensure a minimum of 1 to avoid division by zero
    final maxCount = activityData.values
        .fold<int>(0, (max, count) => count > max ? count : max)
        .clamp(1, double.infinity)
        .toInt();

    // Calculate time range
    final firstDate = dates.first;
    final lastDate = dates.last;
    final daysDifference =
        lastDate.difference(firstDate).inDays + 1; // +1 to include today

    // Determine if we're showing monthly or daily data based on filter or custom days
    bool showMonthly;
    if (filterMode == 'custom' && customDays != null) {
      showMonthly = customDays! > 31;
    } else {
      showMonthly = daysDifference > 31;
    }

    // Format dates based on duration
    String formatDate(DateTime date) {
      if (showMonthly) {
        return DateFormat('MMM').format(date); // Month abbreviation
      } else {
        return DateFormat('dd').format(date); // Just day number
      }
    }

    // Determine which dates to show labels for (to avoid overcrowding)
    bool shouldShowLabel(int index) {
      final int totalItems = dates.length;
      if (totalItems <= 7) return true;
      if (totalItems <= 14) return index % 2 == 0;
      if (totalItems <= 31) return index % 3 == 0;
      return index % 5 == 0 ||
          index == 0 ||
          index == totalItems - 1; // Always show first and last
    }

    final chartBarColor = Theme.of(context).colorScheme.primary;
    final chartBackgroundColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.7);

    // Calculate a good bar width based on number of dates
    final double barWidth = dates.length <= 10 ? 10.0 : 6.0;

    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: chartBackgroundColor,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                children: [
                  // Y-axis labels
                  SizedBox(
                    width: 25,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          maxCount.toString(),
                          style: TextStyle(fontSize: 10, color: textColor),
                        ),
                        Text(
                          (maxCount / 2).round().toString(),
                          style: TextStyle(fontSize: 10, color: textColor),
                        ),
                        Text(
                          '0',
                          style: TextStyle(fontSize: 10, color: textColor),
                        ),
                      ],
                    ),
                  ),
                  // Chart bars
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        width: dates.length *
                            (barWidth +
                                8), // Dynamic width based on number of bars
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(dates.length, (index) {
                            final date = dates[index];
                            final count = activityData[date] ?? 0;
                            final double barHeightPercentage = count > 0
                                ? (count / maxCount).clamp(0.05, 1.0)
                                : 0.0;
                            final height = barHeightPercentage * 100.0;

                            return Container(
                              width: barWidth + 8,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Show tooltip with count on hover
                                  Tooltip(
                                    message:
                                        '$count link${count == 1 ? '' : 's'} on ${DateFormat('dd/MM/yyyy').format(date)}',
                                    child: Container(
                                      height: height,
                                      width: barWidth,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 4.0),
                                      decoration: BoxDecoration(
                                        color: count > 0
                                            ? chartBarColor
                                            : chartBarColor.withOpacity(0.3),
                                        borderRadius:
                                            BorderRadius.circular(4.0),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4.0),
                                  // Only show some date labels to avoid overcrowding
                                  shouldShowLabel(index)
                                      ? Text(
                                          formatDate(date),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: textColor,
                                          ),
                                        )
                                      : const SizedBox(
                                          height:
                                              14), // Empty space for alignment
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
