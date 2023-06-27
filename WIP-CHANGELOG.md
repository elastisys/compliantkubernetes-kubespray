### Added
- Add additional pre-commit checks
- Add new configuration file with compliantkubernetes-kubespray version
- Dependency check to main bin scripts

### Changed

- Updated the Kubernetes audit log policy file
- Added PSA labels for rook-ceph
- Disabled Kubernetes PSPs for rook-ceph

### Fixed
- Reboot scripts uses inventory hostnames instead of machine hostnames
