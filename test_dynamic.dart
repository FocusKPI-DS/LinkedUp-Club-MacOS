void main() {
  final content = "@peter zhu @Hao Zhang I'd like to spend a few minutes align with you later today at our tb and we can start the development with a clearer goal faster. @Vertin For latest macos, when mentioning tab keeps poping @random";
  final mentionableUsers = ["peter zhu", "Hao Zhang", "Vertin"];

  final List<String> escapedUsers = mentionableUsers
      .where((u) => u.trim().isNotEmpty)
      .map((u) => RegExp.escape(u))
      .toList();
  // Sort by length descending, so "Peter Zhu" matches before "Peter"
  escapedUsers.sort((a, b) => b.length.compareTo(a.length));

  final parts = ['linkai'];
  if (escapedUsers.isNotEmpty) {
    parts.addAll(escapedUsers);
  }
  parts.add(r'"[^"]+"');
  parts.add(r'[A-Za-z0-9_\u4e00-\u9fa5]+');

  final RegExp mentionRegex = RegExp(
    '(?:^|\\s)@(?:${parts.join('|')})',
  );

  print("Regex: ${mentionRegex.pattern}");
  for (final match in mentionRegex.allMatches(content)) {
    print("Match: '${match.group(0)}'");
  }
}
