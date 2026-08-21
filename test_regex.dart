void main() {
  final text = "@peter zhu @Hao Zhang I'd like to spend a few minutes align with you later today at our tb and we can start the development with a clearer goal faster. @Vertin For latest macos, when mentioning tab keeps poping";

  // Attempt to match names with optional second word
  // but prevent matching stop words or non-name structures
  
  final regexes = [
    r'(?:^|\s)@(?:linkai|"[^"]+"|[A-Za-z0-9_\u4e00-\u9fa5]+(?:\s+[A-Za-z0-9_\u4e00-\u9fa5]+)?)', // old greedy
    r'(?:^|\s)@(?:linkai|"[^"]+"|[A-Za-z0-9_\u4e00-\u9fa5]+)', // strict
    r'(?:^|\s)@(?:"[^"]+"|[A-Za-z0-9_\u4e00-\u9fa5]+(?:\s+[A-Z\u4e00-\u9fa5][A-Za-z0-9_\u4e00-\u9fa5]*| zhu)?)' // custom
  ];

  for (final r in regexes) {
    print("Regex: $r");
    final RegExp exp = RegExp(r);
    for (final match in exp.allMatches(text)) {
      print("  Matched: '${match.group(0)}'");
    }
  }
}
