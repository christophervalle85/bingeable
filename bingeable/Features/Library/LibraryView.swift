import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var libraryStore: LibraryStore
    @State private var selectedShelf: LibraryShelf = .waiting

    var body: some View {
        VStack(spacing: 10) {
            Picker("Shelf", selection: $selectedShelf) {
                ForEach(LibraryShelf.allCases) { shelf in
                    Label(shelf.title, systemImage: shelf.systemImage)
                        .tag(shelf)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            let items = libraryStore.trackedShows(in: selectedShelf)
            if items.isEmpty {
                EmptyStateView(
                    title: "No shows in \(selectedShelf.title)",
                    message: "Add shows from Discover or Search.",
                    systemImage: selectedShelf.systemImage
                )
            } else {
                List(items) { tracked in
                    NavigationLink {
                        ShowDetailView(seedShow: tracked.asSeedShow)
                    } label: {
                        ShowRowView(show: tracked.asSeedShow)
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Library")
        .onAppear {
            libraryStore.refresh()
        }
    }
}
