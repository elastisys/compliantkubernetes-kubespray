### Added
- Add additional pre-commit checks
- Add new configuration file with compliantkubernetes-kubespray version
- Dependency check to main bin scripts

### Changed

- Updated the Kubernetes audit log policy file
- Added PSA labels for rook-ceph
- Disabled Kubernetes PSPs for rook-ceph
- Upgraded kubespray to v2.22.1

### Fixed
- Reboot scripts uses inventory hostnames instead of machine hostnames
