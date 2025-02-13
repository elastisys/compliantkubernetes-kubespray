# Quality Assurance Checklist

Elastisys Welkin® Kubespray

## Checklist

> [!note]
> This document is maintained as a reference for the quality assurance checklist for Welkin Kubespray.
> The actual release and quality assurance process is driven by an internal issue template, as it also ties together with internal processes, however these are templated from the same source so the main steps are accurate.

### Overview

**Sections**:

- [Before QA steps](#before-qa-steps)
- [Install QA steps](#install-qa-steps)
- [Upgrade QA steps](#upgrade-qa-steps)
- [After QA steps](#after-qa-steps)
- [Release steps](#release-steps)
- [Final steps](#final-steps)

### Before QA steps

> [!note]
> Whenever you need to change access from platform administrator to application developer `admin@example.com` prefer to re-login rather than impersonation `--as=admin@example.com`.
> For this you have two options:
>
> - Either set a different cache directory `export KUBECACHEDIR=${HOME}/.kube-static/cache` when switching to application developer and restore `unset KUBECACHEDIR` when switching to platform administrator.
> - Or clear the cache `rm -r ~/.kube/cache/oidc-login` whenever you switch between.

- [ ] Ensure the release follows [the release constraints](https://github.com/elastisys/compliantkubernetes-kubespray/tree/main/release#constraints)
- [ ] Complete [the feature freeze step](https://github.com/elastisys/compliantkubernetes-kubespray/tree/main/release#feature-freeze)
- [ ] Complete [the staging step](https://github.com/elastisys/compliantkubernetes-kubespray/tree/main/release#staging)

### Install QA steps

> _Kubespray install scenario_

#### Environment setup

**Provider**:

- [ ] Elastx (prod)
- [ ] Safespring (prod)
- [ ] UpCloud (prod)

**Configuration**:

- [ ] Flavor - Prod
- [ ] Dex IdP - Google
- [ ] Dex Static User - Enabled and `admin@example.com` added as an application developer
    <details><summary>Commands</summary>

    ```bash
    # configure
    yq4 -i '.grafana.user.oidc.allowedDomains += ["example.com"]' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq4 -i '.grafana.ops.oidc.allowedDomains += ["example.com"]' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq4 -i 'with(.opensearch.extraRoleMappings[]; with(select(.mapping_name != "all_access"); .definition.users += ["admin@example.com"]))' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq4 -i '.user.adminUsers += ["admin@example.com"]' "${CK8S_CONFIG_PATH}/wc-config.yaml"
    yq4 -i '.dex.enableStaticLogin = true' "${CK8S_CONFIG_PATH}/sc-config.yaml"

    # apply from the apps repository
    ./bin/ck8s apply sc
    ./bin/ck8s apply wc
    ```

    </details>
- [ ] Grafana trailing dots - Disabled
    <details><summary>Commands</summary>

    ```sh
    yq4 -i '.grafana.user.trailingDots = false' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq4 -i '.grafana.ops.trailingDots = false' "${CK8S_CONFIG_PATH}/sc-config.yaml"

    # apply from the apps repository
    ./bin/ck8s ops helmfile sc -lapp=grafana diff
    ./bin/ck8s ops helmfile sc -lapp=grafana apply
    ```

    </details>
- [ ] Set the environment variable `NAMESPACE` to an application developer namespace (this cannot be a subnamespace)
- [ ] Set the environment variable `DOMAIN` to the environment domain

#### Status tests

> [!note]
> As platform administrator

- [ ] Successful `./bin/ck8s test sc|wc` from the apps repository
- [ ] If possible let the environment stabilise into a steady state after the install
    - Best is to perform the install at the end of the day to give it the night to stabilise.
    - Otherwise give it at least one to two hours to stabilise if possible.

#### Automated tests

> [!note]
> As platform administrator

- [ ] Successful `make build-main` from the `tests/` directory of the apps repository
- [ ] Successful `make run-end-to-end` from the `tests/` directory of the apps repository

#### Kubernetes access

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
        - apiGroup: rbac.authorization.k8s.io
          kind: User
          name: jane # "name" is case sensitive
    ```

- [ ] Can delegate view access

    ```console
    $ kubectl edit clusterrolebinding extra-user-view
      # Add some subject
      subjects:
        # You can specify more than one "subject"
        - apiGroup: rbac.authorization.k8s.io
          kind: User
          name: jane # "name" is case sensitive
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

#### Hierarchical Namespaces

> [!note]
> As application developer `admin@example.com`

- [ ] [Can create a subnamespace by following the application developer docs](https://elastisys.io/welkin/user-guide/namespaces/#namespace-management)
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
- [ ] Ensure the default roles, rolebindings, and NetworkPolicies propagated
    <details><summary>Commands</summary>

    ```bash
    kubectl get role,rolebinding,netpol -n "${NAMESPACE}"
    kubectl get role,rolebinding,netpol -n "${NAMESPACE}-qa-test"
    ```

    </details>

#### Harbor

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
- [ ] [Can create projects and push images by following the application developer docs](https://elastisys.io/welkin/user-guide/registry/#running-example)
- [ ] [Can configure image pull secret by following the application developer docs](https://elastisys.io/welkin/user-guide/kubernetes-api/#configure-an-image-pull-secret)
- [ ] Can scan image for vulnerabilities
- [ ] Configure project to disallow vulnerabilities
    - Try to pull image with vulnerabilities, should fail

    ```bash
    docker pull "harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo:${TAG}"
    ```

- [ ] Configure project to allow vulnerabilities
    - Try to pull image with vulnerabilities, should succeed

    ```bash
    docker pull "harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo:${TAG}"
    ```

#### Gatekeeper

> [!note]
> As application developer `admin@example.com`

- [ ] Can list OPA rules

    ```bash
    kubectl get constraints
    ```

> [!note]
> Using [the user demo helm chart](https://github.com/elastisys/welkin/tree/main/user-demo/deploy/welkin-user-demo)
>
> - Set `NAMESPACE` to an application developer namespaces
> - Set `PUBLIC_DOCS_PATH` to the path of the public docs repo

- [ ] With invalid image repository, try to deploy, should warn due to constraint

    ```bash
    helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/welkin-user-demo" \
      --set image.repository="${REGISTRY_PROJECT}/welkin-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}"
    ```

- [ ] With invalid image tag, try to deploy, should fail due to constraint

    ```bash
    helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/welkin-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo" \
      --set image.tag=latest \
      --set ingress.hostname="demoapp.${DOMAIN}"
    ```

- [ ] With unset NetworkPolicies, try to deploy, should warn due to constraint

    ```bash
    helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/welkin-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}" \
      --set networkPolicy.enabled=false
    ```

- [ ] With unset resources, try to deploy, should fail due to constraint

    ```bash
    helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/welkin-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}" \
      --set resources.requests=null
    ```

- [ ] With valid values, try to deploy, should succeed

    ```bash
    helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/welkin-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}"
    ```

#### cert-manager and Ingress-NGINX

> [!note]
> As platform administrator

- [ ] All certificates ready including user demo
- [ ] All ingresses ready including user demo
    - [ ] Endpoints are reachable
    - [ ] Status includes correct IP addresses

#### Metrics

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
    <details><summary>Steps</summary>

    - Go to explore page in Grafana
    - Enter `rate(http_request_duration_seconds_count{container="welkin-user-demo"}[1m])` as the query
    - Metrics should show up

    </details>
- [ ] [CISO dashboards available and working](https://elastisys.io/welkin/ciso-guide/)
    <details><summary>List</summary>

    - [Backup / Backup Status](https://elastisys.io/welkin/ciso-guide/backup/)
    - [Cryptography / NGINX Ingress Controller](https://elastisys.io/welkin/ciso-guide/cryptography/)
    - [Intrusion Detection / Falco](https://elastisys.io/welkin/ciso-guide/intrusion-detection/)
    - [Policy-as-Code / Gatekeeper](https://elastisys.io/welkin/ciso-guide/policy-as-code/)
    - [Network Security / NetworkPolicy](https://elastisys.io/welkin/ciso-guide/network-security/)
    - [Capacity Management / Kubernetes Cluster Status](https://elastisys.io/welkin/ciso-guide/capacity-management/)
    - [Vulnerability / Trivy Operator Dashboard](https://elastisys.io/welkin/ciso-guide/vulnerability/)

    </details>

#### Alerts

> [!note]
> As platform administrator

- [ ] No alert open except `Watchdog`, `CPUThrottlingHigh` and `FalcoAlert`
    - Can be seen in the alert section in platform administrator Grafana

> [!note]
> As application developer `admin@example.com`

- [ ] [Access Prometheus following the application developer docs](https://elastisys.io/welkin/user-guide/metrics/#accessing-the-prometheus-ui)
- [ ] Prometheus picked up user demo ServiceMonitor and PrometheusRule
- [ ] [Access Alertmanager following the application developer docs](https://elastisys.io/welkin/user-guide/alerts/#accessing-user-alertmanager)
- [ ] Alertmanager `Watchdog` firing

#### Logs

> [!note]
> As platform administrator

- [ ] Can login to OpenSearch Dashboards via Dex with IdP
- [ ] Indices created (Authlog, Kubeaudit, Kubernetes, Other)
- [ ] Indices managed (Authlog, Kubeaudit, Kubernetes, Other)
- [ ] Logs available (Authlog, Kubeaudit, Kubernetes, Other)
- [ ] Snapshots configured
- [ ] Check the logs in OpenSearch and review any errors and warnings
    <!-- TODO: Create an OpenSearch dashboard to assist in checking logs for QA --->
    If there are clear issues then this should be fixed.
    If there are no clear issues, or if fixing the issues would require substantial work, then talk with the QAE, or TLs if they are unavailable, about either accepting or taking additional actions.

> [!note]
> As application developer `admin@example.com`

- [ ] Can login to OpenSearch Dashboards via Dex with static user
- [ ] Welcome dashboard presented first
- [ ] Logs available (Kubeaudit, Kubernetes)
- [ ] [CISO dashboards available and working](https://elastisys.io/welkin/ciso-guide/audit-logs/)

#### Falco

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

#### Network Policies

- [ ] No dropped packets in NetworkPolicy Grafana dashboard

#### Infrastructure

- [ ] Able to run `terraform plan` without changes, issues, and warnings
- [ ] Able to add nodes without issues
- [ ] Able to remove nodes without issues

### Upgrade QA steps

> _Kubespray upgrade scenario_

#### Environment setup

**Provider**:

- [ ] Elastx (prod)
- [ ] Safespring (prod)
- [ ] UpCloud (prod)

**Configuration**:

- [ ] Flavor - Prod
- [ ] Dex IdP - Google
- [ ] Dex Static User - Enabled and `admin@example.com` added as an application developer
    <details><summary>Commands</summary>

    ```bash
    # configure
    yq4 -i '.grafana.user.oidc.allowedDomains += ["example.com"]' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq4 -i '.grafana.ops.oidc.allowedDomains += ["example.com"]' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq4 -i 'with(.opensearch.extraRoleMappings[]; with(select(.mapping_name != "all_access"); .definition.users += ["admin@example.com"]))' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq4 -i '.user.adminUsers += ["admin@example.com"]' "${CK8S_CONFIG_PATH}/wc-config.yaml"
    yq4 -i '.dex.enableStaticLogin = true' "${CK8S_CONFIG_PATH}/sc-config.yaml"

    # apply from the apps repository
    ./bin/ck8s apply sc
    ./bin/ck8s apply wc
    ```

    </details>
- [ ] Grafana trailing dots - Disabled
    <details><summary>Commands</summary>

    ```sh
    yq4 -i '.grafana.user.trailingDots = false' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq4 -i '.grafana.ops.trailingDots = false' "${CK8S_CONFIG_PATH}/sc-config.yaml"

    # apply from the apps repository
    ./bin/ck8s ops helmfile sc -lapp=grafana diff
    ./bin/ck8s ops helmfile sc -lapp=grafana apply
    ```

    </details>
- [ ] Set the environment variable `NAMESPACE` to an application developer namespace (this cannot be a subnamespace)
- [ ] Set the environment variable `DOMAIN` to the environment domain

#### Upgrade

- [ ] Can upgrade according to [the migration docs for this version](https://github.com/elastisys/compliantkubernetes-kubespray/tree/main/migration)

#### Status tests

> [!note]
> As platform administrator

- [ ] Successful `./bin/ck8s test sc|wc` from the apps repository
- [ ] If possible let the environment stabilise into a steady state after the upgrade
    - Best is to perform the upgrade at the end of the day to give it the night to stabilise.
    - Otherwise give it at least one to two hours to stabilise if possible.

#### Automated tests

> [!note]
> As platform administrator

- [ ] Successful `make build-main` from the `tests/` directory of the apps repository
- [ ] Successful `make run-end-to-end` from the `tests/` directory of the apps repository

#### Kubernetes access

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
        - apiGroup: rbac.authorization.k8s.io
          kind: User
          name: jane # "name" is case sensitive
    ```

- [ ] Can delegate view access

    ```console
    $ kubectl edit clusterrolebinding extra-user-view
      # Add some subject
      subjects:
        # You can specify more than one "subject"
        - apiGroup: rbac.authorization.k8s.io
          kind: User
          name: jane # "name" is case sensitive
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

#### Hierarchical Namespaces

> [!note]
> As application developer `admin@example.com`

- [ ] [Can create a subnamespace by following the application developer docs](https://elastisys.io/welkin/user-guide/namespaces/#namespace-management)
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
- [ ] Ensure the default roles, rolebindings, and NetworkPolicies propagated
    <details><summary>Commands</summary>

    ```bash
    kubectl get role,rolebinding,netpol -n "${NAMESPACE}"
    kubectl get role,rolebinding,netpol -n "${NAMESPACE}-qa-test"
    ```

    </details>

#### Harbor

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
- [ ] [Can create projects and push images by following the application developer docs](https://elastisys.io/welkin/user-guide/registry/#running-example)
- [ ] [Can configure image pull secret by following the application developer docs](https://elastisys.io/welkin/user-guide/kubernetes-api/#configure-an-image-pull-secret)
- [ ] Can scan image for vulnerabilities
- [ ] Configure project to disallow vulnerabilities
    - Try to pull image with vulnerabilities, should fail

    ```bash
    docker pull "harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo:${TAG}"
    ```

- [ ] Configure project to allow vulnerabilities
    - Try to pull image with vulnerabilities, should succeed

    ```bash
    docker pull "harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo:${TAG}"
    ```

#### Gatekeeper

> [!note]
> As application developer `admin@example.com`

- [ ] Can list OPA rules

    ```bash
    kubectl get constraints
    ```

> [!note]
> Using [the user demo helm chart](https://github.com/elastisys/welkin/tree/main/user-demo/deploy/welkin-user-demo)
>
> - Set `NAMESPACE` to an application developer namespaces
> - Set `PUBLIC_DOCS_PATH` to the path of the public docs repo

- [ ] With invalid image repository, try to deploy, should warn due to constraint

    ```bash
    helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/welkin-user-demo" \
      --set image.repository="${REGISTRY_PROJECT}/welkin-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}"
    ```

- [ ] With invalid image tag, try to deploy, should fail due to constraint

    ```bash
    helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/welkin-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo" \
      --set image.tag=latest \
      --set ingress.hostname="demoapp.${DOMAIN}"
    ```

- [ ] With unset NetworkPolicies, try to deploy, should warn due to constraint

    ```bash
    helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/welkin-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}" \
      --set networkPolicy.enabled=false
    ```

- [ ] With unset resources, try to deploy, should fail due to constraint

    ```bash
    helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/welkin-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}" \
      --set resources.requests=null
    ```

- [ ] With valid values, try to deploy, should succeed

    ```bash
    helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/welkin-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}"
    ```

#### cert-manager and Ingress-NGINX

> [!note]
> As platform administrator

- [ ] All certificates ready including user demo
- [ ] All ingresses ready including user demo
    - [ ] Endpoints are reachable
    - [ ] Status includes correct IP addresses

#### Metrics

> [!note]
> As platform administrator

- [ ] Can login to platform administrator Grafana via Dex with IdP
- [ ] Dashboards are available and viewable
- [ ] Metrics are available from all clusters
- [ ] Check the volume of metrics scraped by Prometheus and ingested by Thanos and compare it to before the upgrade
    <!-- TODO: Create a Grafana dashboard to assist in measuring metrics for QA --->
    If there is a large change compared to before the upgrade that cannot be supported by the changes done in the release then this should be investigated as this may point towards:

    - Errors caused by incompatible or misbehaving components or configurations
    - Unintentional addition or removal of components

    If there are clear issues then this should be fixed.
    If there are no clear issues, or if fixing the issues would require substantial work, then talk with the QAE, or TLs if they are unavailable, about either accepting or taking additional actions.

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
    <details><summary>Steps</summary>

    - Go to explore page in Grafana
    - Enter `rate(http_request_duration_seconds_count{container="welkin-user-demo"}[1m])` as the query
    - Metrics should show up

    </details>
- [ ] [CISO dashboards available and working](https://elastisys.io/welkin/ciso-guide/)
    <details><summary>List</summary>

    - [Backup / Backup Status](https://elastisys.io/welkin/ciso-guide/backup/)
    - [Cryptography / NGINX Ingress Controller](https://elastisys.io/welkin/ciso-guide/cryptography/)
    - [Intrusion Detection / Falco](https://elastisys.io/welkin/ciso-guide/intrusion-detection/)
    - [Policy-as-Code / Gatekeeper](https://elastisys.io/welkin/ciso-guide/policy-as-code/)
    - [Network Security / NetworkPolicy](https://elastisys.io/welkin/ciso-guide/network-security/)
    - [Capacity Management / Kubernetes Cluster Status](https://elastisys.io/welkin/ciso-guide/capacity-management/)
    - [Vulnerability / Trivy Operator Dashboard](https://elastisys.io/welkin/ciso-guide/vulnerability/)

    </details>

#### Alerts

> [!note]
> As platform administrator

- [ ] No alert open except `Watchdog`, `CPUThrottlingHigh` and `FalcoAlert`
    - Can be seen in the alert section in platform administrator Grafana

> [!note]
> As application developer `admin@example.com`

- [ ] [Access Prometheus following the application developer docs](https://elastisys.io/welkin/user-guide/metrics/#accessing-the-prometheus-ui)
- [ ] Prometheus picked up user demo ServiceMonitor and PrometheusRule
- [ ] [Access Alertmanager following the application developer docs](https://elastisys.io/welkin/user-guide/alerts/#accessing-user-alertmanager)
- [ ] Alertmanager `Watchdog` firing

#### Logs

> [!note]
> As platform administrator

- [ ] Can login to OpenSearch Dashboards via Dex with IdP
- [ ] Indices created (Authlog, Kubeaudit, Kubernetes, Other)
- [ ] Indices managed (Authlog, Kubeaudit, Kubernetes, Other)
- [ ] Logs available (Authlog, Kubeaudit, Kubernetes, Other)
- [ ] Snapshots configured
- [ ] Check the volume of logs collected by Fluentd and ingested by OpenSearch and compare it to before the upgrade
    <!-- TODO: Create an OpenSearch dashboard to assist in measuring logs for QA --->
    If there is a large change compared to before the upgrade that cannot be supported by the changes done in the release then this should be investigated as this may point towards:

    - Errors caused by incompatible or misbehaving components or configurations
    - Unintentional addition or removal of components

    If there are clear issues then this should be fixed.
    If there are no clear issues, or if fixing the issues would require substantial work, then talk with the QAE, or TLs if they are unavailable, about either accepting or taking additional actions.
- [ ] Check the logs in OpenSearch and review any errors and warnings
    <!-- TODO: Create an OpenSearch dashboard to assist in checking logs for QA --->
    If there are clear issues then this should be fixed.
    If there are no clear issues, or if fixing the issues would require substantial work, then talk with the QAE, or TLs if they are unavailable, about either accepting or taking additional actions.

> [!note]
> As application developer `admin@example.com`

- [ ] Can login to OpenSearch Dashboards via Dex with static user
- [ ] Welcome dashboard presented first
- [ ] Logs available (Kubeaudit, Kubernetes)
- [ ] [CISO dashboards available and working](https://elastisys.io/welkin/ciso-guide/audit-logs/)

#### Falco

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

#### Network Policies

- [ ] No dropped packets in NetworkPolicy Grafana dashboard

#### Infrastructure

- [ ] Able to run `terraform plan` without changes, issues, and warnings
- [ ] Able to add nodes without issues
- [ ] Able to remove nodes without issues

### After QA steps

- [ ] Complete [the code freeze step](https://github.com/elastisys/compliantkubernetes-kubespray/tree/main/release#code-freeze)
- [ ] The staging pull request must be approved

### Release steps

- [ ] Complete [the release step](https://github.com/elastisys/compliantkubernetes-kubespray/tree/main/release#release)
- [ ] Complete [the update public release notes step](https://github.com/elastisys/compliantkubernetes-kubespray/tree/main/release#update-public-release-notes)
- [ ] Complete [the update main branch step](https://github.com/elastisys/compliantkubernetes-kubespray/tree/main/release#update-the-main-branch)

### Final steps

- [ ] Ensure the minor version of [the kubectl requirement in Apps](https://github.com/elastisys/compliantkubernetes-apps/blob/main/REQUIREMENTS) is equal or greater than the Kubernetes version of
Kubespray.
