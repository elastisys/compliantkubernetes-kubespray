# Upgrade v2.19.0-ck8s1 to v2.19.0-ck8s2

1. Checkout the new release: `git checkout v2.19.0-ck8s2`

1. Switch to the correct remote: `git submodule sync`

1. Update the kubespray submodule: `git submodule update --init --recursive`

1. This patch includes options to create OIDC kubeconfigs instead of regular kubeconfigs. If you want to switch to relying on using OIDC kubeconfigs, then follow "Switch to OIDC kubeconfig" below, otherwise follow "Keep using regular kubeconfigs" below.

## Switch to OIDC kubeconfig

1. Make the following changes to both `sc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml` and `wc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml`

    ```diff
    + kube_oidc_client_secret: <secret-from-IDP|secret-from-dex>
      kube_oidc_username_claim: "email"
      kube_oidc_groups_claim: "groups"
    + kube_oidc_extra_scopes: []
    + kube_oidc_apiserver_endpoint: <Public-IP/DNS-to-apiserver-or-loadbalancer>
    + kube_oidc_apiserver_port: "6443"
    + kubeconfig_file_name: <kube_config_sc.yaml|kube_config_wc.yaml>
    + artifacts_dir: "{{ inventory_dir }}/../.state"
    + create_oidc_kubeconfig: true
    + cluster_admin_users:
    + - <admin-user>
    + cluster_admin_groups:
    + - <admin-group>

    - kubeconfig_localhost: true
    ```

    Change the values in `<>` based on the details of the cluster. In general the service cluster should use IDP (google) and workload cluster should use dex. The `secret-from-dex` can be found in `secrets.yaml` from compliantkubernetes-apps under the key `dex.kubeloginClientSecret`.

1. For service clusters that is using dex as OIDC client it is recommended to switch to your IDP, for example Google. This allows the sc kubeconfig to work even if dex is down. To do that, change the following variables in `sc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml` to use the values from your IDP. For Google you cannot use the same OIDC client here as in dex, you must create an OAuth client of type `Desktop app`.

    ```yaml
    kube_oidc_url: <IDP-URL> #e.g. https://accounts.google.com/
    kube_oidc_client_id: <id-from-IDP>
    kube_oidc_client_secret: <secret-from-IDP>
    ```

    Then update the apiserver by running: `./bin/ck8s-kubespray run-playbook sc upgrade-cluster.yml -b --limit "kube_control_plane" --tags "download,master"`

1. If you are connecting directly to Google as an IDP, then you must remove `kube_oidc_groups_claim: "groups"`, since they do not support group claims via OIDC.

1. Create the new OIDC kubeconfigs by running: `./bin/ck8s-kubespray run-playbook sc ../playbooks/kubeconfig.yml -b` and `./bin/ck8s-kubespray run-playbook wc ../playbooks/kubeconfig.yml -b`. NOTE: this will overwrite any existing file at `kubeconfig_file_name` in `artifacts_dir`.

1. Create the new OIDC cluster admin RBAC by running: `./bin/ck8s-kubespray run-playbook sc ../playbooks/cluster_admin_rbac.yml -b` and `./bin/ck8s-kubespray run-playbook wc ../playbooks/cluster_admin_rbac.yml -b`

## Keep using regular kubeconfigs

1. Add the following to both `sc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml` and `wc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml`

    ```yaml
    kubeconfig_file_name: <kube_config_sc.yaml|kube_config_wc.yaml>
    artifacts_dir: "{{ inventory_dir }}/../.state"
    ```
