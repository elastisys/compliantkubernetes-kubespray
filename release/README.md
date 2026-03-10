# Release process

The releases will follow the version of the Kubespray submodule, with the version string `<kubespray-submodule-version>-<ck8s-patch>`.

- `<kubespray-submodule-version>` - denotes the current version of the Kubespray submodule, following `X.Y.Z`
- `<ck8s-patch>` - denotes the current patch of our additions and modifications, following `ck8sP`
    - The `<ck8s-patch>` will always start at `ck8s1` for each new Kubespray submodule release and then increment the number for each patch release on top of that Kubespray submodule release.

## Prerequisites

These steps must be completed before a major or minor release can be started.
Any required change must be merged to the `main` branch before the release is staged.

- Ensure the ServiceMonitor CRD is synced with Apps:

    ```sh
    # Ensure you have CK8S_GITHUB_TOKEN set with access to the Apps repository.
    export CK8S_GITHUB_TOKEN="$(pass github.com/personal-access-token)"
    ./playbooks/crds/sync.sh
    ```

## Feature freeze

> [!important]
> _Be sure to complete the prerequisites above before the feature freeze._

> [!warning]
> This step is only done for major or minor releases.
> For patch releases switch to the existing release branch.

Create a release branch `release-X.Y.Z` from the main branch:

```sh
git switch main
git switch -c release-X.Y.Z
git push -u origin release-X.Y.Z
```

## Staging

Set up a GitHub token that has access to read the repositories of the organisation including commits, issues, and pull requests.

```sh
export CK8S_GITHUB_TOKEN="$(pass github.com/personal-access-token)"
```

For patch releases, configure the list of commits that you want to backport:

```sh
export CK8S_GIT_CHERRY_PICK="COMMIT-SHA [COMMIT-SHA ...]"
```

Stage the release:

```sh
release/stage-release.sh X.Y.Z-ck8sP
```

Running the script above will:

- Create a staging branch from the release branch.
- Cherry pick commits in `${CK8S_GIT_CHERRY_PICK}`, if there are any.
- Generate and commit the changelog.

Generate a CycloneDX SBOM for the staged release:

```sh
./sbom/generate.sh X.Y.Z --require-evaluation
```

Running the script above will:

- Generate a new SBOM for the current version
- Validate that all required entries has evaluations.

If evaluations are missing add proper evaluations to the `sbom/overrides.yaml` then rerun the script.
Once generated and validated commit and push the new SBOM:

```sh
git add sbom/sbom.cdx.json
git commit -m "docs: Update SBOM for vX.Y.Z"
git push
```

> For more information see the [SBOM generation documentation](../sbom/README.md).

Push the staging branch and open a draft pull request to the release branch:

```sh
git push -u origin staging-X.Y.Z-ck8sP
```

If there is no migration document, create one as described [here](../migration/README.md).
If a migration document already exists, make sure that it follows [this template](../migration/template/README.md) and matches the staged version.

Perform QA on the staging branch.
If any fixes are necessary, add a manual changelog entry and push them to the staging branch.

## Code freeze

When the QA process is finished the code should be in a state where it's ready to be released.

Mark the staging pull request ready for review.

## Release

When the staging branch has been merged to the release branch, the release [GitHub workflow](/.github/workflows/release.yml) will automatically create a new GitHub release.

## Update public release notes

When a release is published [the public application developer facing release notes](https://github.com/elastisys/welkin-public-docs/blob/main/docs/release-notes/kubespray.md) needs to be updated.
The new release needs to be added and the list can be trimmed down to only include the supported versions.

```sh
# Reuse the GitHub token from earlier.
export CK8S_GITHUB_TOKEN="$(pass github.com/personal-access-token)"
release/generate-release-notes.sh X.Y.Z-ck8sP
```

The public release notes are aimed towards application developers.
Remove irrelevant entries and/or reword entries so that they are easy to understand for the application developers.

## Update the main branch

Port the changelog and all applicable fixes done in the QA process to the main branch:

```sh
git switch main
git pull
git switch -c port-X.Y.Z-ck8sP
git cherry-pick [changelog commit SHA]
git cherry-pick [fix 1 commit SHA]
git cherry-pick [fix 2 commit SHA]
git cherry-pick [fix N commit SHA]
git push -u origin port-X.Y.Z-ck8sP
```

Open a pull request to the main branch.
