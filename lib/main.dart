
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const PersonalContactsApp());
}

// --------------------------------------------------
// APP
// --------------------------------------------------

class PersonalContactsApp extends StatelessWidget {
  const PersonalContactsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Contacts',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF6F7FB),
        ),
      ),
      home: const ContactsHomePage(),
    );
  }
}

// --------------------------------------------------
// PERSISTENT FAVORITES AND BLOCKED CONTACTS
// --------------------------------------------------

class ContactPreferences {
  static const String _favoritesKey = 'favorite_contact_ids';
  static const String _blockedKey = 'blocked_contact_ids';

  static Future<Set<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_favoritesKey) ?? []).toSet();
  }

  static Future<Set<String>> getBlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_blockedKey) ?? []).toSet();
  }

  static Future<void> setFavorite(
    String id,
    bool isFavorite,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(_favoritesKey) ?? []).toSet();

    if (isFavorite) {
      ids.add(id);
    } else {
      ids.remove(id);
    }

    await prefs.setStringList(_favoritesKey, ids.toList());
  }

  static Future<void> setBlocked(
    String id,
    bool isBlocked,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(_blockedKey) ?? []).toSet();

    if (isBlocked) {
      ids.add(id);
    } else {
      ids.remove(id);
    }

    await prefs.setStringList(_blockedKey, ids.toList());
  }

  static Future<void> removeContact(String id) async {
    await setFavorite(id, false);
    await setBlocked(id, false);
  }
}

// --------------------------------------------------
// CONTACT LIST SCREEN
// --------------------------------------------------

class ContactsHomePage extends StatefulWidget {
  const ContactsHomePage({super.key});

  @override
  State<ContactsHomePage> createState() => _ContactsHomePageState();
}

class _ContactsHomePageState extends State<ContactsHomePage> {
  List<Contact> contacts = [];
  Set<String> favoriteIds = {};
  Set<String> blockedIds = {};

