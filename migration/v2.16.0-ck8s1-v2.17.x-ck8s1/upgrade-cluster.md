# Upgrade v2.16.0-ck8s1 to v2.17.x-ck8s1

1. Checkout the new release: `git checkout v2.17.x-ck8s1`

1. Update the kubespray submodule: `git submodule update --init --recursive`

1. Upgrade your cluster by running `./bin/ck8s-kubespray run-playbook sc upgrade-cluster.yml -b`.

1. Upgrade your cluster by running `./bin/ck8s-kubespray run-playbook wc upgrade-cluster.yml -b`.

Unless you have another Kubernetes version pinned, upgrading the kubespray version will also upgrade Kubernetes to:

- v1.21.5 (kubespray v2.17.0)
- v1.21.6 (kubespray v2.17.1)
