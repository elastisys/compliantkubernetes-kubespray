# Compliant Kubernetes Kubespray changelog
<!-- BEGIN TOC -->
- [v2.19.0-ck8s3](#v2190-ck8s3---2022-09-23)
- [v2.19.0-ck8s2](#v2190-ck8s2---2022-07-22)
- [v2.19.0-ck8s1](#v2190-ck8s1---2022-06-14)
- [v2.18.1-ck8s1](#v2181-ck8s1---2022-04-26)
- [v2.18.0-ck8s1](#v2180-ck8s1---2022-02-08)
- [v2.17.1-ck8s1](#v2171-ck8s1---2021-11-08)
- [v2.17.0-ck8s1](#v2170-ck8s1---2021-10-21)
- [v2.16.0-ck8s1](#v2160-ck8s1---2021-07-02)
- [v2.15.0-ck8s1](#v2150-ck8s1---2021-05-27)
<!-- END TOC -->

-------------------------------------------------
## v2.19.0-ck8s3 - 2022-09-23

### Changed

- pre-commit rev update to `2.2.0-rc.1`
- Bumped upcloud csi driver to `v0.3.3`

-------------------------------------------------
## v2.19.0-ck8s2 - 2022-07-22

### Added

- Added a check to see if the status of the kubespray git submodule differs from the expected status to hinder that people apply a different kubespray version than they want by mistake.
- New playbook `playbooks/kubeconfig.yml` to manage kubeconfigs. It can either move the cluster admin kubeconfig that kubespray produces or create an OIDC kubeconfig. This comes with several new group vars.
- New playbook `playbooks/cluster_admin_rbac.yml` to add cluster admin RBAC for OIDC users. This comes with several new group vars.

### Changed

- Apply command uses the new ansible playbooks to manage kubeconfigs and OIDC clusteradmin RBAC.

-------------------------------------------------
## v2.19.0-ck8s1 - 2022-06-14

### Changed

- Upgraded kubespray from v2.18.0 to v2.19.0.

### Added
- Added `remove-node` command

-------------------------------------------------
## v2.18.1-ck8s1 - 2022-04-26

### Changed

- Changed default etcd version to 3.5.3
- Switched to fork of kubespray. https://github.com/elastisys/kubespray

### Fixed

- Fixed issue related to `kubeadm join` fail. Because there are no etcd pods mirrored by the kubelet, because of no psp were installed yet.

### Added

- Added ansible config
- Playbook to remove unused docker resources (images, ...)
- Lowered the threshold for garbage collection of unused images.

-------------------------------------------------
## v2.18.0-ck8s1 - 2022-02-08

### Changed

- Upgraded kubespray to 2.18.0
    Includes upgrade to Kubernetes v1.22.5.
- Changed container manager to containerd

-------------------------------------------------
## v2.17.1-ck8s1 - 2021-11-08

### Changed

- The reboot playbook now also drains the nodes before restarting them.
- Upgraded kubespray from v2.17.0 to v2.17.1.
    Includes upgrade to Kubernetes v1.21.6.

-------------------------------------------------
## v2.17.0-ck8s1 - 2021-10-21

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
