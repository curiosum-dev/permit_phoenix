# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Support for automatic inference of action names from controller routes
- Support for automatic inference of action names from LiveView routes
- Support for Phoenix LiveView 1.x

### Fixed
- Missing alias to Types in AuthorizeHook
- Permit.Ecto-related callbacks not correctly defined
- Improved detection of Permit.Ecto presence using mix lock data
- File structure organization: moved live_view.ex file to correct location

### Changed
- Updated CI and testing configuration
- Updated dependencies to fix deprecation warnings

## [0.2.0] - 2023-03-28

### Added
- Support for customizing responses when records are not found with `handle_not_found` callback
- Custom RecordNotFound exception for better error handling
- Authorization for handle_event in LiveView
- Support for using loader with Permit.Ecto.Resolver
- Added event_mapping callback for LiveView

### Changed
- Updated dependencies to latest versions of permit and permit_ecto
- Renamed attach_params_hook to attach_hooks for better clarity

### Fixed
- Allow specifying fallback_path and unauthorized_message as functions
- Tests and fixes for fallback_path and unauthorized_message as functions
- Fixed missing :update and :delete actions in singular and preloadable actions
- Fixed checks for presence of Permit.Ecto
- Various compilation warnings and code style improvements

## [0.1.0] - 2022-10-14

### Added
- Initial stable release
- Phoenix Framework integration for Permit authorization library
- LiveView integration for authorization
- Controller integration with authorization plugs
- Support for preloading resources based on permissions
- Configurable authorization callbacks
- Documentation and examples in README

### Changed
- Upgraded dependencies to enforce usage of bugfixed versions
- Documentation improvements and fixes to Credo indications
- Code cleanup and test coverage improvements

### Fixed
- Fixed various bugs identified during initial testing
- Removed assigns when changing action in LiveView
