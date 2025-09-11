import 'package:flutter/material.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../main.dart';
import 'settings.dart';

/// A side navigation bar that displays a list of chat sessions and provides
/// actions for managing them.
class SideNav extends StatefulWidget {
  /// A callback function that is called when the user creates a new chat.
  final VoidCallback onNewChat;

  /// Whether the navigation bar is expanded.
  final bool isExpanded;

  /// Whether the navigation bar is pinned open.
  final bool isPinned;

  /// A callback function that is called when the user toggles the pin state.
  final VoidCallback onToggle;

  /// The list of chat sessions to display.
  final List<ArcadiaChat> chatList;

  /// A callback function that is called when the user selects a chat.
  final Function(ArcadiaChat) onChatSelected;

  /// A callback function that is called when the user deletes a chat.
  final Function(ArcadiaChat) onDeleteChat;

  /// A callback function that is called when the user archives a chat.
  final Function(ArcadiaChat) onArchiveChat;

  /// A callback function that is called when the user renames a chat.
  final Function(ArcadiaChat, String) onRenameChat;

  /// A callback function that is called when the user exports a chat.
  final Function(ArcadiaChat) onExportChat;

  /// The currently selected chat session.
  final ArcadiaChat? selectedChat;

  const SideNav({
    super.key,
    required this.onNewChat,
    required this.isExpanded,
    required this.isPinned,
    required this.onToggle,
    required this.chatList,
    required this.onChatSelected,
    required this.onDeleteChat,
    required this.onArchiveChat,
    required this.onRenameChat,
    required this.onExportChat,
    this.selectedChat,
  });

  @override
  State<SideNav> createState() => _SideNavState();
}

