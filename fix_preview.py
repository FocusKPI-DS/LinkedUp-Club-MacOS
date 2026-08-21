import re

file_path = "lib/pages/chat/chat/chat_widget.dart"

with open(file_path, "r") as f:
    content = f.read()

# We want to match places where lastMessage is used as a value inside valueOrDefault
# They usually look like:
# valueOrDefault<String>(
#     allChatPinItem.lastMessage,
#
# But there might be places where we don't want to replace, like:
# .lastMessage == ''

old_count = content.count('.lastMessage,')

# Pattern: any word ending with Item.lastMessage,
new_content = re.sub(
    r'(\w+Item)\.lastMessage,',
    r"\1.lastMessage.replaceAll(RegExp(r'\\[([^\\]]+)\\]\\([^)]+\\)'), r'$1'),",
    content
)

print(f"Replaced {old_count} -> {new_content.count('.replaceAll(RegExp')} occurrences")

with open(file_path, "w") as f:
    f.write(new_content)

