# Contributing to OpenCMM

Thank you for your interest in contributing to OpenCMM! This project is open source and welcomes contributions from the community.

## Getting Started

### Prerequisites

- macOS 13 (Ventura) or later
- Xcode 15+ or Swift 5.9+
- Git

### Building

```bash
# Clone the repository
git clone https://github.com/your-username/open-cmm.git
cd open-cmm

# Build with Swift Package Manager
swift build

# Or open in Xcode
open Package.swift

# Run
swift run OpenCMM
```

### Project Structure

```
OpenCMM/
├── App/          # App entry point, delegate, menu bar
├── Views/        # SwiftUI views for each module
├── ViewModels/   # Business logic for views
├── Models/       # Data models
├── Services/     # Core services (cleaning, scanning, etc.)
├── Components/   # Reusable UI components
├── Utilities/    # Helper functions and extensions
└── Resources/    # Assets, entitlements
```

## How to Contribute

1. **Fork** the repository
2. **Create a branch** for your feature (`git checkout -b feature/my-feature`)
3. **Make your changes** with clear, descriptive commits
4. **Test** your changes thoroughly
5. **Submit a Pull Request** with a description of what you changed and why

## Guidelines

- Follow Swift conventions and the existing code style
- Write clear commit messages
- Add comments for complex logic
- Test on macOS 13+ before submitting
- Keep PRs focused — one feature or fix per PR

## Module Contributions

Each module is self-contained with a View, ViewModel, and Service:

- **Sweep**: System junk, caches, logs
- **Security**: Malware detection, privacy cleanup
- **Boost**: Startup item management
- **Updates**: Software update management
- **Uninstaller**: Complete app removal with leftover scanning
- **Duplicates**: Duplicate files, similar images, large file detection
- **Disk Map**: Visual disk usage analysis

If you want to improve a module, the Service layer is where the core logic lives.

For AI agents and detailed architecture docs, see [agents.md](agents.md).

## Reporting Issues

- Use GitHub Issues for bug reports and feature requests
- Include your macOS version and steps to reproduce
- Screenshots are helpful for UI issues

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
