//
//  ProfileView.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 7/4/25.
//

import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseFirestore

private let sharedDb = Firestore.firestore()

struct ProfileView: View {
    @StateObject var viewModel = ProfileViewViewModel()
    @State private var showDrawer = false
    @State private var showingNewItemView = false
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var imagePickerSource: ImagePickerSource = .photoLibrary
    @State private var showImageSourceSelection = false
    @State private var showEditProfile = false
    @State private var loadedUserId: String? = nil
    @State private var selectedCategoryForChart: Category? = nil
    @State private var showTopIdealsView = false
    @Environment(\.modelContext) private var modelContext
    @Query var storedSettings: [MainSettings]
    
    @FirestoreQuery var allIdeals: [Ideal]
    
    init() {
        if let userId = Auth.auth().currentUser?.uid {
            self._allIdeals = FirestoreQuery(
                collectionPath: "users/\(userId)/ideals",
                predicates: [
                    .order(by: "createdDate")
                ]
            )
        } else {
            self._allIdeals = FirestoreQuery(
                collectionPath: "users/empty/ideals",
                predicates: [
                    .order(by: "createdDate")
                ]
            )
        }
    }
    
    var accentColor: Color {
        // Follows the palette chosen in Settings (LCPalette).
        LCColor.pink
    }
    
    var textColor: Color {
        if let firstSettings = storedSettings.first {
            return Color(red: firstSettings.textColorRed, green: firstSettings.textColorGreen, blue: firstSettings.textColorBlue, opacity: firstSettings.textColorOpacity)
        } else {
            return Color.black
        }
    }
    
    var body: some View {
        VStack{
            TopNav(pageTitle: "Profile", isIdealList: false, showDrawer: $showDrawer, showingNewItemView: $showingNewItemView)
            
            ScrollView{
                LazyVStack(alignment:.leading, spacing: 0){
                    if let user = viewModel.user{
                        profile(user: user)
                            .onAppear {
                                // Load profile image when user view appears and user data is available
                                if loadedUserId != user.id {
                                    loadedUserId = user.id
                                    loadProfileImage()
                                }
                            }

                        // "Your Top Ideals" history browser, moved here from the
                        // Progress page. Reuses ProfileView's existing ideals query
                        // (no second snapshot listener).
                        TopIdealsHistorySection(
                            allIdeals: allIdeals,
                            accentColor: accentColor,
                            weekStartDay: storedSettings.first?.week_start_day ?? WeekdayUtility.defaultWeekStartDay
                        )
                        .padding(.top, 8)
                    }else{
                        Text("Profile can't be loaded at this moment")
                            .font(.manrope(15, .medium))
                            .foregroundColor(LCColor.textSecondary)
                            .padding(.horizontal, LCMetrics.screenMargin)
                            .padding(.top, 60)
                            .padding(.vertical)
                    }
                }
                .padding(.bottom, 100) // Add bottom padding to prevent content from being hidden by floating buttons
                .onAppear{
                    viewModel.fetchUser()
                    loadProfileImage()
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            // Top-right edit button — raised YELLOW circle with a centered PINK
            // pencil glyph (handoff 2d).
            .overlay(alignment: .topTrailing) {
                if !showDrawer {
                    Button(action: {
                        HapticFeedback.impact()
                        showEditProfile = true
                    }) {
                        Image("Line Edit_Pink")
                            .resizable()
                            // Templated: baked pink on a tertiary-role fill meant
                            // that in Past the pencil was pink on pink.
                            .renderingMode(.template)
                            .foregroundColor(LCColor.glyph(.pink, onFill: .yellow))
                            .scaledToFit()
                            .frame(width: 19, height: 19)
                    }
                    .buttonStyle(NeuCircleButtonStyle(fill: LCColor.yellow, diameter: 40))
                    .accessibilityLabel("Edit profile")
                    .padding(.trailing, LCMetrics.screenMargin)
                    .padding(.top, 6)
                }
            }

        }
        .background(LCColor.surface.ignoresSafeArea())
        .accentColor(LCColor.pink)
        .overlay(alignment: .bottomLeading) {
            if !showDrawer {
                Button(action: {
                    HapticFeedback.impact(style: .heavy)
                    viewModel.logOut()
                }) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(LCColor.glyph(.pink))
                }
                .buttonStyle(NeuCircleButtonStyle(fill: LCColor.surface, diameter: 52))
                .accessibilityLabel("Log out")
                .padding(.leading, 20)
                .padding(.bottom, 20)
            }
        }
        .padding(.leading, MenuDrawer.contentInset)   // iPad sidebar inset (0 on iPhone)
        .overlay(alignment: .top){
            MenuDrawer(showDrawer: $showDrawer,activeView:"profile")
                .zIndex(10000)
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: imagePickerSource)
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(viewModel: viewModel, isPresented: $showEditProfile)
        }
        .sheet(item: $selectedCategoryForChart) { category in
            CategoryReviewChartView(
                category: category,
                allIdeals: allIdeals,
                accentColor: accentColor,
                textColor: textColor,
                weekStartDay: storedSettings.first?.week_start_day ?? WeekdayUtility.defaultWeekStartDay
            )
            .id("\(category.rawValue)-\(allIdeals.count)")
        }
        .sheet(isPresented: $showTopIdealsView) {
            TopIdealsView(
                allIdeals: allIdeals,
                accentColor: accentColor,
                textColor: textColor,
                weekStartDay: storedSettings.first?.week_start_day ?? WeekdayUtility.defaultWeekStartDay
            )
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            if let image = newValue, let userId = viewModel.user?.id {
                viewModel.saveProfilePicture(image, to: modelContext, userId: userId)
                // Update the displayed image immediately
                DispatchQueue.main.async {
                    viewModel.profileImage = image
                }
            }
        }
    }
    
