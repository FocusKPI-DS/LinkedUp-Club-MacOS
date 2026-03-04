import sys
import re

def balanced_braces(text, start_idx):
    """Find the index of the closing parenthesis/brace/bracket based on the opening one at start_idx."""
    stack = []
    pairs = {'(': ')', '{': '}', '[': ']', '<': '>'}
    
    if text[start_idx] not in pairs:
        return -1
        
    start_char = text[start_idx]
    end_char = pairs[start_char]
    
    for i in range(start_idx, len(text)):
        if text[i] == start_char:
            stack.append(start_char)
        elif text[i] == end_char:
            stack.pop()
            if not stack:
                return i
    return -1

def modify_dart_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # --- 1. Add markAsUnread and isUnread to ChatEditWidget calls ---
    # Find all ChatEditWidget( and insert the properties based on the chat variable
    
    # Let's find each ChatEditWidget(
    idx = 0
    while True:
        idx = content.find("ChatEditWidget(", idx)
        if idx == -1:
            break
            
        # Find the end of this ChatEditWidget call
        end_idx = balanced_braces(content, idx + 14)
        if end_idx == -1:
            idx += 1
            continue
            
        widget_code = content[idx:end_idx+1]
        
        # Determine the variable name used for the chat. Look for `await <var>.reference.update` inside actionEdit
        match = re.search(r'await\s+([a-zA-Z0-9_]+)\.reference\.update', widget_code)
        if match:
            var_name = match.group(1)
            
            # Add isUnread and markAsUnread to the arguments
            # Find a good place to insert (after isPin, or actionEdit)
            insert_str = f"""
                isUnread: _isManuallyUnread({var_name}),
                markAsUnread: () async {{
                    _toggleMarkUnread({var_name});
                }},
            """
            
            # Avoid inserting twice
            if "markAsUnread:" not in widget_code:
                # We can just insert it before the closing parenthesis of ChatEditWidget(
                # Look for the last comma before the end
                last_comma = widget_code.rfind(',')
                if last_comma != -1:
                    new_widget_code = widget_code[:last_comma+1] + insert_str + widget_code[last_comma+1:]
                else:
                    new_widget_code = widget_code[:-1] + "," + insert_str + ")"
                
                content = content[:idx] + new_widget_code + content[end_idx+1:]
                # Update idx to continue after the replaced text
                idx += len(new_widget_code)
            else:
                idx += len(widget_code)
        else:
            idx += len(widget_code)

    # --- 2. Copy Tab 1 to Tab 4 (Unread) ---
    
    # The tabs are inside the TabBarView children
    # Find TabBarView(
    tabbar_idx = content.find("TabBarView(")
    if tabbar_idx == -1:
        print("Error: Could not find TabBarView")
        return
        
    children_idx = content.find("children:", tabbar_idx)
    if children_idx == -1:
        print("Error: Could not find children array in TabBarView")
        return
        
    bracket_idx = content.find("[", children_idx)
    if bracket_idx == -1:
        print("Error: Could not find [ after children:")
        return
        
    tabbarview_end_idx = balanced_braces(content, bracket_idx)
    
    children_content = content[bracket_idx+1:tabbarview_end_idx]
    
    # We need to find the 3 KeepAliveWidgetWrapper tabs.
    # The first KeepAliveWidgetWrapper starts at KeepAliveWidgetWrapper(
    tab1_start = children_content.find("KeepAliveWidgetWrapper(")
    if tab1_start == -1:
        print("Error: Could not find first KeepAliveWidgetWrapper")
        return
        
    tab1_end = balanced_braces(children_content, tab1_start + 22)
    tab1_content = children_content[tab1_start:tab1_end+1]
    
    # Now we need to modify tab1_content for Tab 4 (Unread)
    # We want to change the filter to only include unread chats.
    # Tab 1 has two query parts:
    # 1. chatChatsRecordList.where((e) => e.isPin == true)
    # 2. chatChatsRecordList.where((e) => e.isPin == false)
    # We will change them to check _hasUnreadBadge(e) as well.
    tab4_content = tab1_content.replace(
        "chatChatsRecordList.where((e) => e.isPin == true)",
        "chatChatsRecordList.where((e) => e.isPin == true && _hasUnreadBadge(e))"
    ).replace(
        "chatChatsRecordList.where((e) => e.isPin == false)",
        "chatChatsRecordList.where((e) => e.isPin == false && _hasUnreadBadge(e))"
    ).replace(
        "Chat's All Empty",
        "No Unread Chats"
    )
    
    # Also change the variable names just to avoid any shadow warnings (although Builder isolates them)
    tab4_content = tab4_content.replace("allChatPin", "unreadChatPin")
    tab4_content = tab4_content.replace("allChatAll", "unreadChatAll")
    
    # Now we need to append tab4_content to the children list.
    # Find the end of Tab 3 (which is the last KeepAliveWidgetWrapper)
    # To be safe, we can just insert tab4_content right before the end bracket of children bracket_idx+1 to tabbarview_end_idx.
    # The last child is the 3rd KeepAliveWidgetWrapper.
    # Let's just find the last KeepAliveWidgetWrapper
    
    # Actually, we can just append it right before tabbarview_end_idx
    # Make sure we add a comma after the last child if there isn't one
    # We will insert it at tabbarview_end_idx.
    # Check if there is a trailing comma before the closing brace
    preceding_char_idx = tabbarview_end_idx - 1
    while preceding_char_idx > bracket_idx and content[preceding_char_idx].isspace():
        preceding_char_idx -= 1
        
    if content[preceding_char_idx] != ',':
        insertion = ",\n" + tab4_content + "\n"
    else:
        insertion = "\n" + tab4_content + ",\n"
        
    new_content = content[:tabbarview_end_idx] + insertion + content[tabbarview_end_idx:]
    
    with open(filepath, 'w') as f:
        f.write(new_content)
        
    print("Successfully modified dart file")

if __name__ == "__main__":
    modify_dart_file("lib/pages/chat/chat/chat_widget.dart")
