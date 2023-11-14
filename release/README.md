# Release process

The releases will have the following version string: `<kubespray-version>-<ck8s-patch>`.

- `<kubespray-version>` is the current version of the kubespray git submodule, e.g. 2.16.0.
- `<ck8s-patch>` denotes the current version of our wrapper scripts and config with the format `ck8s<number>`, e.g. ck8s1.
  The `<ck8s-patch>` will always restart at `ck8s1` for each new Kubespray release, then the number after `ck8s` will be incremented in case we release a patch.

## Feature freeze

Create a release branch `release-<kubespray-version>` from the main branch.

```bash
git switch main
git switch -c release-<kubespray-version>
git push -u origin release-<kubespray-version>
```

## Staging

For patch releases, configure the list of commits that you want to backport.

```bash
export CK8S_GIT_CHERRY_PICK="COMMIT-SHA [COMMIT-SHA ...]"
```

Stage the release.

```bash
release/stage-release.sh <kubespray-version>-<ck8s-patch>
```

Running the script above will:

- Create a staging branch from the release branch.
- Cherry pick commits in `$CK8S_GIT_CHERRY_PICK`, if there are any.
- Generate and commit the changelog.

Push the staging branch and open a draft pull request to the release branch.

```bash
git push -u origin staging-<kubespray-version>-<ck8s-patch>
```

If there is no migration document, create one as described [here](../migration/README.md).
If a migration document already exists, make sure that it follows [this template](../migration/template/upgrade-cluster.md).

Perform QA on the staging branch.
If any fixes are necessary, add a manual changelog entry and push them to the staging branch.

## Code freeze

When the QA process is finished the code should be in a state where it's ready to be released.

Mark the staging pull request ready for review.

## Release

When the staging branch has been merged, finalize the release by tagging the HEAD of the release branch and push the tag.

```bash
git switch release-<kubespray-version>
git pull
git tag v<kubespray-version>-<ck8s-patch>
git push --tags
```

A [GitHub actions workflow pipeline](/.github/workflows/release.yml) will create a GitHub release from the tag.

## Update public release notes

When a release is published the public [user-facing release notes](https://github.com/elastisys/compliantkubernetes/blob/main/docs/release-notes/kubespray.md) needs to be updated.
The new release needs to be added and the list can be trimmed down to only include the supported versions.

```bash
release/generate-release-notes.sh <kubespray-version>-<ck8s-patch>
```

The public release notes are aimed towards application developers.
Remove irrelevant entries and/or reword entries so that they are easy to understand for the application developers.

## Update the main branch

Port the changelog and all applicable fixes done in the QA process to the main branch.

```bash
git switch main
git pull
git switch -c port-<kubespray-version>-<ck8s-patch>
git cherry-pick [changelog commit SHA]
git cherry-pick [fix1 commit SHA]
git cherry-pick [fix2 commit SHA]
git cherry-pick [fixN commit SHA]
git push -u origin port-<kubespray-version>-<ck8s-patch>
```

Open a pull request to the main branch.
