#!/bin/bash

set -euo pipefail

here="$(dirname "$(readlink -f "${0}")")"
root="$(dirname "$(dirname "${here}")")"

kubespray_path="${root}/kubespray"
playbooks_path="${root}/playbooks"

render_template_playbook="${playbooks_path}/render_templates.yml"

digests_file="digests.yaml"
images_file_apps="images-apps.yaml"
images_file_kubeadm="images-kubeadm.yaml"

inventory_path="${here}/inventory.yaml"
kubeadm_image_template_path="${here}/kubeadm-images.j2"
kubeadm_patches_template_path="${here}/kubeadm-patches.yaml.j2"
variable_prefixes_path="${here}/variable-prefixes.yaml"

config_image_tags_path="${root}/config/common/group_vars/all/ck8s-image-tags.yaml"
config_kubeadm_patches_path="${root}/config/common/group_vars/all/ck8s-kubeadm-patches.yaml"
config_kube_proxy_image_path="${root}/config/ck8s-kube-proxy-image"

declare -a variable_files=(
  "${kubespray_path}/roles/kubespray_defaults/defaults/main/main.yml"
  "${kubespray_path}/roles/kubespray_defaults/defaults/main/download.yml"
  "${kubespray_path}/roles/kubespray_defaults/vars/main/main.yml"
  "${kubespray_path}/roles/kubespray_defaults/vars/main/checksums.yml"
  "${kubespray_path}/roles/kubernetes-apps/csi_driver/cinder/defaults/main.yml"
  "${kubespray_path}/roles/kubernetes-apps/csi_driver/upcloud/defaults/main.yml"
)

get_kubespray_version() {
  pushd "${kubespray_path}" >/dev/null
  git rev-parse HEAD
  popd >/dev/null
}

_template_images_apps() {
  local var_prefix

  while IFS= read -r var_prefix; do
    case "${var_prefix}" in
    upcloud_csi_plugin_image)
      echo "${var_prefix}: \"ghcr.io/upcloudltd/upcloud-csi:{{ upcloud_csi_plugin_image_tag }}\""
      ;;
    upcloud_csi_provisioner_image)
      echo "${var_prefix}: \"registry.k8s.io/sig-storage/csi-provisioner:{{ upcloud_csi_provisioner_image_tag }}\""
      ;;
    upcloud_csi_attacher_image)
      echo "${var_prefix}: \"registry.k8s.io/sig-storage/csi-attacher:{{ upcloud_csi_attacher_image_tag }}\""
      ;;
    upcloud_csi_resizer_image)
      echo "${var_prefix}: \"registry.k8s.io/sig-storage/csi-resizer:{{ upcloud_csi_resizer_image_tag }}\""
      ;;
    upcloud_csi_snapshotter_image)
      echo "${var_prefix}: \"k8s.gcr.io/sig-storage/csi-snapshotter:{{ upcloud_csi_snapshotter_image_tag }}\""
      ;;
    upcloud_csi_node_image)
      echo "${var_prefix}: \"registry.k8s.io/sig-storage/csi-node-driver-registrar:{{ upcloud_csi_node_image_tag }}\""
      ;;

    cinder_csi_attacher_image | cinder_csi_provisioner_image | cinder_csi_resizer_image | cinder_csi_snapshotter_image | cinder_csi_livenessprobe_image)
      local component
      component=$(echo "${var_prefix}" | sed -E 's/cinder_csi_(.*)_image/\1/')
      echo "${var_prefix}: \"{{ csi_${component}_image_repo }}:{{ ${var_prefix}_tag }}\""
      ;;

    *)
      echo "${var_prefix}: \"{{ ${var_prefix}_repo }}:{{ ${var_prefix}_tag }}\""
      ;;
    esac
  done <"${variable_prefixes_path}"
}

_render_template() {
  local template="${1}"
  local output="${2}"
  shift 2

  if [ -z "${CK8S_KUBESPRAY_NO_VENV+x}" ]; then
    pushd "${kubespray_path}" >/dev/null
    python3 -m venv venv
    # shellcheck disable=SC1091
    source venv/bin/activate
    pip install -r requirements.txt
    popd >/dev/null
  fi

  ansible-playbook \
    -i "${inventory_path}" \
    -e "$(jq -cn '$ARGS.positional | {variable_files: .}' --args "${variable_files[@]}")" \
    -e "$(jq -cn --arg k "${output}" --arg v "${template}" '{template_files: {($k): $v}}')" \
    "${render_template_playbook}" "${@}"
}

