### Changed

- Changed default etcd version to 3.5.3
- Switched to fork of kubespray. https://github.com/elastisys/kubespray

### Fixed

- Fixed issue related to `kubeadm join` fail. Because there are no etcd pods mirrored by the kubelet, because of no psp were installed yet.

### Added

- Added ansible config
- Playbook to remove unused docker resources (images, ...)
- Lowered the threshold for garbage collection of unused images.

### Removed
