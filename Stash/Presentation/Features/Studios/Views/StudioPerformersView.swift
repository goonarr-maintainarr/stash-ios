import SwiftUI

struct StudioPerformersView: View {
    @State private var viewModel: StudioPerformersViewModel
    @EnvironmentObject var dependencyContainer: DependencyContainer
    
    var onPerformerClick: ((String, String) -> Void)?
    
    init(viewModel: StudioPerformersViewModel,
         onPerformerClick: ((String, String) -> Void)? = nil) {
        _viewModel = State(wrappedValue: viewModel)
        self.onPerformerClick = onPerformerClick
    }
    
    // List layout (single column)
    private let columns = [
        GridItem(.flexible())
    ]
    
    var body: some View {
        Group {
            switch viewModel.state {
            case .loading, .idle:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
                
            case .empty:
                ContentUnavailableView(
                    "No Performers Found",
                    systemImage: "person.2",
                    description: Text("This studio has no performers.")
                )
                .frame(maxWidth: .infinity, minHeight: 200)
                
            case .error(let message):
                ContentUnavailableView(
                    "Error Loading Performers",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
                
            case .content(let performers):
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(performers) { performer in
                        PerformerCard(
                            performer: performer,
                            layoutType: .list,
                            actions: PerformerCardActions(onPerformerClick: {
                                onPerformerClick?(performer.id, performer.name ?? "")
                            })
                        )
                        .onAppear {
                            if performer == performers.last {
                                Task { await viewModel.loadMore() }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical)
            }
        }
        .task {
            await viewModel.loadPerformers()
        }
    }
}