  bool isLoading = true;
  String searchQuery = '';
  String selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    loadContacts();
  }

  Future<void> loadContacts() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final permission = await FlutterContacts.permissions.request(
        PermissionType.readWrite,
      );

      if (permission != PermissionStatus.granted) {
        if (!mounted) return;

        setState(() {
          contacts = [];
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please allow contacts permission.'),
          ),
        );
        return;
      }

      final result = await FlutterContacts.getAll(
        properties: {
          ContactProperty.name,
          ContactProperty.phone,
        },
      );

      result.sort(
        (a, b) => (a.displayName ?? '')
            .toLowerCase()
            .compareTo((b.displayName ?? '').toLowerCase()),
      );

      final favorites = await ContactPreferences.getFavorites();
      final blocked = await ContactPreferences.getBlocked();

      if (!mounted) return;

      setState(() {
        contacts = result;
        favoriteIds = favorites;
        blockedIds = blocked;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load contacts: $e')),
      );
    }
  }

  List<Contact> get visibleContacts {
    final query = searchQuery.trim().toLowerCase();

    return contacts.where((contact) {
      final id = contact.id ?? '';
      final name = (contact.displayName ?? '').toLowerCase();
      final numbers = contact.phones
          .map((phone) => phone.number.toLowerCase())
          .join(' ');

      final matchesSearch =
          query.isEmpty || name.contains(query) || numbers.contains(query);

      final matchesFilter = switch (selectedFilter) {
        'Favorites' => favoriteIds.contains(id),
        'Blocked' => blockedIds.contains(id),
        _ => true,
      };

      return matchesSearch && matchesFilter;
    }).toList();
  }

  Future<void> openAddContact() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const ContactEditorPage(),
      ),
    );

    if (added == true) {
      await loadContacts();
    }
  }

  Future<void> openContactDetails(Contact contact) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ContactDetailsPage(contact: contact),
      ),
    );

    await loadContacts();
  }

  @override
  Widget build(BuildContext context) {
    final visible = visibleContacts;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Contacts',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            Text(
              'Your personal address book',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh contacts',
            onPressed: loadContacts,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: TextField(
              onChanged: (value) {
                setState(() => searchQuery = value);
              },
              decoration: InputDecoration(
                hintText: 'Search name or phone number',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _filterChip('All'),
                const SizedBox(width: 8),
                _filterChip('Favorites'),
                const SizedBox(width: 8),
                _filterChip('Blocked'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(
              children: [
                Text(
                  selectedFilter == 'All'
                      ? 'All Contacts'
                      : selectedFilter,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${visible.length} contacts',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              selectedFilter == 'Blocked'
                                  ? Icons.block
                                  : Icons.contacts_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              searchQuery.isNotEmpty
                                  ? 'No matching contacts'
                                  : selectedFilter == 'Blocked'
                                      ? 'No blocked contacts'
                                      : selectedFilter == 'Favorites'
                                          ? 'No favorite contacts yet'
                                          : 'No contacts found',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: loadContacts,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final contact = visible[index];
                            final id = contact.id ?? '';
                            final name =
                                contact.displayName?.trim().isNotEmpty == true
                                    ? contact.displayName!
                                    : 'Unnamed Contact';
                            final phone = contact.phones.isNotEmpty
                                ? contact.phones.first.number
                                : 'No phone number';
                            final isFavorite = favoriteIds.contains(id);
                            final isBlocked = blockedIds.contains(id);

                            return Card(
                              color: Colors.white,
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 5,
                                ),
                                leading: ContactAvatar(name: name),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (isFavorite)
                                      const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                        size: 19,
                                      ),
                                    if (isBlocked)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 5),
                                        child: Icon(
                                          Icons.block,
                                          color: Colors.red,
                                          size: 19,
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  isBlocked ? '$phone  •  Blocked in app' : phone,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isBlocked ? Colors.red : null,
                                  ),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => openContactDetails(contact),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openAddContact,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Contact'),
      ),
    );
  }

  Widget _filterChip(String label) {
    return ChoiceChip(
      label: Text(label),
      selected: selectedFilter == label,
      onSelected: (_) => setState(() => selectedFilter = label),
    );
  }
}

// --------------------------------------------------
// CONTACT DETAILS SCREEN
// --------------------------------------------------

class ContactDetailsPage extends StatefulWidget {
  final Contact contact;

  const ContactDetailsPage({
    super.key,
    required this.contact,
  });

  @override
  State<ContactDetailsPage> createState() => _ContactDetailsPageState();
}

class _ContactDetailsPageState extends State<ContactDetailsPage> {
  late Contact currentContact;
  bool isFavorite = false;
  bool isBlocked = false;
  bool isLoadingPreferences = true;

  @override
  void initState() {
    super.initState();
    currentContact = widget.contact;
    loadContactPreferences();
  }

  Future<void> loadContactPreferences() async {
    final id = currentContact.id;
    if (id == null || id.isEmpty) {
      if (mounted) setState(() => isLoadingPreferences = false);
      return;
    }

    final favorites = await ContactPreferences.getFavorites();
    final blocked = await ContactPreferences.getBlocked();

    if (!mounted) return;

    setState(() {
      isFavorite = favorites.contains(id);
      isBlocked = blocked.contains(id);
      isLoadingPreferences = false;
    });
  }

  Future<void> toggleFavorite() async {
    final id = currentContact.id;
    if (id == null || id.isEmpty) return;

    final newValue = !isFavorite;

    try {
      await ContactPreferences.setFavorite(id, newValue);
      if (!mounted) return;

      setState(() => isFavorite = newValue);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newValue
                ? 'Added to favorites.'
                : 'Removed from favorites.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update favorite: $e')),
      );
    }
  }

  Future<void> toggleBlocked() async {
    final id = currentContact.id;
    if (id == null || id.isEmpty) return;

    final newValue = !isBlocked;
    final name = currentContact.displayName?.trim().isNotEmpty == true
        ? currentContact.displayName!
        : 'this contact';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(newValue ? 'Block contact?' : 'Unblock contact?'),
        content: Text(
          newValue
              ? 'Block $name inside this app? The app will stop opening its '
                  'Call and Message actions for this contact. This does not '
                  'block calls or SMS in your phone system.'
              : 'Allow the app to open Call and Message actions for $name again?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: newValue ? Colors.red : Colors.indigo,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(newValue ? 'Block' : 'Unblock'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ContactPreferences.setBlocked(id, newValue);
      if (!mounted) return;

      setState(() => isBlocked = newValue);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newValue
                ? '$name has been blocked in this app.'
                : '$name has been unblocked in this app.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update blocked status: $e')),
      );
    }
  }

  Future<void> editContact() async {
    final id = currentContact.id;

    if (id == null || id.trim().isEmpty) {
      _showMessage('This contact has no ID and cannot be edited.');
      return;
    }

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ContactEditorPage(contactId: id),
      ),
    );

    if (updated == true && mounted) {
      try {
        final refreshed = await FlutterContacts.get(
          id,
          properties: ContactProperties.all,
        );

        if (refreshed != null && mounted) {
          setState(() => currentContact = refreshed);
        }
      } catch (e) {
        _showMessage('Could not refresh contact: $e');
      }
    }
  }

  Future<void> deleteContact() async {
    final id = currentContact.id;

    if (id == null || id.trim().isEmpty) {
      _showMessage('This contact has no ID and cannot be deleted.');
      return;
    }

    final name = currentContact.displayName?.trim().isNotEmpty == true
        ? currentContact.displayName!
        : 'this contact';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete contact?'),
        content: Text(
          'Are you sure you want to delete "$name" from your phone contacts? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final permission = await FlutterContacts.permissions.request(
        PermissionType.readWrite,
      );

      if (permission != PermissionStatus.granted) {
        _showMessage('Contacts permission is required to delete contacts.');
        return;
      }

      await FlutterContacts.delete(id);
      await ContactPreferences.removeContact(id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact deleted successfully.')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      _showMessage('Failed to delete contact: $e');
    }
  }

  Future<void> openPhoneApp(
    String number, {
    required bool sendMessage,
  }) async {
    if (isBlocked) {
      _showMessage(
        'This contact is blocked in the app. Unblock it before '
        'using Call or Message.',
      );
      return;
    }

    if (number.trim().isEmpty) {
      _showMessage('This contact has no phone number.');
      return;
    }

    final uri = sendMessage
        ? Uri(scheme: 'sms', path: number)
        : Uri(scheme: 'tel', path: number);

    try {
      final launched = await launchUrl(uri);

      if (!launched && mounted) {
        _showMessage(
          sendMessage
              ? 'Could not open the messaging app.'
              : 'Could not open the phone app.',
        );
      }
    } catch (e) {
      _showMessage('Could not open app: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = currentContact.displayName?.trim().isNotEmpty == true
        ? currentContact.displayName!
        : 'Unnamed Contact';

    final phoneNumbers = currentContact.phones;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Details'),
        actions: [
          IconButton(
            tooltip: 'Edit contact',
            onPressed: editContact,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete contact',
            onPressed: deleteContact,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(child: ContactAvatar(name: name, size: 100)),
            const SizedBox(height: 18),
            Center(
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isBlocked) ...[
              const SizedBox(height: 12),
              const Center(
                child: Chip(
                  avatar: Icon(Icons.block, color: Colors.red),
                  label: Text('Blocked in this app'),
                  side: BorderSide(color: Colors.red),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // FAVORITE AND BLOCK CONTROLS
            Card(
              color: Colors.white,
              elevation: 0,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      isFavorite ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    title: Text(
                      isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: isLoadingPreferences ? null : toggleFavorite,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      isBlocked ? Icons.lock_open : Icons.block,
                      color: isBlocked ? Colors.indigo : Colors.red,
                    ),
                    title: Text(
                      isBlocked ? 'Unblock Contact' : 'Block Contact',
                      style: TextStyle(
                        color: isBlocked ? Colors.indigo : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      isBlocked
                          ? 'Allow Call and Message actions again'
                          : 'Prevent Call and Message actions in this app',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: isLoadingPreferences ? null : toggleBlocked,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (phoneNumbers.isEmpty)
              const Card(
                color: Colors.white,
                elevation: 0,
                child: ListTile(
                  leading: Icon(Icons.phone_outlined),
                  title: Text('No phone number saved'),
                ),
              )
            else
              ...phoneNumbers.map(
                (phone) => Card(
                  color: Colors.white,
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Phone Number',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          phone.number,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: isBlocked
                                    ? null
                                    : () => openPhoneApp(
                                          phone.number,
                                          sendMessage: false,
                                        ),
                                icon: const Icon(Icons.call),
                                label: const Text('Call'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isBlocked
                                    ? null
                                    : () => openPhoneApp(
                                          phone.number,
                                          sendMessage: true,
                                        ),
                                icon: const Icon(Icons.message_outlined),
                                label: const Text('Message'),
                              ),
                            ),
                          ],
                        ),
                        if (isBlocked) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Call and Message are disabled while this '
                            'contact is blocked in the app.',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------
// ADD / EDIT CONTACT SCREEN
// --------------------------------------------------

class ContactEditorPage extends StatefulWidget {
  final String? contactId;

  const ContactEditorPage({super.key, this.contactId});

  @override
  State<ContactEditorPage> createState() => _ContactEditorPageState();
}

class _ContactEditorPageState extends State<ContactEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool isLoading = false;
  bool isSaving = false;

  bool get isEditing => widget.contactId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) loadContactForEditing();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> loadContactForEditing() async {
    setState(() => isLoading = true);

    try {
      final permission = await FlutterContacts.permissions.request(
        PermissionType.readWrite,
      );

      if (permission != PermissionStatus.granted) {
        throw Exception('Contacts permission was not granted.');
      }

      final contact = await FlutterContacts.get(
        widget.contactId!,
        properties: ContactProperties.all,
      );

      if (contact == null) {
        throw Exception('The contact could not be found.');
      }

      _firstNameController.text = contact.name?.first ?? '';
      _lastNameController.text = contact.name?.last ?? '';
      _phoneController.text =
          contact.phones.isNotEmpty ? contact.phones.first.number : '';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load contact: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> saveContact() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      final permission = await FlutterContacts.permissions.request(
        PermissionType.readWrite,
      );

      if (permission != PermissionStatus.granted) {
        throw Exception('Contacts permission was not granted.');
      }

      final first = _firstNameController.text.trim();
      final last = _lastNameController.text.trim();
      final number = _phoneController.text.trim();

      if (isEditing) {
        final id = widget.contactId!.trim();

        final contact = await FlutterContacts.get(
          id,
          properties: ContactProperties.all,
        );

        if (contact == null) {
          throw Exception('The original contact could not be found.');
        }

        final updatedPhones = <Phone>[];

        if (contact.phones.isEmpty) {
          updatedPhones.add(Phone(number: number));
        } else {
          for (var i = 0; i < contact.phones.length; i++) {
            if (i == 0) {
              updatedPhones.add(contact.phones[i].copyWith(number: number));
            } else {
              updatedPhones.add(contact.phones[i]);
            }
          }
        }

        final updatedContact = contact.copyWith(
          id: id,
          name: Name(first: first, last: last),
          phones: updatedPhones,
        );

        await FlutterContacts.update(updatedContact);

        final saved = await FlutterContacts.get(
          id,
          properties: ContactProperties.all,
        );

        if (saved == null) {
          throw Exception('Could not verify the saved contact.');
        }
      } else {
        final newContact = Contact(
          name: Name(first: first, last: last),
          phones: [Phone(number: number)],
        );

        await FlutterContacts.create(newContact);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Contact updated successfully!'
                : 'Contact saved successfully!',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Failed to update contact: $e'
                : 'Failed to save contact: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Contact' : 'Add New Contact'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    CircleAvatar(
                      radius: 45,
                      backgroundColor: const Color(0xFFE0E7FF),
                      child: Icon(
                        isEditing
                            ? Icons.edit_outlined
                            : Icons.person_add_alt_1,
                        size: 42,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _firstNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a first name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Last Name (Optional)',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: isSaving ? null : saveContact,
                        icon: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          isSaving
                              ? 'Saving...'
                              : isEditing
                                  ? 'Save Changes'
                                  : 'Save Contact',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// --------------------------------------------------
// REUSABLE CONTACT AVATAR
// --------------------------------------------------

class ContactAvatar extends StatelessWidget {
  final String name;
  final double size;

  const ContactAvatar({
    super.key,
    required this.name,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    var initials = '?';

    if (words.isNotEmpty) {
      initials = words.first[0].toUpperCase();
      if (words.length > 1) {
        initials += words.last[0].toUpperCase();
      }
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.indigo.shade100,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.indigo.shade800,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.32,
        ),
      ),
    );
  }
}
