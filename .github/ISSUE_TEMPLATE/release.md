---
name: Create new release
about: Create a new release of Compliant Kubernetes Kubespray
title: Create release Compliant Kubernetes Kubespray <version>
labels: kind/release
assignees: ""
---

## Overview

> [!note]
> Whenever you need to change access from operator admin to `admin@example.com` prefer to re-login by clearing the `~/.kube/cache/oidc-login` cache instead of impersonation `--as=admin@example.com`.

- [Pre-QA steps](#user-content-pre-qa-steps)
- [Install QA steps](#user-content-install-qa-steps)
- [Upgrade QA steps](#user-content-upgrade-qa-steps)
- [Post-QA steps](#user-content-post-qa-steps)
- [Release steps](#user-content-release-steps)

## <a href="#user-content-pre-qa-steps" id="pre-qa-steps">#</a> Pre-QA steps

- [ ] Complete [the feature freeze step](https://github.com/elastisys/compliantkubernetes-kubespray/tree/main/release#feature-freeze)
- [ ] Complete [the staging step](https://github.com/elastisys/compliantkubernetes-kubespray/tree/main/release#staging)
- [ ] Complete all pre-QA steps in the internal checklist

## <a href="#user-content-install-qa-steps" id="install-qa-steps">#</a> Install QA steps

> _Kubespray install scenario_

### Infrastructure provider

- [ ] Cleura
- [ ] Elastx
- [ ] Exoscale
- [ ] Safespring
- [ ] UpCloud

### Configuration

- [ ] Flavor - Prod
- [ ] Dex IdP - Google
- [ ] Dex Static User - Enabled and `admin@example.com` added as an application developer
  <details><summary>Commands</summary>

  ```bash
  # configure
  yq4 -i '.grafana.user.oidc.allowedDomains += ["example.com"]' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i 'with(.opensearch.extraRoleMappings[]; with(select(.mapping_name != "all_access"); .definition.users += ["admin@example.com"]))' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.user.adminUsers += ["admin@example.com"]' "${CK8S_CONFIG_PATH}/wc-config.yaml"
  yq4 -i '.dex.enableStaticLogin = true' "${CK8S_CONFIG_PATH}/sc-config.yaml"

  pushd ~/path/to/apps/

  # apply
  ./bin/ck8s apply sc
  ./bin/ck8s apply wc

  popd
  ```

  </details>
- [ ] Set the environment variable `NAMESPACE` to an application developer namespace
- [ ] Set the environment variable `DOMAIN` to the environment domain

### Automated tests

> [!note]
> As platform administrator

- [ ] Successful `./bin/ck8s test sc|wc`
- [ ] From `tests/` successful `make build-main`
- [ ] From `tests/` successful `make ctr-run-end-to-end`

### Kubernetes access

> [!note]
> As platform administrator

- [ ] Can login as platform administrator via Dex with IdP

> [!note]
> As application developer `admin@example.com`

- [ ] Can login as application developer `admin@example.com` via Dex with static user
- [ ] Can list access

  ```bash
  kubectl -n "${NAMESPACE}" auth can-i --list
  ```

- [ ] Can delegate admin access

  ```console
  $ kubectl -n "${NAMESPACE}" edit rolebinding extra-workload-admins
    # Add some subject
    subjects:
      # You can specify more than one "subject"
      - kind: User
        name: jane # "name" is case sensitive
        apiGroup: rbac.authorization.k8s.io
  ```

- [ ] Can delegate view access

  ```console
  $ kubectl edit clusterrolebinding extra-user-view
    # Add some subject
    subjects:
      # You can specify more than one "subject"
      - kind: User
        name: jane # "name" is case sensitive
        apiGroup: rbac.authorization.k8s.io
  ```

- [ ] Cannot run with root by default

  ```bash
  kubectl apply -n "${NAMESPACE}" -f - <<EOF
  ---
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: allow-root-nginx
  spec:
    podSelector:
      matchLabels:
        app: root-nginx
    policyTypes:
      - Ingress
      - Egress
    ingress:
      - {}
    egress:
      - {}
  ---
  apiVersion: v1
  kind: Pod
  metadata:
    labels:
      app: root-nginx
    name: root-nginx
  spec:
    restartPolicy: Never
    containers:
      - name: nginx
        image: nginx:stable
        resources:
          requests:
            memory: 64Mi
            cpu: 250m
          limits:
            memory: 128Mi
            cpu: 500m
  EOF
  ```

### Hierarchical Namespaces

> [!note]
> As application developer `admin@example.com`

- [ ] [Can create a subnamespace by following the application developer docs](https://elastisys.io/compliantkubernetes/user-guide/namespaces/#namespace-management)
  <details><summary>Commands</summary>

  ```bash
  kubectl apply -n "${NAMESPACE}" -f - <<EOF
  apiVersion: hnc.x-k8s.io/v1alpha2
  kind: SubnamespaceAnchor
  metadata:
    name: ${NAMESPACE}-qa-test
  EOF

  kubectl get ns "${NAMESPACE}-qa-test"

  kubectl get subns -n "${NAMESPACE}" "${NAMESPACE}-qa-test" -o yaml
  ```

  </details>
- [ ] Ensure the default roles, rolebindings, and networkpolicies propagated
  <details><summary>Commands</summary>

  ```bash
  kubectl get role,rolebinding,netpol -n "${NAMESPACE}"
  kubectl get role,rolebinding,netpol -n "${NAMESPACE}-qa-test"
  ```

  </details>

### Harbor

> [!note]
> As application developer `admin@example.com`

- [ ] Can login as application developer via Dex with static user
  <details><summary>Steps</summary>

  - Login to Harbor with `admin@example.com`

    ```bash
    xdg-open "https://harbor.${DOMAIN}"
    ```

  - Login to Harbor with the admin user and promote `admin@example.com` to admin
  - Re-login with `admin@example.com`

  </details>
- [ ] [Can create projects and push images by following the application developer docs](https://elastisys.io/compliantkubernetes/user-guide/registry/#running-example)
- [ ] [Can configure image pull secret by following the application developer docs](https://elastisys.io/compliantkubernetes/user-guide/kubernetes-api/#configure-an-image-pull-secret)
- [ ] Can scan image for vulnerabilities
- [ ] Configure project to disallow vulnerabilities
  - Try to pull image with vulnerabilities, should fail

    ```bash
    docker pull "harbor.${DOMAIN}/${REGISTRY_PROJECT}/ck8s-user-demo:${TAG}"
    ```

- [ ] Configure project to allow vulnerabilities
  - Try to pull image with vulnerabilities, should succeed

    ```bash
    docker pull "harbor.${DOMAIN}/${REGISTRY_PROJECT}/ck8s-user-demo:${TAG}"
    ```

### Gatekeeper

> [!note]
> As application developer `admin@example.com`

- [ ] Can list OPA rules

  ```bash
  kubectl get constraints
  ```

> [!note]
> Using [the user demo helm chart](https://github.com/elastisys/compliantkubernetes/tree/main/user-demo/deploy/ck8s-user-demo)
>
> Set `NAMESPACE` to an application developer namespaces
> Set `PUBLIC_DOCS_PATH` to the path of the public docs repo

- [ ] With invalid image repository, try to deploy, should warn due to constraint

  ```bash
  helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/ck8s-user-demo" \
      --set image.repository="${REGISTRY_PROJECT}/ck8s-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}"
  ```

- [ ] With invalid image tag, try to deploy, should fail due to constraint

  ```bash
  helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/ck8s-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/ck8s-user-demo" \
      --set image.tag=latest \
      --set ingress.hostname="demoapp.${DOMAIN}"
  ```

- [ ] With unset networkpolicies, try to deploy, should warn due to constraint

  ```bash
  helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/ck8s-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/ck8s-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}" \
      --set networkPolicy.enabled=false
  ```

- [ ] With unset resources, try to deploy, should fail due to constraint

  ```bash
  helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/ck8s-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/ck8s-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}" \
      --set resources.requests=null
  ```

- [ ] With valid values, try to deploy, should succeed

  ```bash
  helm -n "${NAMESPACE}" upgrade --atomic --install "${PUBLIC_DOCS_PATH}/user-demo/deploy/ck8s-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/ck8s-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}"
  ```

### cert-manager and ingress-nginx

> [!note]
> As platform administrator

- [ ] All certificates ready including user demo
- [ ] All ingresses ready including user demo
  - [ ] Endpoints are reachable
  - [ ] Status includes correct IP addresses

### Metrics

> [!note]
> As platform administrator

- [ ] Can login to platform administrator Grafana via Dex with IdP
- [ ] Dashboards are available and viewable
- [ ] Metrics are available from all clusters

> [!note]
> As application developer `admin@example.com`

- [ ] Can login to application developer Grafana via Dex with static user
  <details><summary>Steps</summary>

  - Login to Grafana with `admin@example.com`

    ```bash
    xdg-open "https://grafana.${DOMAIN}"
    ```

  - Login to Grafana with the admin user and promote `admin@example.com` to admin
  - Re-login with `admin@example.com`

  </details>
- [ ] Welcome dashboard presented first
- [ ] Dashboards are available and viewable
- [ ] Metrics are available from all clusters
- [ ] Metrics are available from user demo application
- [ ] [CISO dashboards available and working](https://elastisys.io/compliantkubernetes/ciso-guide/)
  <details><summary>List</summary>

  - [Backup / Backup Status](https://elastisys.io/compliantkubernetes/ciso-guide/backup/)
  - [Cryptography / NGINX Ingress Controller](https://elastisys.io/compliantkubernetes/ciso-guide/cryptography/)
  - [Intrusion Detection / Falco](https://elastisys.io/compliantkubernetes/ciso-guide/intrusion-detection/)
  - [Policy-as-Code / Gatekeeper](https://elastisys.io/compliantkubernetes/ciso-guide/policy-as-code/)
  - [Network Security / NetworkPolicy](https://elastisys.io/compliantkubernetes/ciso-guide/network-security/)
  - [Capacity Management / Kubernetes Cluster Status](https://elastisys.io/compliantkubernetes/ciso-guide/capacity-management/)
  - [Vulnerability / Trivy Operator Dashboard](https://elastisys.io/compliantkubernetes/ciso-guide/vulnerability/)

  </details>

### Alerts

> [!note]
> As platform administrator

- [ ] No alert open except `Watchdog`, `CPUThrottlingHigh` and `FalcoAlert`
  - Can be seen in the alert section in platform administrator Grafana

> [!note]
> As application developer `admin@example.com`

- [ ] [Access Prometheus following the application developer docs](https://elastisys.io/compliantkubernetes/user-guide/metrics/#accessing-prometheus)
- [ ] Prometheus picked up user demo ServiceMonitor and PrometheusRule
- [ ] [Access Alertmanager following the application developer docs](https://elastisys.io/compliantkubernetes/user-guide/alerts/#accessing-user-alertmanager)
- [ ] Alertmanager `Watchdog` firing

### Logs

> [!note]
> As platform administrator

- [ ] Can login to OpenSearch Dashboards via Dex with IdP
- [ ] Indices created (authlog, kubeaudit, kubernetes, other)
- [ ] Indices managed (authlog, kubeaudit, kubernetes, other)
- [ ] Logs available (authlog, kubeaudit, kubernetes, other)
- [ ] Snapshots configured

> [!note]
> As application developer `admin@example.com`

- [ ] Can login to OpenSearch Dashboards via Dex with static user
- [ ] Welcome dashboard presented first
- [ ] Logs available (kubeaudit, kubernetes)
- [ ] [CISO dashboards available and working](https://elastisys.io/compliantkubernetes/ciso-guide/audit-logs/)

### Falco

> [!note]
> As platform administrator

- [ ] Deploy the [falcosecurity/event-generator](https://github.com/falcosecurity/event-generator#with-kubernetes) to generate events in wc
  <details><summary>Commands</summary>

  ```bash
  # Install

  kubectl create namespace event-generator
  kubectl label namespace event-generator owner=operator

  helm repo add falcosecurity https://falcosecurity.github.io/charts
  helm repo update

  helm -n event-generator install event-generator falcosecurity/event-generator \
      --set securityContext.runAsNonRoot=true \
      --set securityContext.runAsGroup=65534 \
      --set securityContext.runAsUser=65534 \
      --set podSecurityContext.fsGroup=65534 \
      --set config.actions=""

  # Uninstall

  helm -n event-generator uninstall event-generator
  kubectl delete namespace event-generator
  ```

  </details>

- [ ] Logs are available in OpenSearch Dashboards
- [ ] Logs are relevant

### Network policies

- [ ] No dropped packets in NetworkPolicy Grafana dashboard

#### Infrastructure tests

- [ ] Able to run `terraform plan` without changes
- [ ] Able to add nodes without issues
- [ ] Able to remove nodes without issues

## <a href="#user-content-upgrade-qa-steps" id="upgrade-qa-steps">#</a> Upgrade QA steps

> _Kubespray upgrade scenario_

> [!note]
> The upgrade is done as part of the checklist.

### Infrastructure provider

- [ ] Cleura
- [ ] Elastx
- [ ] Exoscale
- [ ] Safespring
- [ ] UpCloud

### Configuration

- [ ] Flavor - Prod
- [ ] Dex IdP - Google
- [ ] Dex Static User - Enabled and `admin@example.com` added as an application developer
  <details><summary>Commands</summary>

  ```bash
  # configure
  yq4 -i '.grafana.user.oidc.allowedDomains += ["example.com"]' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i 'with(.opensearch.extraRoleMappings[]; with(select(.mapping_name != "all_access"); .definition.users += ["admin@example.com"]))' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.user.adminUsers += ["admin@example.com"]' "${CK8S_CONFIG_PATH}/wc-config.yaml"
  yq4 -i '.dex.enableStaticLogin = true' "${CK8S_CONFIG_PATH}/sc-config.yaml"

  pushd ~/path/to/apps/

  # apply
  ./bin/ck8s apply sc
  ./bin/ck8s apply wc

  popd
  ```

  </details>
- [ ] Set the environment variable `NAMESPACE` to an application developer namespace
- [ ] Set the environment variable `DOMAIN` to the environment domain

#### Upgrade

- [ ] Can upgrade according to [the migration docs for this version](https://github.com/elastisys/compliantkubernetes-kubespray/tree/main/migration)

### Automated tests

> [!note]
> As platform administrator

- [ ] Successful `./bin/ck8s test sc|wc`
- [ ] From `tests/` successful `make build-main`
- [ ] From `tests/` successful `make ctr-run-end-to-end`

### Kubernetes access

> [!note]
> As platform administrator

- [ ] Can login as platform administrator via Dex with IdP

> [!note]
> As application developer `admin@example.com`

- [ ] Can login as application developer `admin@example.com` via Dex with static user
- [ ] Can list access

  ```bash
  kubectl -n "${NAMESPACE}" auth can-i --list
  ```

- [ ] Can delegate admin access

  ```console
  $ kubectl -n "${NAMESPACE}" edit rolebinding extra-workload-admins
    # Add some subject
    subjects:
      # You can specify more than one "subject"
      - kind: User
        name: jane # "name" is case sensitive
        apiGroup: rbac.authorization.k8s.io
  ```

- [ ] Can delegate view access

  ```console
  $ kubectl edit clusterrolebinding extra-user-view
    # Add some subject
    subjects:
      # You can specify more than one "subject"
      - kind: User
        name: jane # "name" is case sensitive
        apiGroup: rbac.authorization.k8s.io
  ```

- [ ] Cannot run with root by default

  ```bash
  kubectl apply -n "${NAMESPACE}" -f - <<EOF
  ---
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: allow-root-nginx
  spec:
    podSelector:
      matchLabels:
        app: root-nginx
    policyTypes:
      - Ingress
      - Egress
    ingress:
      - {}
    egress:
      - {}
  ---
  apiVersion: v1
  kind: Pod
  metadata:
    labels:
      app: root-nginx
    name: root-nginx
  spec:
    restartPolicy: Never
    containers:
      - name: nginx
        image: nginx:stable
        resources:
          requests:
            memory: 64Mi
            cpu: 250m
          limits:
            memory: 128Mi
            cpu: 500m
  EOF
  ```

### Hierarchical Namespaces

> [!note]
> As application developer `admin@example.com`

- [ ] [Can create a subnamespace by following the application developer docs](https://elastisys.io/compliantkubernetes/user-guide/namespaces/#namespace-management)
  <details><summary>Commands</summary>

  ```bash
  kubectl apply -n "${NAMESPACE}" -f - <<EOF
  apiVersion: hnc.x-k8s.io/v1alpha2
  kind: SubnamespaceAnchor
  metadata:
    name: ${NAMESPACE}-qa-test
  EOF

  kubectl get ns "${NAMESPACE}-qa-test"

  kubectl get subns -n "${NAMESPACE}" "${NAMESPACE}-qa-test" -o yaml
  ```

  </details>
- [ ] Ensure the default roles, rolebindings, and networkpolicies propagated
  <details><summary>Commands</summary>

  ```bash
  kubectl get role,rolebinding,netpol -n "${NAMESPACE}"
  kubectl get role,rolebinding,netpol -n "${NAMESPACE}-qa-test"
  ```

  </details>

### Harbor

> [!note]
> As application developer `admin@example.com`

- [ ] Can login as application developer via Dex with static user
  <details><summary>Steps</summary>

  - Login to Harbor with `admin@example.com`

    ```bash
    xdg-open "https://harbor.${DOMAIN}"
    ```

  - Login to Harbor with the admin user and promote `admin@example.com` to admin
  - Re-login with `admin@example.com`

  </details>
- [ ] [Can create projects and push images by following the application developer docs](https://elastisys.io/compliantkubernetes/user-guide/registry/#running-example)
- [ ] [Can configure image pull secret by following the application developer docs](https://elastisys.io/compliantkubernetes/user-guide/kubernetes-api/#configure-an-image-pull-secret)
- [ ] Can scan image for vulnerabilities
- [ ] Configure project to disallow vulnerabilities
  - Try to pull image with vulnerabilities, should fail

    ```bash
    docker pull "harbor.${DOMAIN}/${REGISTRY_PROJECT}/ck8s-user-demo:${TAG}"
    ```

- [ ] Configure project to allow vulnerabilities
  - Try to pull image with vulnerabilities, should succeed

    ```bash
    docker pull "harbor.${DOMAIN}/${REGISTRY_PROJECT}/ck8s-user-demo:${TAG}"
    ```

### Gatekeeper

> [!note]
> As application developer `admin@example.com`

- [ ] Can list OPA rules

  ```bash
  kubectl get constraints
  ```

> [!note]
> Using [the user demo helm chart](https://github.com/elastisys/compliantkubernetes/tree/main/user-demo/deploy/ck8s-user-demo)
>
> Set `NAMESPACE` to an application developer namespaces
> Set `PUBLIC_DOCS_PATH` to the path of the public docs repo

- [ ] With invalid image repository, try to deploy, should warn due to constraint

  ```bash
  helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/ck8s-user-demo" \
      --set image.repository="${REGISTRY_PROJECT}/ck8s-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}"
  ```

- [ ] With invalid image tag, try to deploy, should fail due to constraint

  ```bash
  helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/ck8s-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/ck8s-user-demo" \
      --set image.tag=latest \
      --set ingress.hostname="demoapp.${DOMAIN}"
  ```

- [ ] With unset networkpolicies, try to deploy, should warn due to constraint

  ```bash
  helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/ck8s-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/ck8s-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}" \
      --set networkPolicy.enabled=false
  ```

- [ ] With unset resources, try to deploy, should fail due to constraint

  ```bash
  helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/ck8s-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/ck8s-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}" \
      --set resources.requests=null
  ```

- [ ] With valid values, try to deploy, should succeed

  ```bash
  helm -n "${NAMESPACE}" upgrade --atomic --install "${PUBLIC_DOCS_PATH}/user-demo/deploy/ck8s-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/ck8s-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}"
  ```

### cert-manager and ingress-nginx

> [!note]
> As platform administrator

- [ ] All certificates ready including user demo
- [ ] All ingresses ready including user demo
  - [ ] Endpoints are reachable
  - [ ] Status includes correct IP addresses

### Metrics

> [!note]
> As platform administrator

- [ ] Can login to platform administrator Grafana via Dex with IdP
- [ ] Dashboards are available and viewable
- [ ] Metrics are available from all clusters

> [!note]
> As application developer `admin@example.com`

- [ ] Can login to application developer Grafana via Dex with static user
  <details><summary>Steps</summary>

  - Login to Grafana with `admin@example.com`

    ```bash
    xdg-open "https://grafana.${DOMAIN}"
    ```

  - Login to Grafana with the admin user and promote `admin@example.com` to admin
  - Re-login with `admin@example.com`

  </details>
- [ ] Welcome dashboard presented first
- [ ] Dashboards are available and viewable
- [ ] Metrics are available from all clusters
- [ ] Metrics are available from user demo application
- [ ] [CISO dashboards available and working](https://elastisys.io/compliantkubernetes/ciso-guide/)
  <details><summary>List</summary>

  - [Backup / Backup Status](https://elastisys.io/compliantkubernetes/ciso-guide/backup/)
  - [Cryptography / NGINX Ingress Controller](https://elastisys.io/compliantkubernetes/ciso-guide/cryptography/)
  - [Intrusion Detection / Falco](https://elastisys.io/compliantkubernetes/ciso-guide/intrusion-detection/)
  - [Policy-as-Code / Gatekeeper](https://elastisys.io/compliantkubernetes/ciso-guide/policy-as-code/)
  - [Network Security / NetworkPolicy](https://elastisys.io/compliantkubernetes/ciso-guide/network-security/)
  - [Capacity Management / Kubernetes Cluster Status](https://elastisys.io/compliantkubernetes/ciso-guide/capacity-management/)
  - [Vulnerability / Trivy Operator Dashboard](https://elastisys.io/compliantkubernetes/ciso-guide/vulnerability/)

  </details>

### Alerts

> [!note]
> As platform administrator

- [ ] No alert open except `Watchdog`, `CPUThrottlingHigh` and `FalcoAlert`
  - Can be seen in the alert section in platform administrator Grafana

> [!note]
> As application developer `admin@example.com`

- [ ] [Access Prometheus following the application developer docs](https://elastisys.io/compliantkubernetes/user-guide/metrics/#accessing-prometheus)
- [ ] Prometheus picked up user demo ServiceMonitor and PrometheusRule
- [ ] [Access Alertmanager following the application developer docs](https://elastisys.io/compliantkubernetes/user-guide/alerts/#accessing-user-alertmanager)
- [ ] Alertmanager `Watchdog` firing

### Logs

> [!note]
> As platform administrator

- [ ] Can login to OpenSearch Dashboards via Dex with IdP
- [ ] Indices created (authlog, kubeaudit, kubernetes, other)
- [ ] Indices managed (authlog, kubeaudit, kubernetes, other)
- [ ] Logs available (authlog, kubeaudit, kubernetes, other)
- [ ] Snapshots configured

> [!note]
> As application developer `admin@example.com`

- [ ] Can login to OpenSearch Dashboards via Dex with static user
- [ ] Welcome dashboard presented first
- [ ] Logs available (kubeaudit, kubernetes)
- [ ] [CISO dashboards available and working](https://elastisys.io/compliantkubernetes/ciso-guide/audit-logs/)

### Falco

> [!note]
> As platform administrator

- [ ] Deploy the [falcosecurity/event-generator](https://github.com/falcosecurity/event-generator#with-kubernetes) to generate events in wc
  <details><summary>Commands</summary>

  ```bash
  # Install

  kubectl create namespace event-generator
  kubectl label namespace event-generator owner=operator

  helm repo add falcosecurity https://falcosecurity.github.io/charts
  helm repo update

  helm -n event-generator install event-generator falcosecurity/event-generator \
      --set securityContext.runAsNonRoot=true \
      --set securityContext.runAsGroup=65534 \
      --set securityContext.runAsUser=65534 \
      --set podSecurityContext.fsGroup=65534 \
      --set config.actions=""

  # Uninstall

  helm -n event-generator uninstall event-generator
  kubectl delete namespace event-generator
  ```

  </details>

- [ ] Logs are available in OpenSearch Dashboards
- [ ] Logs are relevant

### Network policies

- [ ] No dropped packets in NetworkPolicy Grafana dashboard

#### Infrastructure tests

- [ ] Able to run `terraform plan` without changes
- [ ] Able to add nodes without issues
- [ ] Able to remove nodes without issues

## <a href="#user-content-post-qa-steps" id="post-qa-steps">#</a> Post-QA steps

- [ ] Complete [the code freeze step](https://github.com/elastisys/compliantkubernetes-kubespray/tree/main/release#code-freeze)
- [ ] Complete all post-QA steps in the internal checklist

## <a href="#user-content-release-steps" id="release-steps">#</a> Release steps

- [ ] Complete [the release step](https://github.com/elastisys/compliantkubernetes-kubespray/tree/main/release#release)
- [ ] Complete [the update public release notes step](https://github.com/elastisys/compliantkubernetes-kubespray/tree/main/release#update-public-release-notes)
- [ ] Complete [the update the main branch step](https://github.com/elastisys/compliantkubernetes-kubespray/tree/main/release#update-the-main-branch)
- [ ] Complete all post release steps in the internal checklist
