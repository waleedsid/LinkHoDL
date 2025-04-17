import 'package:flutter/material.dart';

class Link {
  final String id;
  final String title;
  final String url;
  final DateTime dateAdded;
  final Color color;
  final String? category;
  final bool isFavorite;
  final String? note;

  Link({
    required this.id,
    required this.title,
    required this.url,
    required this.dateAdded,
    required this.color,
    this.category,
    this.isFavorite = false,
    this.note,
  });

  // Create a copy of this Link with the given fields replaced
  Link copyWith({
    String? id,
    String? title,
    String? url,
    DateTime? dateAdded,
    Color? color,
    String? category,
    bool? isFavorite,
    String? note,
  }) {
    return Link(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      dateAdded: dateAdded ?? this.dateAdded,
      color: color ?? this.color,
      category: category ?? this.category,
      isFavorite: isFavorite ?? this.isFavorite,
      note: note ?? this.note,
    );
  }

  // Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'dateAdded': dateAdded.millisecondsSinceEpoch,
      'color': color.value,
      'category': category,
      'isFavorite': isFavorite,
      'note': note,
    };
  }

  // Create Link from Map
  factory Link.fromMap(Map<String, dynamic> map) {
    return Link(
      id: map['id'] as String,
      title: map['title'] as String,
      url: map['url'] as String,
      dateAdded: DateTime.fromMillisecondsSinceEpoch(map['dateAdded'] as int),
      color: Color(map['color'] as int),
      category: map['category'] as String?,
      isFavorite: map['isFavorite'] as bool? ?? false,
      note: map['note'] as String?,
    );
  }
}
