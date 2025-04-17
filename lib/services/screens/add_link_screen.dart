import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/link_model.dart';
import '../services/link_service.dart';

class AddLinkScreen extends StatefulWidget {
  final Link? linkToEdit; // Optional link to edit

  const AddLinkScreen({Key? key, this.linkToEdit}) : super(key: key);

  @override
  State<AddLinkScreen> createState() => _AddLinkScreenState();
}

class _AddLinkScreenState extends State<AddLinkScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  final _categoryController = TextEditingController();
  final LinkService _linkService = LinkService();
  bool _isLoading = false;
  String? _selectedCategory;
  bool _showCategoryField = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  List<String> _categories = [];

  final Map<String, IconData> _categoryIcons = {
    'YouTube': Icons.video_library,
    'Instagram': Icons.photo_camera,
    'Twitter': Icons.chat,
    'Facebook': Icons.facebook,
    'Shopping': Icons.shopping_cart,
    'News': Icons.article,
    'Education': Icons.school,
    'Work': Icons.work,
    'Personal': Icons.person,
    'Other': Icons.link,
  };

  @override
  void initState() {
    super.initState();
    // Animation setup
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _loadCategories();

    // Fill form if editing an existing link
    if (widget.linkToEdit != null) {
      _titleController.text = widget.linkToEdit!.title;
      _urlController.text = widget.linkToEdit!.url;
      _selectedCategory = widget.linkToEdit!.category;
      if (_selectedCategory != null) {
        _showCategoryField = true;
      }
    }

    _animationController.forward();
  }

  Future<void> _loadCategories() async {
    final categories = await _linkService.getCategories();
    setState(() {
      _categories = categories;
      // Add default categories if none exist
      if (_categories.isEmpty) {
        _categories = _categoryIcons.keys.toList();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _categoryController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String? _detectCategory(String url) {
    final lowercaseUrl = url.toLowerCase();

    if (lowercaseUrl.contains('youtube') || lowercaseUrl.contains('youtu.be')) {
      return 'YouTube';
    } else if (lowercaseUrl.contains('instagram')) {
      return 'Instagram';
    } else if (lowercaseUrl.contains('twitter') ||
        lowercaseUrl.contains('x.com')) {
      return 'Twitter';
    } else if (lowercaseUrl.contains('facebook')) {
      return 'Facebook';
    } else if (lowercaseUrl.contains('amazon') ||
        lowercaseUrl.contains('ebay') ||
        lowercaseUrl.contains('shop')) {
      return 'Shopping';
    } else if (lowercaseUrl.contains('news') ||
        lowercaseUrl.contains('bbc') ||
        lowercaseUrl.contains('cnn')) {
      return 'News';
    } else if (lowercaseUrl.contains('edu') ||
        lowercaseUrl.contains('course') ||
        lowercaseUrl.contains('learn')) {
      return 'Education';
    }

    return null;
  }

  // Improved URL validation
  String? _validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a URL';
    }

    String url = value.trim();
    // Add protocol if missing
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
      _urlController.text = url;
    }

    // Basic URL pattern validation
    final RegExp urlRegExp = RegExp(
      r'^(https?:\/\/)?(www\.)?([a-zA-Z0-9][-a-zA-Z0-9]{0,62}\.)+[a-zA-Z]{2,}(:\d+)?(\/[-a-zA-Z0-9%_.~#?&=]*)?$',
      caseSensitive: false,
    );

    if (!urlRegExp.hasMatch(url)) {
      return 'Please enter a valid URL';
    }

    return null;
  }

  Future<void> _openLink() async {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      String formattedUrl = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        formattedUrl = 'https://$url';
      }

      try {
        final uri = Uri.parse(formattedUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not open link: $url')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error opening link: $e')),
          );
        }
      }
    }
  }

  Future<void> _saveLink() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final isEditing = widget.linkToEdit != null;
        final url = _urlController.text.trim();

        // Auto-detect category if none selected
        if (_selectedCategory == null || _selectedCategory!.isEmpty) {
          _selectedCategory = _detectCategory(url);
        }

        final link = Link(
          id: isEditing ? widget.linkToEdit!.id : const Uuid().v4(),
          title: _titleController.text.trim(),
          url: url,
          dateAdded: isEditing ? widget.linkToEdit!.dateAdded : DateTime.now(),
          color: isEditing
              ? widget.linkToEdit!.color
              : _linkService.getRandomColor(),
          category: _selectedCategory,
          isFavorite: widget.linkToEdit?.isFavorite ?? false,
          note: widget.linkToEdit?.note,
        );

        if (isEditing) {
          await _linkService.updateLink(link);
        } else {
          await _linkService.addLink(link);
        }

        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving link: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.linkToEdit == null ? 'Add Link' : 'Edit Link'),
        backgroundColor: isDarkMode
            ? Theme.of(context).appBarTheme.backgroundColor
            : Colors.deepPurple.shade50,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // URL Field with auto detect title feature
                    TextFormField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        labelText: 'Link URL',
                        border: const OutlineInputBorder(),
                        hintText: 'https://example.com',
                        prefixIcon: const Icon(Icons.link),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Open directly button
                            IconButton(
                              icon: const Icon(Icons.open_in_new,
                                  color: Color(0xFF6C63FF)),
                              tooltip: 'Open link',
                              onPressed: _openLink,
                            ),
                            // Clear button
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _urlController.clear();
                              },
                            ),
                          ],
                        ),
                      ),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      onChanged: (value) {
                        // Try to detect category from URL
                        final detectedCategory = _detectCategory(value);
                        if (detectedCategory != null &&
                            (_selectedCategory == null ||
                                _selectedCategory!.isEmpty)) {
                          setState(() {
                            _selectedCategory = detectedCategory;
                            _showCategoryField = true;
                          });
                        }
                      },
                      validator: _validateUrl,
                    ),
                    const SizedBox(height: 16.0),

                    // Title Field
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Link Title',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),

                    // Category Selector
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.category),
                            label: Text(_showCategoryField
                                ? 'Change Category'
                                : 'Add Category'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: primaryColor),
                            ),
                            onPressed: () {
                              setState(() {
                                _showCategoryField = true;
                              });

                              // Show category selection dialog
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (context) => StatefulBuilder(
                                  builder: (context, setModalState) =>
                                      Container(
                                    padding: const EdgeInsets.all(20),
                                    height: MediaQuery.of(context).size.height *
                                        0.6,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Select Category',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onBackground,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        // Fixed categories
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            ..._categoryIcons.entries
                                                .map((entry) {
                                              final isSelected =
                                                  _selectedCategory ==
                                                      entry.key;
                                              final Color accentColor =
                                                  isDarkMode
                                                      ? Colors.deepPurpleAccent
                                                      : const Color(0xFF6C63FF);

                                              return InkWell(
                                                onTap: () {
                                                  setModalState(() {
                                                    _selectedCategory =
                                                        entry.key;
                                                  });
                                                  setState(() {
                                                    _selectedCategory =
                                                        entry.key;
                                                  });
                                                  Navigator.pop(context);
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? accentColor
                                                        : accentColor
                                                            .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            30),
                                                    border: Border.all(
                                                      color: isSelected
                                                          ? accentColor
                                                          : Colors.transparent,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        entry.value,
                                                        size: 18,
                                                        color: isSelected
                                                            ? Colors.white
                                                            : accentColor,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        entry.key,
                                                        style: TextStyle(
                                                          color: isSelected
                                                              ? Colors.white
                                                              : accentColor,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                            // Custom category
                                            InkWell(
                                              onTap: () {
                                                Navigator.pop(context);
                                                // Show custom category dialog
                                                showDialog(
                                                  context: context,
                                                  builder: (context) =>
                                                      AlertDialog(
                                                    title: const Text(
                                                        'Custom Category'),
                                                    content: TextField(
                                                      controller:
                                                          _categoryController,
                                                      decoration:
                                                          const InputDecoration(
                                                        labelText:
                                                            'Category Name',
                                                      ),
                                                      autofocus: true,
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context),
                                                        child: const Text(
                                                            'CANCEL'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () {
                                                          setState(() {
                                                            _selectedCategory =
                                                                _categoryController
                                                                    .text;
                                                          });
                                                          Navigator.pop(
                                                              context);
                                                        },
                                                        child:
                                                            const Text('ADD'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: isDarkMode
                                                      ? Colors.grey.shade800
                                                      : Colors.grey
                                                          .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(30),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.add,
                                                      size: 18,
                                                      color: isDarkMode
                                                          ? Colors.grey.shade300
                                                          : Colors.grey,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Custom',
                                                      style: TextStyle(
                                                        color: isDarkMode
                                                            ? Colors
                                                                .grey.shade300
                                                            : Colors.grey,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (_selectedCategory != null &&
                            _selectedCategory!.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Chip(
                            label: Text(_selectedCategory!),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () {
                              setState(() {
                                _selectedCategory = null;
                              });
                            },
                            backgroundColor:
                                const Color(0xFF6C63FF).withOpacity(0.1),
                            labelStyle:
                                const TextStyle(color: Color(0xFF6C63FF)),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 32.0),

                    // Save Button
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveLink,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                      ),
                      icon: _isLoading
                          ? Container(
                              width: 24,
                              height: 24,
                              padding: const EdgeInsets.all(2.0),
                              child: CircularProgressIndicator(
                                color: Theme.of(context).colorScheme.onPrimary,
                                strokeWidth: 3,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isLoading ? 'Saving...' : 'SAVE LINK'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