render_images_apps() {
  mkdir -p "${here}/${kubespray_version}"

  (
    local template
    template="$(mktemp)" && trap 'rm -f "${template}"' EXIT

    _template_images_apps >"${template}"

    _render_template "${template}" "${images_path_apps}"
  )
}

render_images_kubeadm() {
  mkdir -p "${here}/${kubespray_version}"

  _render_template "${kubeadm_image_template_path}" "${images_path_kubeadm}"
}

_digest_fetch() {
  local image="${1}"

  local digest

  if image="${image}" yq --exit-status 'has(strenv(image))' "${digests_path}" 1>/dev/null 2>&1; then
    echo "Digest already fetched for ${image}, skipping" >&2
    return 0
  fi

  echo "Fetching digest for image ${image}" >&2

  if digest=$(skopeo inspect --format '{{.Digest}}' "docker://${image}"); then
    image="${image}" digest="${digest}" yq -i '.[strenv(image)] = strenv(digest)' "${digests_path}"
  else
    echo "ERROR: Could not find digest for image ${image}" >&2
    exit 1
  fi
}

digests() {
  local image

  mkdir -p "${here}/${kubespray_version}"
  touch "${digests_path}"

  for image in $(yq '.[]' "${images_path_apps}"); do
    _digest_fetch "${image}"
  done

  for image in $(yq '.[]' "${images_path_kubeadm}"); do
    _digest_fetch "${image}"
  done
}

_digest_get() {
  local image="${1}"

  if ! image="${image}" yq --exit-status '.[strenv(image)]' "${digests_path}"; then
    echo "Failed to get digest ${image}" >&2
    return 1
  fi
}

_config_image_tags() {
  local digest image tag var_prefix

  while IFS= read -r var_prefix; do
    if ! image="$(var_prefix="${var_prefix}" yq --exit-status '.[strenv(var_prefix)]' "${images_path_apps}")"; then
      echo "Failed to get image for ${var_prefix}" >&2
      exit 1
    fi

    tag="$(echo "${image}" | cut -d':' -f 2)"
    digest="$(_digest_get "${image}")"

    echo "${var_prefix}_tag: ${tag}@${digest}"
  done <"${variable_prefixes_path}" >"${config_image_tags_path}"
}

_config_kubeadm_patches() {
  local kube_apiserver_image
  kube_apiserver_image="$(key="kube_apiserver_image" yq --exit-status '.[strenv(key)]' "${images_path_kubeadm}")"
  local kube_controller_manager_image
  kube_controller_manager_image="$(key="kube_controller_manager_image" yq --exit-status '.[strenv(key)]' "${images_path_kubeadm}")"
  local kube_scheduler_image
  kube_scheduler_image="$(key="kube_scheduler_image" yq --exit-status '.[strenv(key)]' "${images_path_kubeadm}")"

  local kube_apiserver_digest
  kube_apiserver_digest="$(_digest_get "${kube_apiserver_image}")"
  local kube_controller_manager_digest
  kube_controller_manager_digest="$(_digest_get "${kube_controller_manager_image}")"
  local kube_scheduler_digest
  kube_scheduler_digest="$(_digest_get "${kube_scheduler_image}")"

  _render_template "${kubeadm_patches_template_path}" "${config_kubeadm_patches_path}" \
    -e "kube_apiserver_image=${kube_apiserver_image}@${kube_apiserver_digest}" \
    -e "kube_controller_manager_image=${kube_controller_manager_image}@${kube_controller_manager_digest}" \
    -e "kube_scheduler_image=${kube_scheduler_image}@${kube_scheduler_digest}"
}

_config_kube_proxy_image() {
  local kube_proxy_image
  kube_proxy_image="$(key="kube_proxy_image" yq --exit-status '.[strenv(key)]' "${images_path_kubeadm}")"
  local kube_proxy_digest
  kube_proxy_digest="$(_digest_get "${kube_proxy_image}")"

  echo "${kube_proxy_image}@${kube_proxy_digest}" >"${config_kube_proxy_image_path}"
}

