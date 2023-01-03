### Release notes

- This requires at least terraform 0.14.0
- If you are using the rook-ceph operator you can read the [migration docs](rook/migration/rook-1.5.x-rook-1.10.5/upgrade.md) on how to upgrade these components.

### Fixed

- Changed a Kubespray variable which is required for upgrading clusters on cloud providers that don't have external IPs on their control plane nodes.

### Changed

- Changed terraform scripts for openstack to be able to setup additional server groups and override variables per instance.
- Enabled the `ceph` dashboard for better visibility and troubleshooting of `rook-ceph`
- Upgraded rook-ceph operator to `v1.10.5` and ceph to `v17.2.5`

### Added

Added a get-requirements file to standardize which terraform version to use, `1.2.9`.
