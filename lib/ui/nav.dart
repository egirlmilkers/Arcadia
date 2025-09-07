import 'package:flutter/material.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../main.dart';
import 'settings.dart';

class SideNav extends StatefulWidget {
  final VoidCallback onNewChat;
  final bool isExpanded;
  final bool isPinned;
  final VoidCallback onToggle;
  final List<ChatSession> chatList;
  final Function(ChatSession) onChatSelected;
  final Function(ChatSession) onDeleteChat;
  final Function(ChatSession) onArchiveChat;
  final Function(ChatSession, String) onRenameChat;
  final ChatSession? selectedChat;

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
    this.selectedChat,
  });

  @override
  State<SideNav> createState() => _SideNavState();
}

class _SideNavState extends State<SideNav> {
  void _showRenameDialog(ChatSession chat) {
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
              maxLines: 1, // prevents wrapping
              // allows use of pressing enter
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

    return AnimatedContainer(
      duration: 200.ms,
      width: widget.isExpanded ? 280 : 74,
      color: theme.colorScheme.surfaceContainerLowest,
      child: ClipRect(
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
                CustomNavButton(
                  isExpanded: widget.isExpanded,
                  onPressed: widget.onNewChat,
                  icon: Icons.rate_review_outlined,
                  label: "New Chat",
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(height: 24),
                if (widget.isExpanded)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 8),
                    child: Text("Recent", style: theme.textTheme.titleSmall),
                  ),
                if (widget.isExpanded)
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
                          );
                        },
                        separatorBuilder: (context, index) {
                          return const SizedBox(height: 6);
                        }
                      ),
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  height: 1,
                  width: widget.isExpanded ? 280 - 32 : 80 - 32,
                  color: theme.dividerColor,
                ),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChatListTile extends StatefulWidget {
  final ChatSession chat;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const ChatListTile({
    super.key,
    required this.chat,
    required this.isSelected,
    required this.onTap,
    required this.onRename,
    required this.onArchive,
    required this.onDelete,
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

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: ListTile(
        leading: const Icon(Icons.chat_bubble_outline, size: 16),
        title: Text(widget.chat.title),
        onTap: widget.onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        hoverColor: theme.colorScheme.onPrimary.withValues(alpha: 0.5),
        selected: widget.isSelected,
        selectedTileColor: theme.colorScheme.onPrimary,
        horizontalTitleGap: 8,
        contentPadding: const EdgeInsets.only(left: 16, right: 8),
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
            onSelected: (value) {
              if (value == 'rename') {
                widget.onRename();
              } else if (value == 'archive') {
                widget.onArchive();
              } else if (value == 'delete') {
                widget.onDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'rename',
                child: Row(
                  spacing: 12,
                  children: <Widget>[
                    Icon(Icons.drive_file_rename_outline),
                    Text('Rename'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'archive',
                child: Row(
                  spacing: 12,
                  children: <Widget>[
                    Icon(Icons.archive_outlined),
                    Text('Archive'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  spacing: 12,
                  children: <Widget>[
                    Icon(Icons.delete_outline),
                    Text('Delete'),
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

class CustomNavButton extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color? backgroundColor;
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
          if (isExpanded) ...[const SizedBox(width: 8), Text(label)],
        ],
      ),
    );
  }
}
