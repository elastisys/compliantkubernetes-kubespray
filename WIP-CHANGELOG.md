### Release notes

- Check out the [upgrade guide](migration/v2.16.0-ck8s1-v2.17.0-ck8s1/upgrade-cluster.md) for a complete set of instructions needed to upgrade.

### Changed

- enabled calico metrics reporting
- init script uses $flavor automatically to choose the group folder to copy to the config folder
- Changed default openstack config to use the external cloud controller
- Upgraded kubespray from v2.16.0 to 2.17.0.
    Includes upgrade to Kubernetes v1.21.5.

### Fixed

### Added

- Added new command to reboot nodes in a cluster if necessary
- resource requests for rook containers [#105](https://github.com/elastisys/compliantkubernetes-kubespray/pull/105)
- Added configuration for Openstack to use Cinder CSI by default with volume expansion enabled.

### Removed
