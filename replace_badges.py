import sys
import re

def modify_dart_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Find all instances where we check if a user has NOT seen the message
    # Examples:
    # if (allChatPinItem.lastMessageSeen.contains(currentUserReference) == false)
    # visible: !allChatPinItem.lastMessageSeen.contains(currentUserReference)
    
    # We will replace these specific patterns:
    # 1. `if (VAR.lastMessageSeen.contains(currentUserReference) == false)` -> `if (_hasUnreadBadge(VAR))`
    # 2. `visible: !VAR.lastMessageSeen.contains(currentUserReference)` -> `visible: _hasUnreadBadge(VAR)`
    
    # Regex 1
    content = re.sub(
        r'if\s*\(\s*([a-zA-Z0-9_]+)\.lastMessageSeen\.contains\(currentUserReference\)\s*==\s*false\s*\)',
        r'if (_hasUnreadBadge(\1))',
        content
    )
    
    # Regex 2
    content = re.sub(
        r'visible:\s*!\s*([a-zA-Z0-9_]+)\.lastMessageSeen\.contains\(currentUserReference\)',
        r'visible: _hasUnreadBadge(\1)',
        content
    )
    
    # Also handle the checkmark (read receipt) case, which should NOT be unread
    # else if ((VAR.lastMessageSeen.contains(currentUserReference) == true) && (VAR.lastMessageSent == currentUserReference))
    content = re.sub(
        r'else\s+if\s*\(\s*\(\s*([a-zA-Z0-9_]+)\.lastMessageSeen\.contains\(currentUserReference\)\s*==\s*true\s*\)\s*&&\s*\([a-zA-Z0-9_]+\.lastMessageSent\s*==\s*currentUserReference\)\s*\)',
        r'else if (!_hasUnreadBadge(\1) && (\1.lastMessageSent == currentUserReference))',
        content
    )

    with open(filepath, 'w') as f:
        f.write(content)
        
    print("Successfully replaced badge logic")

if __name__ == "__main__":
    modify_dart_file("lib/pages/chat/chat/chat_widget.dart")
