import re

def update_file(filepath, is_register=False):
    with open(filepath, 'r') as f:
        content = f.read()

    # Add state
    if "const [showPassword, setShowPassword] = useState(false);" not in content:
        if is_register:
            content = content.replace(
                "const [localError, setLocalError] = useState('');",
                "const [localError, setLocalError] = useState('');\n  const [showPassword, setShowPassword] = useState(false);\n  const [showConfirmPassword, setShowConfirmPassword] = useState(false);"
            )
        else:
            content = content.replace(
                "const [password, setPassword] = useState('');",
                "const [password, setPassword] = useState('');\n  const [showPassword, setShowPassword] = useState(false);"
            )
            
    # Modify SecureTextEntry for typical password field
    if 'secureTextEntry' in content:
        if is_register:
            content = re.sub(
                r'placeholder=\{\s*t\(\'passwordMinChars\'\)\s*\}[\s\S]*?secureTextEntry[\s\S]*?returnKeyType="next"',
                r'placeholder={t(\'passwordMinChars\')}\n                placeholderTextColor="#9CA3AF"\n                value={password}\n                onChangeText={setPassword}\n                secureTextEntry={!showPassword}\n                returnKeyType="next"',
                content
            )
            content = re.sub(
                r'placeholder=\{\s*t\(\'confirmPassword\'\)\s*\}[\s\S]*?secureTextEntry[\s\S]*?returnKeyType="done"',
                r'placeholder={t(\'confirmPassword\')}\n                placeholderTextColor="#9CA3AF"\n                value={confirmPassword}\n                onChangeText={setConfirmPassword}\n                secureTextEntry={!showConfirmPassword}\n                returnKeyType="done"',
                content
            )
        else:
            content = re.sub(
                r'placeholder=\{\s*t\(\'password\'\)\s*\}[\s\S]*?secureTextEntry[\s\S]*?returnKeyType="done"',
                r'placeholder={t(\'password\')}\n                placeholderTextColor="#9CA3AF"\n                value={password}\n                onChangeText={setPassword}\n                secureTextEntry={!showPassword}\n                returnKeyType="done"',
                content
            )

    # Add toggle button after the inputs
    
    toggle_btn = """
              <TouchableOpacity onPress={() => setShowPassword(!showPassword)}>
                <Ionicons
                  name={showPassword ? 'eye-off-outline' : 'eye-outline'}
                  size={20}
                  color="#9CA3AF"
                />
              </TouchableOpacity>
"""
    confirm_toggle_btn = """
              <TouchableOpacity onPress={() => setShowConfirmPassword(!showConfirmPassword)}>
                <Ionicons
                  name={showConfirmPassword ? 'eye-off-outline' : 'eye-outline'}
                  size={20}
                  color="#9CA3AF"
                />
              </TouchableOpacity>
"""

    if "eye-outline" not in content:
        if is_register:
            # For register, we have to inject it right before the closing View of the input wrap
            # This is fragile with regex, so let's do a reliable replace:
            content = content.replace('                returnKeyType="next"\n              />\n            </View>', 
                                    '                returnKeyType="next"\n              />\n' + toggle_btn + '            </View>')
            content = content.replace('                returnKeyType="done"\n                onSubmitEditing={handleRegister}\n              />\n            </View>', 
                                    '                returnKeyType="done"\n                onSubmitEditing={handleRegister}\n              />\n' + confirm_toggle_btn + '            </View>')
        else:
            content = content.replace('                returnKeyType="done"\n                onSubmitEditing={handleLogin}\n              />\n            </View>', 
                                    '                returnKeyType="done"\n                onSubmitEditing={handleLogin}\n              />\n' + toggle_btn + '            </View>')

    with open(filepath, 'w') as f:
        f.write(content)

update_file('/Users/aleyna/Desktop/skincore/skincore/skincore_native/app/(auth)/email-login.tsx', is_register=False)
update_file('/Users/aleyna/Desktop/skincore/skincore/skincore_native/app/(auth)/register.tsx', is_register=True)
