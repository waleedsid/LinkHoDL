import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/link_model.dart';

class LinkService {
  static const String _storageKey = 'linkhodl_links';
  static const String _profileKey = 'linkhodl_profile';

  // Available colors for links
  static final List<Color> _availableColors = [
    Colors.red.shade400,
    Colors.green.shade400,
    Colors.blue.shade400,
    Colors.purple.shade400,
    Colors.orange.shade400,
    Colors.teal.shade400,
  ];

  // Get a random color for a new link
  Color getRandomColor() {
    final random = Random();
    return _availableColors[random.nextInt(_availableColors.length)];
  }

  // Get all links
  Future<List<Link>> getLinks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? linksJson = prefs.getString(_storageKey);

      if (linksJson == null || linksJson.isEmpty) {
        return [];
      }

      try {
        final List<dynamic> decoded = jsonDecode(linksJson);
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((item) => Link.fromMap(item))
            .toList();
      } catch (e) {
        print('Error parsing links from storage: $e');
        return [];
      }
    } catch (e) {
      print('Error loading links: $e');
      return [];
    }
  }

  // Get filtered links based on day filter
  Future<List<Link>> getFilteredLinks(String filterMode) async {
    try {
      final allLinks = await getLinks();

      if (filterMode == 'all') {
        return allLinks;
      }

      // Get current date for filtering
      final now = DateTime.now();

      // Determine date range based on filter
      DateTime startDate;

      switch (filterMode) {
        case 'week':
          startDate = DateTime(now.year, now.month, now.day - 7);
          break;
        case 'month':
          startDate = DateTime(now.year, now.month - 1, now.day);
          break;
        case 'year':
          startDate = DateTime(now.year - 1, now.month, now.day);
          break;
        default:
          return allLinks;
      }

      // Filter links
      return allLinks
          .where((link) => link.dateAdded.isAfter(startDate))
          .toList();
    } catch (e) {
      print('Error in getFilteredLinks: $e');
      // Return empty list on error instead of crashing
      return [];
    }
  }

  // Search suggestions based on query
  Future<List<String>> getSearchSuggestions(String query) async {
    final links = await getLinks();
    final Set<String> suggestions = {};

    query = query.toLowerCase();

    for (final link in links) {
      if (link.title.toLowerCase().contains(query)) {
        suggestions.add(link.title);
      }
      if (link.url.toLowerCase().contains(query)) {
        suggestions.add(link.url);
      }
    }

    return suggestions.toList()..sort();
  }

  // Save links
  Future<void> saveLinks(List<Link> links) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = links.map((link) => link.toMap()).toList();
    await prefs.setString(_storageKey, jsonEncode(encoded));
  }

  // Add a new link
  Future<void> addLink(Link link) async {
    final links = await getLinks();
    links.add(link);
    await saveLinks(links);
  }

  // Update an existing link
  Future<void> updateLink(Link updatedLink) async {
    final links = await getLinks();
    final index = links.indexWhere((link) => link.id == updatedLink.id);

    if (index >= 0) {
      links[index] = updatedLink;
      await saveLinks(links);
    }
  }

  // Delete a link
  Future<void> deleteLink(String id) async {
    final links = await getLinks();
    links.removeWhere((link) => link.id == id);
    await saveLinks(links);
  }

  // Toggle favorite status
  Future<void> toggleFavorite(String id) async {
    final links = await getLinks();
    final index = links.indexWhere((link) => link.id == id);

    if (index >= 0) {
      final link = links[index];
      links[index] = link.copyWith(isFavorite: !link.isFavorite);
      await saveLinks(links);
    }
  }

  // Get activity data for the chart based on selected filter
  Future<Map<DateTime, int>> getActivityData(
      {String filterMode = 'all'}) async {
    try {
      final links = await getLinks();
      final Map<DateTime, int> activityData = {};

      // Get current date for filtering
      final now = DateTime.now();

      // Determine date range based on filter
      DateTime startDate;

      switch (filterMode) {
        case 'week':
          startDate = DateTime(now.year, now.month, now.day - 7);
          break;
        case 'month':
          startDate = DateTime(now.year, now.month - 1, now.day);
          break;
        case 'year':
          startDate = DateTime(now.year - 1, now.month, now.day);
          break;
        case 'all':
        default:
          // For "all", go back up to 365 days or to the oldest link
          final oldestLinkDate = links.isEmpty
              ? now
              : links
                  .map((l) => l.dateAdded)
                  .reduce((a, b) => a.isBefore(b) ? a : b);
          startDate = oldestLinkDate
                  .isBefore(DateTime(now.year - 1, now.month, now.day))
              ? DateTime(now.year - 1, now.month, now.day)
              : oldestLinkDate;
      }

      // Normalize dates based on filter mode
      bool showMonthlyData = now.difference(startDate).inDays > 31;

      // Populate date range
      if (showMonthlyData) {
        // Group by months
        DateTime current = DateTime(startDate.year, startDate.month, 1);
        while (current.isBefore(DateTime(now.year, now.month + 1, 1))) {
          activityData[current] = 0;
          current = DateTime(current.year, current.month + 1, 1);
        }
      } else {
        // Group by days
        DateTime current =
            DateTime(startDate.year, startDate.month, startDate.day);
        while (current.isBefore(DateTime(now.year, now.month, now.day + 1))) {
          activityData[current] = 0;
          current = DateTime(current.year, current.month, current.day + 1);
        }
      }

      // Count links added for each period
      for (final link in links) {
        // Skip links before the start date
        if (link.dateAdded.isBefore(startDate)) continue;

        DateTime key;
        if (showMonthlyData) {
          // Group by month
          key = DateTime(link.dateAdded.year, link.dateAdded.month, 1);
        } else {
          // Group by day
          key = DateTime(
              link.dateAdded.year, link.dateAdded.month, link.dateAdded.day);
        }

        activityData[key] = (activityData[key] ?? 0) + 1;
      }

      return activityData;
    } catch (e) {
      print('Error in getActivityData: $e');
      // Return empty map on error instead of crashing
      return {};
    }
  }

  // Get categories from existing links
  Future<List<String>> getCategories() async {
    final links = await getLinks();
    final Set<String> categories = {};

    for (final link in links) {
      if (link.category != null && link.category!.isNotEmpty) {
        categories.add(link.category!);
      }
    }

    return categories.toList()..sort();
  }

  // Get user profile
  Future<Map<String, dynamic>> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? profileJson = prefs.getString(_profileKey);

    if (profileJson == null) {
      return {
        'name': 'User',
        'email': null,
        'avatarUrl': null,
        'joinDate': DateTime.now().millisecondsSinceEpoch,
      };
    }

    return jsonDecode(profileJson) as Map<String, dynamic>;
  }

  // Save user profile
  Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile));
  }
}
