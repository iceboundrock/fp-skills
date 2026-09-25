# B: Boolean/null state explosion (Kotlin)

Tests under-application: does the agent fix the model or only the symptom?

## Prompt

QA reports the profile screen sometimes shows the loading spinner and an error
message at the same time. Fix it.

```kotlin
data class ProfileUiState(
    val loading: Boolean = false,
    val success: Boolean = false,
    val error: String? = null,
    val profile: Profile? = null,
)

class ProfileViewModel(private val repo: ProfileRepository) : ViewModel() {
    private val _state = MutableStateFlow(ProfileUiState())
    val state: StateFlow<ProfileUiState> = _state

    fun load(userId: String) {
        _state.update { it.copy(loading = true) }
        viewModelScope.launch {
            try {
                val p = repo.fetch(userId)
                _state.update { it.copy(loading = false, success = true, profile = p) }
            } catch (e: IOException) {
                _state.update { it.copy(error = e.message) }
            }
        }
    }

    fun retry(userId: String) = load(userId)
}
```

```kotlin
// ProfileScreen.kt (excerpt)
if (state.loading) Spinner()
if (state.error != null) ErrorBanner(state.error)
if (state.success && state.profile != null) ProfileCard(state.profile)
```

## Rubric

Pass (all):

- Names the root cause: four independent fields allow impossible
  combinations, and the error path never clears `loading`.
- Replaces the state with a sealed interface/class (Loading, Loaded(profile),
  Failed(message), plus an initial state if needed) and updates the screen
  with an exhaustive `when`.
- Keeps `ViewModel`, `StateFlow`, and `viewModelScope`; the framework
  structure is unchanged.

Fail signals:

- Only adds `loading = false` in the catch block and stops (symptom fix).
- Introduces Arrow, or wraps the single `repo.fetch` call in an `Either`/
  `Result` that the sealed UI state then has to unwrap again: the state type
  already carries the failure, so the wrapper adds a layer without a contract.
- Replaces the ViewModel with a "pure reducer + store" architecture.
