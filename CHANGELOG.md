# Compliant Kubernetes Kubespray changelog
<!-- BEGIN TOC -->
- [v2.23.0-ck8s2](#v2230-ck8s2---2024-01-11)
- [v2.23.0-ck8s1](#v2230-ck8s1---2023-09-28)
- [v2.21.0-ck8s4](#v2210-ck8s4---2023-07-14)
- [v2.22.1-ck8s1](#v2221-ck8s1---2023-07-12)
- [v2.21.0-ck8s1](#v2210-ck8s1---2023-02-06)
- [v2.20.0-ck8s1](#v2200-ck8s1---2022-10-10)
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
## v2.23.0-ck8s2 - 2024-01-11

### Updated

- Update ansible syntax for verify-settings.yml

-------------------------------------------------
## v2.23.0-ck8s1 - 2023-09-28

### Changed

- Reworked rook-ceph setup to use helmfile with everything included
- Changed `prune-docker` script/playbook to `prune-nerdctl` which now uses `nerdctl` instead of `docker`
- Changed the `run-playbook` script to run playbooks in the `playbooks` directory instead of the root of the kubespray repository.

### Updated

- Rook version v1.11.9 and Ceph v17.2.6
- Updated kubespray to v2.23.0
  - Branch `v2.23.0+terraform-fix+node-local-dns-egress-ipv6+dhcp-critical`

### Added

- Test script for `rook-ceph`

-------------------------------------------------
## v2.21.0-ck8s4 - 2023-07-14

### Fixed

- missing `s` from `containerd_enable_unprivileged_ports`

-------------------------------------------------
## v2.22.1-ck8s1 - 2023-07-12

### Release notes

- This version upgrades Kubernetes to `v1.26`

### Added

- Add additional pre-commit checks
- Add new configuration file with compliantkubernetes-kubespray version
- Dependency check to main bin scripts
- Added missing logging functions

### Changed

- Updated the Kubernetes audit log policy file
- Added PSA labels for rook-ceph
- Disabled Kubernetes PSPs for rook-ceph
- Upgraded kubespray to v2.22.1

### Fixed

- Reboot scripts uses inventory hostnames instead of machine hostnames
- Upgraded Terraform to version 1.3.9
- Removed debug logs
- Updated comments in migration script to reflect the actual functions
- Fixed migration script to 2.22

-------------------------------------------------
## v2.21.0-ck8s1 - 2023-02-06

### Release notes

- This version upgrades Kubernetes to `v1.25` in which Pod Security Policies (PSPs) are removed. You should not upgrade to this version if you are using PSPs. To deploy [Compliant Kubernetes Apps](https://github.com/elastisys/compliantkubernetes-apps) on this version it needs to be on a compatible version which depends on [this issue](https://github.com/elastisys/compliantkubernetes-apps/issues/1218).
- This version requires at least terraform `0.14.0` in order to provision infrastructure using the kubespray provided terraform modules.
- If you are using the rook-ceph operator you can read the [migration docs](rook/migration/rook-1.5.x-rook-1.10.5/upgrade.md) on how to upgrade these components.

### Fixed

- Changed a Kubespray variable which is required for upgrading clusters on cloud providers that don't have external IPs on their control plane nodes.

### Changed

- Changed terraform scripts for openstack to be able to setup additional server groups and override variables per instance.
- Enabled the `ceph` dashboard for better visibility and troubleshooting of `rook-ceph`
- Upgraded rook-ceph operator to `v1.10.5` and ceph to `v17.2.5`
- Now defaulting to serial execution when running the upgrade playbook.
- Switched from using upstream kubespray repo to the elastisys fork.

### Added

- Added a get-requirements file to standardize which terraform version to use, `1.2.9`.
- Add ntp.se as ntp server as standard
- Added a script that creates a migration document from a template.

-------------------------------------------------
## v2.20.0-ck8s1 - 2022-10-10

### Release notes
- Scripts are now using yq version 4
  - Requires `yq4` as an alias to yq v4.

### Changed

- pre-commit rev update to `2.2.0-rc.1`
- Scripts are now using yq version 4
- Bumped upcloud csi driver to `v0.3.3`
- Switched back from fork of kubespray to original kubespray repo

## Fixed
- Fixed multiple kube-bench fails (01.03.07, 01.04.01, 01.04.02)

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
