import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import GoogleMobileAds

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        MobileAds.shared.start(completionHandler: nil)
        
        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { _, _ in }
        )
        application.registerForRemoteNotifications()
        Messaging.messaging().delegate = self
        
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("FCM Token: \(String(describing: fcmToken))")
        if let token = fcmToken {
            UserDefaults.standard.set(token, forKey: "fcm_token")
            Task {
                if UserDefaults.standard.string(forKey: "access_token") != nil || APIClient.shared != nil {
                   // AuthViewModel'in isAuthenticated değişkeni devreye girecek,
                   // Ancak yine de garanti olması için burada da atabilirsiniz:
                   try? await APIClient.shared.updateFcmToken(token)
                }
            }
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([[.banner, .sound]])
    }
}

@main
struct SkinCoreApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var lang = LanguageManager.shared
    @StateObject private var subscriptionService = SubscriptionService.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isInitializing {
                    SplashView()
                } else if authViewModel.isAuthenticated {
                    if authViewModel.needsUsername {
                        UsernameSetupView()
                    } else {
                        MainTabView()
                            .onAppear {
                                if !subscriptionService.isPremium {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        subscriptionService.showPaywallOnLaunch = true
                                    }
                                }
                            }
                            .sheet(isPresented: $subscriptionService.showPaywallOnLaunch) {
                                PaywallView()
                                    .environmentObject(subscriptionService)
                                    .environmentObject(lang)
                            }
                    }
                } else {
                    LoginView()
                }
            }
            .environmentObject(authViewModel)
            .environmentObject(lang)
            .environmentObject(subscriptionService)
            .preferredColorScheme(.light)
        }
    }
}

// MARK: - Keyboard Dismiss

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Splash View
struct SplashView: View {
    @State private var pulse = false
    
    var body: some View {
        ZStack {
            // App theme background
            LinearGradient(
                colors: [Color(hex: "F9D6D6"), Color(hex: "FBF3F3")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Central Logo
                Image("app_logo_header")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 70)
                    .scaleEffect(pulse ? 1.03 : 0.97)
                    .animation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
                    .onAppear {
                        pulse = true
                    }
                
                // Loading spinner
                ProgressView()
                    .tint(Color(hex: "D4728C"))
                    .scaleEffect(1.2)
            }
        }
    }
}
