# Compliant Kubernetes Kubespray changelog
<!-- BEGIN TOC -->
- [v2.17.0-ck8s1](#v2170-ck8s1---2021-10-20)
- [v2.16.0-ck8s1](#v2160-ck8s1---2021-07-02)
- [v2.15.0-ck8s1](#v2150-ck8s1---2021-05-27)
<!-- END TOC -->

-------------------------------------------------
## v2.17.0-ck8s1 - 2021-10-20

### Changed

- enabled calico metrics reporting
- init script uses $flavor automatically to choose the group folder to copy to the config folder
- Changed default openstack config to use the external cloud controller

### Fixed

### Added

- Added new command to reboot nodes in a cluster if necessary
- resource requests for rook containers [#105](https://github.com/elastisys/compliantkubernetes-kubespray/pull/105)
- Added configuration for Openstack to use Cinder CSI by default with volume expansion enabled.

### Removed

-------------------------------------------------
## v2.16.0-ck8s1 - 2021-07-02

### Release notes

- Inventory and group_vars must be migrated to use new group names.
- Check out the [upgrade guide](migration/v2.15.0-ck8s1-v2.16.0-ck8s1/upgrade-cluster.md) for a complete set of instructions needed to upgrade.

### Changed

- Upgraded kubespray from v2.15.0 to 2.16.0.
  Includes upgrade to Kubernetes v1.20.7.

### Fixed

### Added

- Added scripts and instructions for removing Rook.

### Removed

-------------------------------------------------
## v2.15.0-ck8s1 - 2021-05-27

### Added

- First stable release

### Fixed

### Changed

### Removed
