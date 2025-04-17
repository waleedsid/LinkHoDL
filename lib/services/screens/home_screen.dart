import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/link_model.dart';
import '../services/link_service.dart';
import '../widgets/activity_chart.dart';
import 'add_link_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final LinkService _linkService = LinkService();
  List<Link> _links = [];
  Map<DateTime, int> _activityData = {};
  bool _isLoading = true;
  String _searchQuery = '';
  List<String> _searchSuggestions = [];
  bool _isSearching = false;
  late TabController _tabController;
  int _currentDayFilter = 7;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Convert int to string filter mode
      final String filterMode = _currentDayFilter == 7
          ? 'week'
          : _currentDayFilter == 30
              ? 'month'
              : _currentDayFilter == 365
                  ? 'year'
                  : 'all';

      final links = await _linkService.getFilteredLinks(filterMode);
      final activityData =
          await _linkService.getActivityData(filterMode: filterMode);

      if (mounted) {
        setState(() {
          _links = links;
          _activityData = activityData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _searchLinks(String query) async {
    if (!mounted) return;

    setState(() {
      _searchQuery = query;
      _isSearching = query.isNotEmpty;
    });

    if (query.isNotEmpty) {
      final suggestions = await _linkService.getSearchSuggestions(query);
      if (mounted) {
        setState(() {
          _searchSuggestions = suggestions;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _searchSuggestions = [];
        });
      }
    }
  }

  void _updateDayFilter(int days) {
    setState(() {
      _currentDayFilter = days;
    });
    _loadData();
  }

  List<Link> get _filteredLinks {
    if (_searchQuery.isEmpty) {
      return _tabController.index == 0
          ? _links
          : _tabController.index == 1
              ? _links.where((link) => link.isFavorite).toList()
              : _links;
    }

    final filtered = _links
        .where((link) =>
            link.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            link.url.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (link.category != null &&
                link.category!
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase())))
        .toList();

    return _tabController.index == 0
        ? filtered
        : _tabController.index == 1
            ? filtered.where((link) => link.isFavorite).toList()
            : filtered;
  }

  Future<void> _addOrEditLink(BuildContext context, [Link? link]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddLinkScreen(linkToEdit: link),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Link copied to clipboard'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF6C63FF),
        ),
      );
    }
  }

  Future<void> _openLink(String url) async {
    try {
      // Ensure URL has protocol
      String formattedUrl = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        formattedUrl = 'https://$url';
      }

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

  Future<bool> _confirmDelete(BuildContext context, Link link) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Link'),
            content: Text('Are you sure you want to delete "${link.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('DELETE'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteLink(Link link) async {
    final confirmed = await _confirmDelete(context, link);

    if (confirmed) {
      try {
        await _linkService.deleteLink(link.id);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${link.title} deleted'),
              action: SnackBarAction(
                label: 'UNDO',
                onPressed: () async {
                  await _linkService.addLink(link);
                  _loadData();
                },
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting link: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleFavorite(Link link) async {
    try {
      await _linkService.toggleFavorite(link.id);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating favorite: $e')),
        );
      }
    }
  }

  Widget _buildLinkCard(Link link) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Dismissible(
          key: Key(link.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20.0),
            color: Colors.red,
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          confirmDismiss: (direction) => _confirmDelete(context, link),
          onDismissed: (direction) => _deleteLink(link),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // Show options dialog with open in browser option
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withOpacity(0.1),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: link.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.link, color: link.color),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    link.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    link.url,
                                    style: TextStyle(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.open_in_browser,
                            color: Color(0xFF6C63FF)),
                        title: const Text('Open in Browser'),
                        onTap: () {
                          Navigator.pop(context);
                          _openLink(link.url);
                        },
                      ),
                      ListTile(
                        leading:
                            const Icon(Icons.copy, color: Color(0xFF6C63FF)),
                        title: const Text('Copy Link'),
                        onTap: () {
                          Navigator.pop(context);
                          _copyToClipboard(link.url);
                        },
                      ),
                      ListTile(
                        leading:
                            const Icon(Icons.edit, color: Color(0xFF6C63FF)),
                        title: const Text('Edit Link'),
                        onTap: () {
                          Navigator.pop(context);
                          _addOrEditLink(context, link);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete, color: Colors.red),
                        title: const Text('Delete Link',
                            style: TextStyle(color: Colors.red)),
                        onTap: () {
                          Navigator.pop(context);
                          _deleteLink(link);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: link.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.link_rounded,
                            color: link.color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                link.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                link.url,
                                style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            link.isFavorite
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: link.isFavorite
                                ? const Color(0xFFFF7746)
                                : Colors.grey,
                          ),
                          onPressed: () => _toggleFavorite(link),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (link.category != null && link.category!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: link.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              link.category!,
                              style: TextStyle(
                                color: link.color,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        Row(
                          children: [
                            Text(
                              DateFormat('MMM d, yyyy').format(link.dateAdded),
                              style: TextStyle(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _addOrEditLink(context, link),
                              color: const Color(0xFF6C63FF),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.copy_outlined, size: 20),
                              onPressed: () => _copyToClipboard(link.url),
                              color: const Color(0xFF6C63FF),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => _deleteLink(link),
                              color: Colors.red.shade400,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Delete link',
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildSearchSuggestions() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _searchSuggestions.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.search, color: Color(0xFF6C63FF)),
            title: Text(
              _searchSuggestions[index],
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            onTap: () {
              _searchLinks(_searchSuggestions[index]);
              setState(() {
                _isSearching = false;
              });
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for settings changes
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with search
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.settings,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(),
                            ),
                          );
                          _loadData();
                        },
                      ),
                      Expanded(
                        child: TextField(
                          onChanged: _searchLinks,
                          decoration: InputDecoration(
                            hintText: 'Search links...',
                            filled: true,
                            fillColor: Theme.of(context).cardColor,
                            prefixIcon:
                                const Icon(Icons.search, color: Colors.grey),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.mic, color: Colors.grey),
                              onPressed: _startVoiceSearch,
                              tooltip: 'Voice search',
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.filter_list,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                        onPressed: () {
                          _showFilterOptions(context);
                        },
                        tooltip: 'Filter',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tabs
                  TabBar(
                    controller: _tabController,
                    labelColor: primaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: primaryColor,
                    tabs: const [
                      Tab(text: 'All'),
                      Tab(text: 'Favorites'),
                      Tab(text: 'Categories'),
                    ],
                    onTap: (_) {
                      setState(() {});
                    },
                  ),

                  const SizedBox(height: 16),

                  // Activity chart
                  if (_tabController.index == 0)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Activity',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ActivityChart(
                              activityData: _activityData,
                              filterMode: _currentDayFilter == 7
                                  ? 'week'
                                  : _currentDayFilter == 30
                                      ? 'month'
                                      : _currentDayFilter == 365
                                          ? 'year'
                                          : _currentDayFilter == 0
                                              ? 'all'
                                              : 'custom',
                              customDays: _currentDayFilter,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Category folders view
                  if (_tabController.index == 2)
                    Expanded(
                      child: _buildCategoriesView(),
                    ),

                  // Links list (for All and Favorites tabs)
                  if (_tabController.index != 2)
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _filteredLinks.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _searchQuery.isNotEmpty
                                            ? Icons.search_off
                                            : _tabController.index == 1
                                                ? Icons.star_border
                                                : Icons.link_off,
                                        size: 64,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.grey.shade500
                                            : Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _searchQuery.isNotEmpty
                                            ? 'No links found matching "$_searchQuery"'
                                            : _tabController.index == 1
                                                ? 'No favorite links yet'
                                                : 'No links saved yet',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onBackground
                                              .withOpacity(0.7),
                                          fontSize: 16,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      if (_searchQuery.isEmpty &&
                                          _tabController.index == 0) ...[
                                        const SizedBox(height: 24),
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              _addOrEditLink(context),
                                          icon: const Icon(Icons.add),
                                          label:
                                              const Text('Add Your First Link'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            foregroundColor: Theme.of(context)
                                                .colorScheme
                                                .onPrimary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: _loadData,
                                  child: ListView.builder(
                                    itemCount: _filteredLinks.length,
                                    padding: const EdgeInsets.only(bottom: 80),
                                    itemBuilder: (context, index) {
                                      return _buildLinkCard(
                                          _filteredLinks[index]);
                                    },
                                  ),
                                ),
                    ),
                ],
              ),
            ),
            // Search suggestions overlay
            if (_isSearching && _searchSuggestions.isNotEmpty)
              Positioned(
                top: 60,
                left: 16,
                right: 16,
                child: _buildSearchSuggestions(),
              ),
          ],
        ),
      ),
      floatingActionButton: !_isSearching
          ? FloatingActionButton.extended(
              onPressed: () => _addOrEditLink(context),
              backgroundColor: primaryColor,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text('Add Link'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // Helper to get formatted slider label
  String _getSliderLabel(int days) {
    if (days == 1) return '1 day';
    if (days == 7) return '1 week';
    if (days == 30) return '1 month';
    if (days == 90) return '3 months';
    if (days == 180) return '6 months';
    if (days == 365) return '1 year';
    return '$days days';
  }

  // Helper to get activity title
  String _getActivityTitle() {
    if (_currentDayFilter == 0) return 'All Time';
    if (_currentDayFilter == 1) return 'Last 24 Hours';
    if (_currentDayFilter == 7) return 'Last Week';
    if (_currentDayFilter == 30) return 'Last Month';
    if (_currentDayFilter == 365) return 'Last Year';
    return 'Last $_currentDayFilter Days';
  }

  // Show filter options dialog
  void _showFilterOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Time'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Last 24 Hours'),
              leading: Radio<int>(
                value: 1,
                groupValue: _currentDayFilter,
                onChanged: (value) {
                  Navigator.pop(context);
                  _updateDayFilter(value!);
                },
              ),
            ),
            ListTile(
              title: const Text('Last Week'),
              leading: Radio<int>(
                value: 7,
                groupValue: _currentDayFilter,
                onChanged: (value) {
                  Navigator.pop(context);
                  _updateDayFilter(value!);
                },
              ),
            ),
            ListTile(
              title: const Text('Last Month'),
              leading: Radio<int>(
                value: 30,
                groupValue: _currentDayFilter,
                onChanged: (value) {
                  Navigator.pop(context);
                  _updateDayFilter(value!);
                },
              ),
            ),
            ListTile(
              title: const Text('Last Year'),
              leading: Radio<int>(
                value: 365,
                groupValue: _currentDayFilter,
                onChanged: (value) {
                  Navigator.pop(context);
                  _updateDayFilter(value!);
                },
              ),
            ),
            ListTile(
              title: const Text('All Time'),
              leading: Radio<int>(
                value: 0,
                groupValue: _currentDayFilter,
                onChanged: (value) {
                  Navigator.pop(context);
                  _updateDayFilter(value!);
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

  // Add voice search functionality
  void _startVoiceSearch() async {
    try {
      // This would normally use a speech recognition package
      // For now, we'll just show a dialog to simulate the feature
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Voice Search'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mic, size: 50, color: Colors.deepPurple),
              const SizedBox(height: 16),
              const Text('Listening...'),
              const SizedBox(height: 24),
              const Text('Say the name of a link or category'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
          ],
        ),
      );

      if (result != null) {
        _searchLinks(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Voice search not available: $e')),
        );
      }
    }
  }

  // Build categories folder view
  Widget _buildCategoriesView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Get all categories from links
    final Map<String, List<Link>> categorizedLinks = {};

    for (final link in _links) {
      final category = link.category ?? 'Uncategorized';
      if (!categorizedLinks.containsKey(category)) {
        categorizedLinks[category] = [];
      }
      categorizedLinks[category]!.add(link);
    }

    if (categorizedLinks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade500
                  : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No categories yet',
              style: TextStyle(
                color:
                    Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add categories to your links to organize them',
              style: TextStyle(
                color:
                    Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Sort categories alphabetically, but keep 'Uncategorized' at the end
    final sortedCategories = categorizedLinks.keys.toList()
      ..sort((a, b) {
        if (a == 'Uncategorized') return 1;
        if (b == 'Uncategorized') return -1;
        return a.compareTo(b);
      });

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: sortedCategories.length,
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        final category = sortedCategories[index];
        final links = categorizedLinks[category]!;
        final categoryColor = _getCategoryColor(category);

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CategoryDetailScreen(
                  category: category,
                  links: links,
                  color: categoryColor,
                ),
              ),
            ).then((_) => _loadData());
          },
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Icon(
                    _getCategoryIcon(category),
                    size: 30,
                    color: categoryColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  category,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${links.length} link${links.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper to get category icon
  IconData _getCategoryIcon(String category) {
    final Map<String, IconData> categoryIcons = {
      'YouTube': Icons.video_library,
      'Instagram': Icons.photo_camera,
      'Twitter': Icons.chat,
      'Facebook': Icons.facebook,
      'Shopping': Icons.shopping_cart,
      'News': Icons.article,
      'Education': Icons.school,
      'Work': Icons.work,
      'Personal': Icons.person,
      'Uncategorized': Icons.folder_outlined,
    };

    return categoryIcons[category] ?? Icons.link;
  }

  // Helper to get category color
  Color _getCategoryColor(String category) {
    final Map<String, Color> categoryColors = {
      'YouTube': Colors.red.shade400,
      'Instagram': Colors.purple.shade400,
      'Twitter': Colors.blue.shade400,
      'Facebook': Colors.indigo.shade400,
      'Shopping': Colors.green.shade400,
      'News': Colors.orange.shade400,
      'Education': Colors.teal.shade400,
      'Work': Colors.blueGrey.shade400,
      'Personal': Colors.pink.shade400,
      'Uncategorized': Colors.grey.shade400,
    };

    return categoryColors[category] ?? Colors.deepPurple.shade400;
  }
}

// Category Detail Screen class
class CategoryDetailScreen extends StatefulWidget {
  final String category;
  final List<Link> links;
  final Color color;

  const CategoryDetailScreen({
    Key? key,
    required this.category,
    required this.links,
    required this.color,
  }) : super(key: key);

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  final LinkService _linkService = LinkService();
  List<Link> _links = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _links = widget.links;
  }

  Future<void> _deleteLink(Link link) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _linkService.deleteLink(link.id);
      setState(() {
        _links.removeWhere((l) => l.id == link.id);
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${link.title} deleted'),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () async {
                await _linkService.addLink(link);
                setState(() {
                  _links.add(link);
                });
              },
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting link: $e')),
        );
      }
    }
  }

  Future<void> _toggleFavorite(Link link) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _linkService.toggleFavorite(link.id);
      final index = _links.indexWhere((l) => l.id == link.id);
      if (index != -1) {
        setState(() {
          _links[index] = _links[index].copyWith(isFavorite: !link.isFavorite);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating favorite: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
        backgroundColor: widget.color.withOpacity(0.2),
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _links.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 64,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade500
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No links in this category',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onBackground
                              .withOpacity(0.7),
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _links.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final link = _links[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: link.color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.link, color: link.color),
                        ),
                        title: Text(
                          link.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          link.url,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                link.isFavorite
                                    ? Icons.star
                                    : Icons.star_border,
                                color: link.isFavorite
                                    ? Colors.amber
                                    : Colors.grey,
                              ),
                              onPressed: () => _toggleFavorite(link),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () => _deleteLink(link),
                            ),
                          ],
                        ),
                        onTap: () {
                          final uri = Uri.parse(link.url);
                          launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

class LinkSearchDelegate extends SearchDelegate<String> {
  final List<Link> links;
  final Function(String) onLinkSelected;

  LinkSearchDelegate({required this.links, required this.onLinkSelected});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final filteredLinks = links
        .where((link) =>
            link.title.toLowerCase().contains(query.toLowerCase()) ||
            link.url.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: filteredLinks.length,
      itemBuilder: (context, index) {
        final link = filteredLinks[index];
        return ListTile(
          title: Text(link.title),
          subtitle: Text(link.url),
          leading: CircleAvatar(
            backgroundColor: link.color,
            child: const Icon(Icons.link, color: Colors.white),
          ),
          onTap: () {
            onLinkSelected(link.url);
            close(context, link.url);
          },
        );
      },
    );
  }
}
