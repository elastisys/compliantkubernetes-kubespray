### Changed

- Reworked rook-ceph setup to use helmfile with everything included
- Changed `prune-docker` script/playbook to `prune-nerdctl` which now uses `nerdctl` instead of `docker`

### Updated

- Rook version v1.11.9 and Ceph v17.2.6
- Updated kubespray to v2.23.0
  - Branch `v2.23.0+terraform-fix+node-local-dns-egress-ipv6+dhcp-critical`

### Added

- Test script for `rook-ceph`