    private func loadProfileImage() {
        // Try to get userId from user object first, fallback to Auth if not available
        let userId: String? = viewModel.user?.id ?? Auth.auth().currentUser?.uid
        
        if let userId = userId {
            if let image = viewModel.loadProfilePicture(from: modelContext, userId: userId) {
                DispatchQueue.main.async {
                    viewModel.profileImage = image
                }
            } else {
                DispatchQueue.main.async {
                    viewModel.profileImage = nil
                }
            }
        }
    }
    
    @ViewBuilder
    func profile(user: User) -> some View {
        let joinedDateText = Date(timeIntervalSince1970: user.joined).formatted(date: .abbreviated, time: .omitted)
        let lifetimeStats = lifetimeStatsSinceMembership(joinedAt: user.joined)

        VStack(spacing: 0) {
            // Header — raised avatar + stacked name on the left, boxless vitals
            // to the right (handoff 2d).
            HStack(alignment: .center, spacing: 18) {
                VStack(spacing: 10) {
                    ZStack(alignment: .bottomTrailing) {
                        // Profile image — raised neumorphic circle
                        if let profileImage = viewModel.profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 104, height: 104)
                                .clipShape(Circle())
                                .shadow(color: LCColor.shadowDark, radius: 7, x: 6, y: 6)
                                .shadow(color: LCColor.shadowLight, radius: 7, x: -6, y: -6)
                        } else {
                            Image(systemName: "person")
                                .font(.system(size: 44, weight: .regular))
                                .accentText(.pink)
                                .frame(width: 104, height: 104)
                                .neuRaised(Circle(), cssOffset: 6, cssBlur: 14)
                        }

                        // Camera badge — small raised circle over the avatar edge
                        Button(action: {
                            HapticFeedback.impact()
                            showImageSourceSelection = true
                        }) {
                            Image(systemName: "camera")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(LCColor.glyph(.pink))
                        }
                        .buttonStyle(NeuCircleButtonStyle(diameter: 30))
                        .disabled(viewModel.isLoading)
                        .offset(x: 2, y: 2)
                        .zIndex(1)
                        .accessibilityLabel("Change profile photo")
                    }

                    // User's name — stacked first / last
                    Text("\(user.first_name)\n\(user.last_name)")
                        .font(.lcTitle(21))
                        .foregroundColor(LCColor.ink)
                        .multilineTextAlignment(.center)
                }
                .frame(width: 112)

                // Vitals — age, height, weight, email (no boxes).
                // Gender and Location removed at the client's request
                // (2026-09-02); the underlying User fields are untouched.
                VStack(alignment: .leading, spacing: 0) {
                    vitalRow(label: "Age", value: formatAge(user: viewModel.user))
                    vitalHairline
                    vitalRow(label: "Height", value: formatHeight(user: viewModel.user))
                    vitalHairline
                    vitalRow(label: "Weight", value: formatWeight(user: viewModel.user))
                    vitalHairline
                    vitalRow(label: "Email", value: user.email, valueSize: 13)
                }
            }
            .padding(.top, 52) // clears the floating top-right edit button
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            // Lifetime stats — actions propel ideals (raised card, sunken wells).
            // Same card as the Progress page's weekly totals (StatWellsCard).
            StatWellsCard(idealsValue: lifetimeStats.ideals,
                          idealsLabel: "IDEALS",
                          actionsValue: lifetimeStats.actions,
                          actionsLabel: "ACTIONS") {
                VStack(spacing: 0) {
                    Text("Every action propels an ideal forward")
                        .font(.lcBody(13))
                        .foregroundColor(LCColor.textSecondary)
                        .padding(.top, 14)
                    Text("Since \(joinedDateText)")
                        .font(.lcBody(12))
                        .foregroundColor(LCColor.textMuted)
                        .padding(.top, 3)
                }
            }
            .padding(.horizontal, LCMetrics.screenMargin)
            .padding(.top, 10)
            .padding(.bottom, 6)
        }
        .fixedSize(horizontal: false, vertical: false)
        .confirmationDialog("Select Photo Source", isPresented: $showImageSourceSelection, titleVisibility: .visible) {
            Button("Camera") {
                imagePickerSource = .camera
                showImagePicker = true
            }
            Button("Photo Library") {
                imagePickerSource = .photoLibrary
                showImagePicker = true
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    /// One boxless vitals line — muted Oswald label left, ink value right.
    private func vitalRow(label: String, value: String, valueSize: CGFloat = 16) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.lcTitle(15))
                .foregroundColor(LCColor.textMuted)
            Spacer(minLength: 8)
            Text(value)
                .font(.manrope(valueSize, .semibold))
                .foregroundColor(LCColor.ink)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 9)
    }

    /// Hairline break between vitals (per the 2d mock — not the feathered list divider).
    private var vitalHairline: some View {
        Rectangle()
            .fill(LCColor.dividerGrey.opacity(0.5))
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    // The stat wells and the propel arrow live in Views/Components/StatWellsCard.swift,
    // shared with the Progress page.

    private func lifetimeStatsSinceMembership(joinedAt: TimeInterval) -> (ideals: Int, actions: Int) {
        let idealsSinceMembership = allIdeals.filter { ideal in
            ideal.createdDate >= joinedAt
        }
        
        let totalIdeals = idealsSinceMembership.count
        let totalActions = idealsSinceMembership.reduce(0) { $0 + $1.doneCount }
        return (ideals: totalIdeals, actions: totalActions)
    }
    
    
    
    
    
    
    
    
    
    private func formatHeight(user: User?) -> String {
        guard let user = user else { return "—" }
        
        if let country = user.country, country != "United States" {
            // Metric - need to calculate from feet/inches if available
            if let feet = user.height_feet, let inches = user.height_inches {
                let totalInches = Double(feet * 12 + inches)
                let cm = totalInches * 2.54
                return String(format: "%.0f cm", cm)
            }
            return "—"
        } else {
            // Imperial
            if let feet = user.height_feet, let inches = user.height_inches {
                return "\(feet)'\(inches)\""
            }
            return "—"
        }
    }
    
    private func formatWeight(user: User?) -> String {
        guard let user = user else { return "—" }
        
        if let country = user.country, country != "United States" {
            // Metric
            if let weight = user.weight_kg {
                return String(format: "%.1f kg", weight)
            }
            return "—"
        } else {
            // Imperial - convert from kg
            if let weightKg = user.weight_kg {
                let weightLbs = weightKg * 2.20462
                return String(format: "%.1f lbs", weightLbs)
            }
            return "—"
        }
    }
    
    private func formatAge(user: User?) -> String {
        guard let user = user,
              let dob = user.date_of_birth else { return "—" }
        
        let birthDate = Date(timeIntervalSince1970: dob)
        let calendar = Calendar.current
        let age = calendar.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
        return "\(age)"
    }
    
    
    
    
    private func formatAddressMultiline(user: User) -> String {
        var lines: [String] = []
        
        // First line: address
        if let address = user.address, !address.isEmpty {
            lines.append(address)
        }
        
        // Second line: city, state
        var line2: [String] = []
        if let city = user.city, !city.isEmpty {
            line2.append(city)
        }
        if let state = user.state, !state.isEmpty {
            line2.append(state)
        }
        if !line2.isEmpty {
            lines.append(line2.joined(separator: ", "))
        }
        
        // Third line: country, zip code
        var line3: [String] = []
        if let country = user.country, !country.isEmpty {
            line3.append(country)
        }
        if let zipCode = user.zip_code, !zipCode.isEmpty {
            line3.append(zipCode)
        }
        if !line3.isEmpty {
            lines.append(line3.joined(separator: ", "))
        }
        
        return lines.joined(separator: "\n")
    }
}

#Preview {
    ProfileView()
}
