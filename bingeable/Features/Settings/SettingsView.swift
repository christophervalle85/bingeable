import SwiftUI

struct SettingsView: View {
    private enum ProfileSection: Hashable {
        case profile
        case editProfile
        case subscriptions
        case appSettings
    }

    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var libraryStore: LibraryStore
    @EnvironmentObject private var profileSettingsStore: ProfileSettingsStore
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var viewModel = ProfileViewModel()
    @State private var selectedSection: ProfileSection = .profile
    @State private var isClearing = false
    @State private var cacheStatusMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView {
                VStack(spacing: 14) {
                    switch selectedSection {
                    case .profile:
                        profileHeaderCard
                        subscriptionOverviewCard
                        queuePulseCard
                    case .editProfile:
                        editProfileCard
                    case .subscriptions:
                        providerCard
                    case .appSettings:
                        appSettingsCard
                    }
                }
                .padding(16)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.bind(sessionManager: sessionManager, store: profileSettingsStore)
            viewModel.loadForCurrentScope()
        }
        .onChange(of: sessionManager.authState) { _, _ in
            viewModel.handleAuthStateChange()
        }
        .onChange(of: scenePhase) { _, nextPhase in
            if nextPhase == .background || nextPhase == .inactive {
                viewModel.saveIfNeeded()
            }
        }
        .alert("Discard unsaved changes?", isPresented: $viewModel.showDiscardChangesConfirmation) {
            Button("Keep Editing", role: .cancel) {
                viewModel.cancelScopeChange()
            }

            Button("Discard", role: .destructive) {
                viewModel.confirmDiscardAndSwitchScope()
            }
        } message: {
            Text("Your account context changed. Discard current edits and load the other profile?")
        }
    }

    private var topBar: some View {
        HStack {
            if selectedSection == .profile {
                Text("Profile")
                    .font(.title2.weight(.black))
                    .fontDesign(.serif)
            } else {
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        selectedSection = .profile
                    }
                } label: {
                    Label("Profile", systemImage: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile-back-button")
            }

            Spacer()

            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    selectedSection = .appSettings
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(Color.secondary.opacity(0.14), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile-open-settings")
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    private var profileHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: viewModel.avatarStyle.symbolName)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.cyan.gradient, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Profile")
                        .font(.title3.weight(.bold))

                    Text(viewModel.accountBadgeText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            Text("Quick access to profile updates, services, and queue activity.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    selectedSection = .editProfile
                }
            } label: {
                Label("Edit Profile", systemImage: "pencil")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("profile-edit-button")
        }
        .padding(14)
        .background(cardBackground)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile-header-card")
    }

    private var subscriptionOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Streaming Subscriptions", systemImage: "tv")
                .font(.headline)

            infoRow(
                title: "Selected",
                value: "\(viewModel.selectedProviderIDs.count) of \(viewModel.providerOptions.count)"
            )

            if viewModel.selectedProviders.isEmpty {
                Text("No services selected yet. Add your subscriptions to personalize recommendations.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), spacing: 8)], spacing: 8) {
                    ForEach(viewModel.selectedProviders) { provider in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(provider.name)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }

            Text("\(unselectedProviderCount) more services available to add")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    selectedSection = .subscriptions
                }
            } label: {
                Label("Manage Services", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("profile-manage-services")
        }
        .padding(14)
        .background(cardBackground)
        .accessibilityIdentifier("profile-subscriptions-card")
    }

    private var queuePulseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Queue Activity", systemImage: "sparkles.tv")
                .font(.headline)

            HStack(spacing: 10) {
                statTile(title: "Waiting", value: waitingCount, tint: .orange, symbol: "clock.fill")
                statTile(title: "Watching", value: watchingCount, tint: .cyan, symbol: "play.fill")
                statTile(title: "Finished", value: finishedCount, tint: .green, symbol: "checkmark.circle.fill")
            }

            Divider()

            infoRow(title: "Total Saved", value: "\(libraryStore.items.count)")
            infoRow(title: "Recently Updated", value: mostRecentlyUpdatedName ?? "No shows tracked yet")
        }
        .padding(14)
        .background(cardBackground)
    }

    private var editProfileCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Edit Profile", systemImage: "pencil")
                .font(.headline)

            Picker("Avatar Style", selection: $viewModel.avatarStyle) {
                ForEach(ProfileAvatarStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 6) {
                Text("Display Name")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("Display name", text: $viewModel.displayName)
                    .textInputAutocapitalization(.words)
                    .padding(10)
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityIdentifier("profile-display-name-field")

                Text("\(viewModel.displayNameRemainingCount) characters remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            editorActionRow(doneButtonID: "profile-done-button")
        }
        .padding(14)
        .background(cardBackground)
        .accessibilityIdentifier("profile-edit-section")
    }

    @ViewBuilder
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func statTile(title: String, value: Int, tint: Color, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)

            Text("\(value)")
                .font(.title3.weight(.black))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var waitingCount: Int {
        libraryStore.items.filter { $0.shelf == .waiting }.count
    }

    private var watchingCount: Int {
        libraryStore.items.filter { $0.shelf == .watching }.count
    }

    private var finishedCount: Int {
        libraryStore.items.filter { $0.shelf == .finished }.count
    }

    private var mostRecentlyUpdatedName: String? {
        libraryStore.items.max(by: { $0.updatedAt < $1.updatedAt })?.name
    }

    private var unselectedProviderCount: Int {
        max(0, viewModel.providerOptions.count - viewModel.selectedProviderIDs.count)
    }

    private var providerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Streaming Subscriptions", systemImage: "tv")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(viewModel.providerOptions) { provider in
                    let isSelected = viewModel.selectedProviderIDs.contains(provider.id)

                    Button {
                        viewModel.toggleProvider(provider.id)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected ? .green : .secondary)

                            Text(provider.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(
                            isSelected ? Color.green.opacity(0.12) : Color.secondary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("profile-provider-\(provider.id)")
                    .accessibilityValue(isSelected ? "selected" : "not-selected")
                }
            }

            editorActionRow(doneButtonID: "profile-subscriptions-done-button")
        }
        .padding(14)
        .background(cardBackground)
        .accessibilityIdentifier("profile-subscriptions-section")
    }

    private func editorActionRow(doneButtonID: String) -> some View {
        HStack(spacing: 10) {
            Button("Reset") {
                viewModel.resetToSaved()
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.isDirty)
            .accessibilityIdentifier("profile-reset-button")

            Button("Save") {
                viewModel.save()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.isDirty)
            .accessibilityIdentifier("profile-save-button")

            Spacer()

            Button("Done") {
                viewModel.saveIfNeeded()
                withAnimation(.snappy(duration: 0.2)) {
                    selectedSection = .profile
                }
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .accessibilityIdentifier(doneButtonID)
        }
    }

    private var appSettingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("App Settings", systemImage: "gearshape")
                .font(.headline)

            HStack {
                Text("Region")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(appContainer.regionCode)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button(isClearing ? "Clearing..." : "Clear Cache") {
                clearCache()
            }
            .buttonStyle(.bordered)
            .disabled(isClearing)
            .accessibilityIdentifier("profile-cache-clear")

            if let cacheStatusMessage {
                Text(cacheStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !appContainer.hasTMDBAPIKey {
                Text("TMDB API key not configured. App is using local fallback data.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("Saved shows: \(libraryStore.items.count)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if sessionManager.authState != .undetermined {
                Divider()

                Button(role: .destructive) {
                    sessionManager.signOut()
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2)
                .accessibilityIdentifier("profile-sign-out")
            } else {
                Text("You are currently signed out.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(cardBackground)
        .accessibilityIdentifier("profile-app-settings-section")
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
            }
    }

    private func clearCache() {
        cacheStatusMessage = nil
        isClearing = true

        Task {
            await appContainer.showRepository.clearCache()
            await MainActor.run {
                isClearing = false
                cacheStatusMessage = "Cache cleared"
            }
        }
    }
}