class _SideNavState extends State<SideNav> {
  /// Shows a dialog for renaming a chat session.
  void _showRenameDialog(ArcadiaChat chat) {
    final controller = TextEditingController(text: chat.title);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Chat'),
          content: SizedBox(
            width: 250,
            child: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 1,
              onSubmitted: (value) {
                widget.onRenameChat(chat, controller.text);
                Navigator.of(context).pop();
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                widget.onRenameChat(chat, controller.text);
                Navigator.of(context).pop();
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // The main container for the side navigation bar.
    return AnimatedContainer(
      duration: 200.ms,
      width: widget.isExpanded ? 280 : 74,
      color: theme.colorScheme.surfaceContainerLowest,
      child: ClipRect(
        // Use an OverflowBox to ensure the content doesn't get clipped during animation.
        child: OverflowBox(
          minWidth: 280,
          maxWidth: 280,
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The button for pinning the sidebar.
                IconButton(
                  icon: AnimatedRotation(
                    duration: 200.ms,
                    turns: widget.isPinned ? 0.0 : 0.25,
                    child: Icon(
                      widget.isPinned
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                    ),
                  ),
                  onPressed: widget.onToggle,
                ),
                const SizedBox(height: 10),
                // The button for creating a new chat.
                CustomNavButton(
                  isExpanded: widget.isExpanded,
                  onPressed: widget.onNewChat,
                  icon: Icons.rate_review_outlined,
                  label: "New Chat",
                  backgroundColor: theme.colorScheme.tertiaryContainer,
                  foregroundColor: theme.colorScheme.onTertiaryContainer,
                ),
                // The list of recent chats, which is only visible when expanded.
                if (widget.isExpanded) ...[
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 4),
                    child: Text("Recent", style: theme.textTheme.titleMedium),
                  ),
                  Expanded(
                    child: Material(
                      type: MaterialType.transparency,
                      child: ListView.separated(
                        itemCount: widget.chatList.length,
                        itemBuilder: (context, index) {
                          final chat = widget.chatList[index];
                          final isSelected = widget.selectedChat?.id == chat.id;
                          return ChatListTile(
                            chat: chat,
                            isSelected: isSelected,
                            onTap: () => widget.onChatSelected(chat),
                            onRename: () => _showRenameDialog(chat),
                            onArchive: () => widget.onArchiveChat(chat),
                            onDelete: () => widget.onDeleteChat(chat),
                            onExport: () => widget.onExportChat(chat),
                          );
                        },
                        separatorBuilder: (context, index) {
                          return const SizedBox(height: 4);
                        },
                      ),
                    ),
                  ),
                ] else ...[
                  const Spacer(),
                ],
                // A divider to separate the main content from the settings button.
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  height: 1,
                  width: widget.isExpanded ? 280 - 32 : 80 - 32,
                  color: theme.dividerColor,
                ),
                // The button for opening the settings page.
                CustomNavButton(
                  isExpanded: widget.isExpanded,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SettingsPage(),
                      ),
                    );
                  },
                  icon: Icons.settings,
                  label: "Settings",
                  foregroundColor: theme.textTheme.titleSmall!.color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A list tile that represents a single chat session in the side navigation.
class ChatListTile extends StatefulWidget {
  /// The chat session to display.
  final ArcadiaChat chat;

  /// Whether the tile is currently selected.
  final bool isSelected;

  /// A callback function that is called when the tile is tapped.
  final VoidCallback onTap;

  /// A callback function that is called when the user chooses to rename the chat.
  final VoidCallback onRename;

  /// A callback function that is called when the user chooses to archive the chat.
  final VoidCallback onArchive;

  /// A callback function that is called when the user chooses to delete the chat.
  final VoidCallback onDelete;

  /// A callback function that is called when the user chooses to export the chat.
  final VoidCallback onExport;

  const ChatListTile({
    super.key,
    required this.chat,
    required this.isSelected,
    required this.onTap,
    required this.onRename,
    required this.onArchive,
    required this.onDelete,
    required this.onExport,
  });

  @override
  State<ChatListTile> createState() => _ChatListTileState();
}

class _ChatListTileState extends State<ChatListTile> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showPopupMenu = _isHovering || widget.isSelected;

    final Color? bgColor = widget.isSelected
        ? theme.colorScheme.onPrimary
        : null;
    final Color? fgColor = widget.isSelected ? theme.colorScheme.primary : null;

    // Use a MouseRegion to detect when the user is hovering over the tile.
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: ListTile(
        leading: const Icon(Icons.chat_bubble_rounded, size: 18),
        title: Text(
          widget.chat.title,
          style: const TextStyle(
            fontVariations: [FontVariation('wght', 500.0)],
          ),
        ),
        onTap: widget.onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        hoverColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        selected: widget.isSelected,
        selectedTileColor: theme.colorScheme.onPrimary,
        horizontalTitleGap: 8,
        contentPadding: const EdgeInsets.only(left: 16, right: 8),
        // The popup menu button for chat actions.
        trailing: AnimatedOpacity(
          opacity: showPopupMenu ? 1.0 : 0.0,
          duration: 200.ms,
          child: PopupMenuButton<String>(
            offset: const Offset(40, 0),
            menuPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            clipBehavior: Clip.antiAlias,
            color: bgColor,
            onSelected: (value) {
              if (value == 'rename') {
                widget.onRename();
              } else if (value == 'archive') {
                widget.onArchive();
              } else if (value == 'delete') {
                widget.onDelete();
              } else if (value == 'export') {
                widget.onExport();
              }
            },
            itemBuilder: (context) => [
              // The "Rename" menu item.
              PopupMenuItem(
                value: 'rename',
                child: Row(
                  spacing: 12,
                  children: <Widget>[
                    const Icon(Icons.drive_file_rename_outline),
                    Text('Rename', style: TextStyle(color: fgColor)),
                  ],
                ),
              ),
              // The "Archive" menu item.
              PopupMenuItem(
                value: 'archive',
                child: Row(
                  spacing: 12,
                  children: <Widget>[
                    const Icon(Icons.archive_outlined),
                    Text('Archive', style: TextStyle(color: fgColor)),
                  ],
                ),
              ),
              // The "Delete" menu item.
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  spacing: 12,
                  children: <Widget>[
                    const Icon(Icons.delete_outline),
                    Text('Delete', style: TextStyle(color: fgColor)),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 3, indent: 10, endIndent: 10),
              // The "Export" menu item.
              PopupMenuItem(
                value: 'export',
                child: Row(
                  spacing: 12,
                  children: <Widget>[
                    const Icon(Icons.download),
                    Text('Export', style: TextStyle(color: fgColor)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A custom navigation button used in the side navigation bar.
class CustomNavButton extends StatelessWidget {
  /// Whether the button is in an expanded state.
  final bool isExpanded;

  /// A callback function that is called when the button is pressed.
  final VoidCallback onPressed;

  /// The icon to display on the button.
  final IconData icon;

  /// The label to display on the button when it is expanded.
  final String label;

  /// The background color of the button.
  final Color? backgroundColor;

  /// The foreground color of the button.
  final Color? foregroundColor;

  const CustomNavButton({
    super.key,
    required this.isExpanded,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: Size(isExpanded ? double.infinity : 48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          if (isExpanded) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontVariations: [FontVariation('wght', 550.0)],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
