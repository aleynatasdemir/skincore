import os
import glob
import re

auth_dir = '/Users/aleyna/Desktop/skincore/skincore/skincore_native/app/(auth)'
files = glob.glob(os.path.join(auth_dir, '*.tsx'))

emoji_map = {
    '✉': '<Ionicons name="mail-outline" size={20} color="#9CA3AF" style={styles.inputIcon} />',
    '🔒': '<Ionicons name="lock-closed-outline" size={20} color="#9CA3AF" style={styles.inputIcon} />',
    '👤': '<Ionicons name="person-outline" size={20} color="#9CA3AF" style={styles.inputIcon} />',
    '⚠': '<Ionicons name="warning-outline" size={20} color={Colors.danger} />',
    '‹': '<Ionicons name="chevron-back" size={32} color={Colors.dark} />'
}

for f in files:
    with open(f, 'r') as file:
        content = file.read()
    
    modified = False
    
    # First, handle adding the import
    if any(emoji in content for emoji in emoji_map.keys()) and "Ionicons" not in content:
        # We need to insert Ionicons import
        # Let's insert it after import { Colors }
        if "from '@expo/vector-icons'" not in content:
            content = content.replace("import { Colors } from '../../src/theme/colors';", "import { Colors } from '../../src/theme/colors';\nimport { Ionicons } from '@expo/vector-icons';")
            modified = True

    # For specifically index.tsx which has emailIcon style
    if re.search(r'<Text style=\{styles\.emailIcon\}>✉</Text>', content):
        content = re.sub(r'<Text style=\{styles\.emailIcon\}>✉</Text>', '<Ionicons name="mail-outline" size={20} color={Colors.dark} style={styles.emailIcon} />', content)
        modified = True

    for emoji, icon in emoji_map.items():
        pattern = r'<Text[^>]*>' + emoji + r'</Text>'
        if re.search(pattern, content):
            content = re.sub(pattern, icon, content)
            modified = True
            
        pattern_bare = r'>' + emoji + r'<'
        if re.search(pattern_bare, content):
            content = re.sub(pattern_bare, '> ' + icon + ' <', content)
            modified = True

    # Also clean up unused Text style sizes if needed, but not strictly necessary.

    if modified:
        with open(f, 'w') as file:
            file.write(content)
        print(f"Updated icons in {os.path.basename(f)}")

