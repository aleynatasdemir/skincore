import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FFF0F0").ignoresSafeArea()

                VStack(spacing: 24) {
                    // avatar
                    VStack(spacing: 12) {
                        ZStack(alignment: .bottomTrailing) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 128, height: 128)
                                .overlay(
                                    ZStack {
                                        if let fullName = authViewModel.currentUser?.fullName, !fullName.isEmpty {
                                            Text(getInitials(from: fullName))
                                                .font(.system(size: 48, weight: .bold))
                                                .foregroundColor(Color(hex: "F472B8"))
                                        } else {
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 64))
                                                .foregroundColor(Color(hex: "F472B8").opacity(0.5))
                                        }
                                    }
                                )
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
                        }

                        Text(authViewModel.currentUser?.fullName ?? "Kullanıcı")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: "2B0E15"))

                        Text(authViewModel.currentUser?.email ?? "")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "F472B8"))
                    }
                    .padding(.top, 24)

                    // menu
                    VStack(spacing: 0) {
                        ProfileRow(icon: "person.fill", title: "Account Preferences")
                        Divider().padding(.leading, 64)
                        ProfileRow(icon: "bell.fill", title: "Reminders & Alerts")
                        Divider().padding(.leading, 64)
                        ProfileRow(icon: "shield.lefthalf.fill", title: "Privacy & Security")
                        Divider().padding(.leading, 64)
                        Button(action: {
                            // delete account action
                        }) {
                            HStack {
                                Image(systemName: "xmark.seal.fill")
                                    .foregroundColor(Color(hex: "EF4444"))
                                    .frame(width: 28)
                                Text("Delete Account")
                                    .foregroundColor(Color(hex: "EF4444"))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Color(hex: "CBD5E1"))
                            }
                            .padding()
                            .background(Color.white)
                        }

                        Divider().padding(.leading, 64)

                        Button(action: {
                            authViewModel.logout()
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                                    .foregroundColor(Color(hex: "EF4444"))
                                    .frame(width: 28)
                                Text("Log Out")
                                    .foregroundColor(Color(hex: "EF4444"))
                                Spacer()
                            }
                            .padding()
                            .background(Color.white)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(Color(hex: "2B0E15"))
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // open settings
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundColor(Color(hex: "2B0E15"))
                    }
                }
            }
        }
    }

    private func getInitials(from name: String) -> String {
        let formatter = PersonNameComponentsFormatter()
        if let components = formatter.personNameComponents(from: name) {
            formatter.style = .abbreviated
            return formatter.string(from: components)
        }
        return String(name.prefix(1)).uppercased()
    }
}

private struct ProfileRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "F472B8"))
                .frame(width: 28)
            Text(title)
                .foregroundColor(Color(hex: "2B0E15"))
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(Color(hex: "CBD5E1"))
        }
        .padding()
        .background(Color.white)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
