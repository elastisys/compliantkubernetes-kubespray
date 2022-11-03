### Release notes

- This requires at least terraform 0.14.0

### Fixed

- Changed a Kubespray variable which is required for upgrading clusters on cloud providers that don't have external IPs on their control plane nodes.

### Changed

- Changed terraform scripts for openstack to be able to setup additional server groups and override variables per instance.
- Enabled the `ceph` dashboard for better visibility and troubleshooting of `rook-ceph`
