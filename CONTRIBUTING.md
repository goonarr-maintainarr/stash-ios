# Contributing to Stash iOS

Thank you for your interest in contributing to Stash iOS! This document provides guidelines and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment. Be kind, constructive, and professional in all interactions.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/stash-ios.git
   cd stash-ios
   ```
3. **Open in Xcode**: `open Stash.xcodeproj`
4. **Create a branch** for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Guidelines

### Code Style

- Follow Swift conventions and SwiftUI best practices
- Use `@MainActor` for all ViewModels
- Prefer `@Observable` over `ObservableObject`
- Use protocol abstractions for dependencies (enables testing)
- Add documentation comments to public APIs

### Architecture

- **Presentation Layer**: Views and ViewModels only
- **Domain Layer**: Repositories, Services, Models
- **Core Layer**: Networking, Persistence, Utilities

New features should follow the existing patterns:
- ViewModels use `ListState<T>` for paginated lists
- Complex ViewModels delegate to focused Manager classes
- Repositories coordinate services, don't contain business logic

### Testing

- Write unit tests for new ViewModels and Services
- Use mocks from `StashTests/Mocks/`
- Run tests before submitting: `⌘U` in Xcode

## Pull Request Process

1. **Update documentation** if your change affects the README or API
2. **Add tests** for new functionality
3. **Ensure tests pass** locally
4. **Create a Pull Request** with:
   - Clear title describing the change
   - Description of what and why
   - Screenshots for UI changes
   - Link to related issue (if applicable)

### PR Title Format

Use conventional commit style:
- `feat: Add performer favorites`
- `fix: Resolve scene list pagination bug`
- `docs: Update README architecture section`
- `refactor: Extract SceneCardManager`
- `test: Add HomeViewModel tests`

## Reporting Issues

When opening an issue, please include:

- **iOS version** and device
- **Stash server version**
- **Steps to reproduce**
- **Expected behavior**
- **Actual behavior**
- **Screenshots/logs** if applicable

## Feature Requests

Feature requests are welcome! Please include:

- **Use case**: Why do you need this feature?
- **Proposed solution**: How should it work?
- **Alternatives considered**: Other approaches you thought of

## Questions

For questions about the codebase or architecture, open a Discussion on GitHub rather than an Issue.

---

Thank you for contributing! 🎉
