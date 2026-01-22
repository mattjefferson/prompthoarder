import Observation

@Observable
@MainActor
final class AppState {
    var isLoading = false
}
