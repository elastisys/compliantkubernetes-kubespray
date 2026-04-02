# Kubespray Image Pinner

This tool automates the pinning of Kubernetes container images to their immutable SHA256 digests.
By updating our Kubespray configuration to use explicit digests (while preserving the human-readable tags), we guarantee deterministic, reproducible, and secure cluster deployments that are immune to tag-mutation attacks.

## Usage

```bash
./pin-digests.sh
```

## How It Works

The script executes the pinning process in three distinct phases, caching data under a directory named after the current Kubespray Git commit (e.g., `./[kubespray-commit]/`).

### 1. Render Images

First, the script evaluates Kubespray's native Ansible variables to determine the exact image tags our flavor of Kubernetes intends to deploy.

- For each variable prefix listed in [`variable-prefixes.yaml`](./variable-prefixes.yaml), the script templates an image string by appending `_repo` and `_tag`.
  > **Example:** `cinder_csi_plugin_image` is templated as `{{ cinder_csi_plugin_image_repo }}:{{ cinder_csi_plugin_image_tag }}`, which resolves to `registry.k8s.io/provider-os/cinder-csi-plugin:v1.30.0`.
- **Apps:** Standard cluster add-on images are rendered to `./[kubespray-commit]/images-apps.yaml`.
- **Kubeadm:** Core control plane images are rendered to `./[kubespray-commit]/images-kubeadm.yaml`.

### 2. Fetch Digests

Next, the script iterates through the rendered images and uses `skopeo` to query their upstream container registries.
The fetched SHA256 digests are cached locally in `./[kubespray-commit]/digests.yaml`.
If a digest has already been fetched for a specific commit, the script skips querying the registry again.

### 3. Update Configuration

Finally, the script generates the exact configuration files needed to enforce the immutable images during the Kubespray run.
We use a `tag@digest` format (e.g., `v1.30.0@sha256:5a9937...`) to ensure machine immutability while preserving human readability.

It updates three core files:

[Image Tag Configuration](/config/common/group_vars/all/ck8s-image-tags.yaml): Updates standard Kubespray variables (e.g., `cinder_csi_plugin_image_tag`).
[Kubeadm Patches Configuration](/config/common/group_vars/all/ck8s-kubeadm-patches.yaml): Generates the `kubeadm_patches` list required to pin the static control plane pods (API server, controller manager, scheduler) during `kubeadm init`.
[Kube-proxy File](/config/ck8s-kube-proxy-image): Outputs the raw digest string for `kube-proxy`, which is required for post-install/upgrade procedures since `kubeadm` cannot natively patch proxy addons.

## Maintenance & Kubespray Upgrades

When upgrading your Kubespray version, running this script is usually all you need to do to generate the new digests.
However, watch out for upstream changes:

- **New Images:** If the new Kubespray release introduces (or if we start using) entirely new images, you must add their prefixes to [`variable-prefixes.yaml`](./variable-prefixes.yaml) before running the script.
- **Variable Locations:** The variable prefixes are traditionally located in Kubespray's [download.yml](https://github.com/kubernetes-sigs/kubespray/blob/master/roles/kubespray_defaults/defaults/main/download.yml).
  If an upstream update moves these definitions to a new file, you must update the `variable_files` array inside this script to ensure Ansible can find and render them.