config() {
  _config_image_tags
  _config_kubeadm_patches
  _config_kube_proxy_image
}

_check_fail() {
  echo "Run this to pin all the image digests in the default config: ${0}" >&2
  exit 1
}

_check_image_files() {
  if [ ! -f "${images_path_apps}" ]; then
    echo "Kubernetes apps images output for Kubespray version ${kubespray_version} does not exist" >&2
    _check_fail
  fi

  if [ ! -f "${images_path_kubeadm}" ]; then
    echo "Kubeadm images output for Kubespray version ${kubespray_version} does not exist" >&2
    _check_fail
  fi
}

_check_digests() {
  local image

  for image in $(yq '.[]' "${images_path_apps}"); do
    if ! _digest_get "${image}" 1>/dev/null 2>&1; then
      echo "Kubernetes apps image ${image} is missing digest" >&2
      _check_fail
    fi
  done

  for image in $(yq '.[]' "${images_path_kubeadm}"); do
    if ! _digest_get "${image}" 1>/dev/null 2>&1; then
      echo "Kubeadm image ${image} is missing digest" >&2
      _check_fail
    fi
  done
}

_check_config_apps() {
  local config_tag pinned_digest pinned_image pinned_tag var_prefix

  while IFS= read -r var_prefix; do
    if ! config_tag="$(var="${var_prefix}_tag" yq --exit-status '.[strenv(var)]' "${config_image_tags_path}" 2>/dev/null)"; then
      echo "Missing image tag in default config ${config_image_tags_path}: ${var_prefix}_tag" >&2
      _check_fail
    fi

    pinned_image="$(var="${var_prefix}" yq --exit-status '.[strenv(var)]' "${images_path_apps}" 2>/dev/null)"
    pinned_tag="$(echo "${pinned_image}" | cut -d : -f 2)"
    pinned_digest="$(image="${pinned_image}" yq --exit-status '.[strenv(image)]' "${digests_path}" 2>/dev/null)"

    if [ "${config_tag}" != "${pinned_tag}@${pinned_digest}" ]; then
      echo "Image tag ${var_prefix}_tag in default config ${config_image_tags_path} differs from pinned tag and digest ${config_tag} != ${pinned_tag}@${pinned_digest}" >&2
      _check_fail
    fi
  done <"${variable_prefixes_path}"
}

_check_config_kubeadm() {
  local name="${1}"

  local config_image pinned_image

  pinned_image="$(grep -F "${name}" "${digests_path}" | sed 's/: sha256:/@sha256:/')"

  config_image="$(name="${name}" yq --exit-status '.kubeadm_patches[] | select(.target == strenv(name)).patch.spec.containers[0].image' "${config_kubeadm_patches_path}")"

  if [ "${pinned_image}" != "${config_image}" ]; then
    echo "The Kubeadm image in the default config ${config_image} differs from the pinned image for this Kubespray version ${pinned_image}" >&2
    _check_fail
  fi
}

_check_config_kube_proxy() {
  local config_image pinned_image

  pinned_image="$(grep -F "kube-proxy" "${digests_path}" | sed 's/: sha256:/@sha256:/')"

  config_image="$(cat "${config_kube_proxy_image_path}")"

  if [ "${pinned_image}" != "${config_image}" ]; then
    echo "The kube-proxy image in the default config ${config_image} differs from the pinned image for this Kubespray version ${pinned_image}" >&2
    _check_fail
  fi
}

_check_config() {
  _check_config_apps

  _check_config_kubeadm kube-apiserver
  _check_config_kubeadm kube-controller-manager
  _check_config_kubeadm kube-scheduler

  _check_config_kube_proxy
}

check() {
  _check_image_files
  _check_digests
  _check_config
}

kubespray_version=$(get_kubespray_version)

images_path_apps="${here}/${kubespray_version}/${images_file_apps}"
images_path_kubeadm="${here}/${kubespray_version}/${images_file_kubeadm}"
digests_path="${here}/${kubespray_version}/${digests_file}"

case "${1:-}" in
"render-images-apps") render_images_apps ;;
"render-images-kubeadm") render_images_kubeadm ;;
"digests") digests ;;
"config") config ;;
"check") check ;;
*) render_images_apps && render_images_kubeadm && digests && config ;;
esac
