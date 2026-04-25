const fs = require('fs');
let content = fs.readFileSync('/Users/aleyna/Desktop/skincore/skincore/skincore_native/src/components/profile/ProfileComponents.tsx', 'utf-8');

const importQuiz = "import { SkinTypeQuizModal } from './SkinTypeQuizModal';";
if (!content.includes('SkinTypeQuizModal')) {
    content = content.replace("import { CachedImage } from '../common/CachedImage';", "import { CachedImage } from '../common/CachedImage';\n" + importQuiz);
}

const editProfileState = "const [showQuiz, setShowQuiz] = useState(false);";
if (!content.includes('showQuiz')) {
    content = content.replace("const [loading, setLoading] = useState(false);", "const [loading, setLoading] = useState(false);\n  " + editProfileState);
}

const quizSection = `
            <View style={stylesSheet.inputGroup}>
              <Text style={stylesSheet.label}>Cilt Tipi</Text>
              <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: 12, borderBottomWidth: 1, borderBottomColor: '#f3f4f6' }}>
                <Text style={{ fontSize: 16, color: user?.skinType ? '#1a1a2e' : '#9ca3af' }}>{user?.skinType || 'Belirtilmemiş'}</Text>
                <TouchableOpacity onPress={() => setShowQuiz(true)}>
                    <Text style={{ fontSize: 14, color: Colors.primary, fontWeight: '600' }}>Testi Çöz</Text>
                </TouchableOpacity>
              </View>
            </View>
            <SkinTypeQuizModal
               visible={showQuiz}
               onClose={() => setShowQuiz(false)}
            />
`;

if (!content.includes('Cilt Tipi')) {
    content = content.replace("</View>\n          </View>\n        </View>\n      </SafeAreaView>", quizSection + "          </View>\n        </View>\n      </SafeAreaView>");
}

fs.writeFileSync('/Users/aleyna/Desktop/skincore/skincore/skincore_native/src/components/profile/ProfileComponents.tsx', content);
