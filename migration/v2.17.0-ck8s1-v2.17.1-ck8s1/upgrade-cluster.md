# Upgrade v2.17.0-ck8s1 to v2.17.1-ck8s1

1. Checkout the new release: `git checkout v2.17.1-ck8s1`

1. Update the kubespray submodule: `git submodule update --init --recursive`

1. Upgrade your cluster by running `./bin/ck8s-kubespray run-playbook sc upgrade-cluster.yml -b`.
    Note that this will also upgrade Kubernetes to v1.21.6 (unless you have another version pinned).

1. Upgrade your cluster by running `./bin/ck8s-kubespray run-playbook wc upgrade-cluster.yml -b`.
    Note that this will also upgrade Kubernetes to v1.21.6 (unless you have another version pinned).
