<!-- Choose your PR title carefully as it will be used as the entry in the changelog! -->

<!-- markdownlint-disable MD041 -->
> [!warning]
> **This is a public repository, ensure not to disclose:**
>
> - [ ] personal data beyond what is necessary for interacting with this pull request, nor
> - [ ] business confidential information, such as customer names.

### What kind of PR is this?

**Required**: Mark one of the following that is applicable:

- [ ] kind/feature       <!-- This PR adds a new feature -->
- [ ] kind/improvement   <!-- This PR changes an existing feature -->
- [ ] kind/deprecation   <!-- This PR removes an existing feature -->
- [ ] kind/documentation <!-- This PR contains documentation -->
- [ ] kind/clean-up      <!-- This PR cleans up technical debt -->
- [ ] kind/bug           <!-- This PR fixes a bug -->
- [ ] kind/other         <!-- This PR does something else -->

_Optional_: Mark one or more of the following that are applicable:

> [!important]
> Breaking changes should be marked `kind/admin-change` or `kind/dev-change` depending on type
> Critical security fixes should be marked with `kind/security`

- [ ] kind/admin-change   <!-- This PR introduces an admin facing change, add "Platform Administrator notice" section -->
- [ ] kind/dev-change     <!-- This PR introduces a dev facing change, add "Application Developer notice" section -->
- [ ] kind/security       <!-- This PR introduces a critical security fix, add "Security notice" section -->
- [ ] [kind/adr](set-me\) <!-- This PR implements an ADR, add the link -->

<!-- Uncomment the additional sections that applies. -->

<!-- Additional information to be added in the release notes
### Release notes
...
-->

<!-- Additional information with kind/admin-change
### Platform Administrator notice
...
-->

<!-- Add additional information with kind/dev-change
### Application Developer notice
...
-->

<!-- Add additional information with kind/security
### Security notice
...
-->

### What does this PR do / why do we need this PR?

<!-- Add description of the change -->
...

<!-- Add all issues that are fixed by this PR, use "Part of" instead of "Fixes" if you want to keep issues open. -->
- Fixes #

#### Information to reviewers

<!--
Any additional information reviews should know.

How to run / how to test.

Include screenshots if applicable to help explain these changes.
--->

#### Checklist

<!-- This section is not added to the changelog or release notes, it is to help you as a contributor and reviewers. -->

- [ ] Proper commit message prefix on all commits
    <!-- Example of commit message prefixes:
    - all: changes to multiple areas
    - bin: changes to management binaries
    - config: changes to configuration
    - deploy: changes to deployments
    - docs: changes to documentation
    - release: release related
    - scripts: changes to scripts
    - tests: changes to tests
    --->
- Change checks:
    - [ ] The change is transparent
    - [ ] The change is disruptive
    - [ ] The change requires no migration steps
    - [ ] The change requires migration steps
- Documentation checks:
    - [ ] The [public documentation](https://github.com/elastisys/welkin) required no updates
    - [ ] The [public documentation](https://github.com/elastisys/welkin) required an update - [link to change](set-me\)
- Metrics checks:
    - [ ] The metrics are still exposed and present in Grafana after the change
    - [ ] The metrics names didn't change (Grafana dashboards and Prometheus alerts required no updates)
    - [ ] The metrics names did change (Grafana dashboards and Prometheus alerts required an update)
- Logs checks:
    - [ ] The logs do not show any errors after the change
- PodSecurityPolicy checks:
    - [ ] Any changed Pod is covered by Kubernetes Pod Security Standards
    - [ ] Any changed Pod is covered by Gatekeeper Pod Security Policies
    - [ ] The change does not cause any Pods to be blocked by Pod Security Standards or Policies
- NetworkPolicy checks:
    - [ ] Any changed Pod is covered by Network Policies
    - [ ] The change does not cause any dropped packets in the NetworkPolicy Dashboard
- Audit checks:
    - [ ] The change does not cause any unnecessary Kubernetes audit events
    - [ ] The change requires changes to Kubernetes audit policy
- Falco checks:
    - [ ] The change does not cause any alerts to be generated by Falco
- Bug checks:
    - [ ] The bug fix is covered by regression tests
