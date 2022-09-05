# Release process

The releases will have the following version string: `<kubespray-version>-<ck8s-patch>`.

- `<kubespray-version>` is the current version of the kubespray git submodule, e.g. 2.16.0.
- `<ck8s-patch>` denotes the current version of our wrapper scripts and config with the format `ck8s<number>`, e.g. ck8s1.
  The `<ck8s-patch>` will always restart at ck8s1 for each new kubespray version, then the number after ck8s will be incremented in case we release a patch.

## New kubespray releases

1. To release a version with an updated kubespray version create a release branch `release-<kubespray-version>` from the main branch.

    ```bash
    git switch main
    git switch -c release-<kubespray-version>
    git push -u origin release-<kubespray-version>
    ```

1. Reset changelog

    ```bash
    git switch -c reset-changelog-<kubespray-version>
    release/reset-changelog.sh <kubespray-version>-<ck8s-patch>
    ```

    The release script will:
    - Append what is in `WIP-CHANGELOG.md` to `CHANGELOG.md`
    - Clear `WIP-CHANGELOG.md`
    - Create a git commit with message `Reset changelog for release <kubespray-version>-<ck8s-patch>`

    Make sure that the changes only include changes mentioned above, and then push.

    ```bash
    git diff HEAD~1
    git push -u origin reset-changelog-<kubespray-version>
    ```

1. Merge `reset-changelog-<kubespray-version>` into `release-<kubespray-version>` then, into `main` as soon as possible to minimize risk of conflicts

    **NOTE**: The release action will fail since we haven't tagged the release commit.
    We will do that after QA.

1. Create a `QA-<kubespray-version>` branch and run QA checks on this branch.

    ```bash
    git switch release-<kubespray-version>
    git switch -c QA-<kubespray-version>
    git push -u origin QA-<kubespray-version>
    ```

    **NOTE**: All changes made in QA should be added to `CHANGELOG.md` and **NOT** `WIP-CHANGELOG.md`.
    Also, make sure to not merge any fixes into `release-<kubespray-version>` on this step.

1. When the QA is finished, create the release tag.

    ```bash
    git tag v<kubespray-version>-<ck8s-patch>
    ```

1. Push the tagged commit, create a PR against the release branch and request a review.
   If there are no changes, create the release manually instead by going to [releases](https://github.com/elastisys/compliantkubernetes-kubespray/releases) and clicking "Draft a new release".
   Check older releases for how to word it.

    ```bash
    git push --tags
    ```

1. Merge it to finalize the release.

    Since the tag is referencing a specific commit hash we need to retain it after the PR (via e.g. fast-forward merge).

    *GitHub currently does not support merging with fast-forward only in PRs.
    Merge the release PR locally and push it instead.*

    ```bash
    git switch release-<kubespray-version>
    git merge --ff-only QA-<kubespray-version>
    git push
    ```

    A [GitHub actions workflow pipeline](/.github/workflows/release.yml) will create a GitHub release from the tag.

1. Merge any fixes from the release branch back to the `main` branch `git cherry-pick` can be used, e.g.

    ```bash
    git switch main
    git switch -c release-<kubespray-version>-fixes
    git cherry-pick <fix 1 hash> [<fix 2 hash>..]
    git push -u origin release-<kubespray-version>-fixes
    ```

    Create a PR and merge the fixes into main.

1. Update public release notes.

    When a released is published the public [user-facing release notes](https://github.com/elastisys/compliantkubernetes/blob/main/docs/compliantkubernetes/release-notes/kubespray.md) needs to be updated. The new release needs to be added and the list can be trimmed down to only include the supported versions.

    Add bullet points of major changes within the cluster that affects the user as defined [here](https://compliantkubernetes.io/user-guide/). This includes any change within the cluster that may impact the user experience, for example new or updated feature, or the deprecation of features.

    Finish it of with one bullet point regarding the overall changes of the release in regards to updates, fixes, or other improvements.

## Patch releases

1. Create a new branch `patch-<kubespray-version>-<patch-name>` from the release branch to patch and commit the patch to it.

    ```bash
    git switch release-<kubespray-version>
    git pull
    git switch -c patch-<kubespray-version>-<patch-name>
    git cherry-pick [fixed commits from main]
    git add -p [fixed files]
    git commit
    git push -u origin patch-<kubespray-version>-<patch-name>
    ```

1. Reset changelog, increment `<ck8s-patch>` from the previous version.

    ```bash
    release/reset-changelog.sh <kubespray-version>-<ck8s-patch>
    ```

    Make sure that `CHANGELOG.md` is updated correctly.

1. Run QA checks on this branch related to the introduced changes.

    **NOTE**: All changes made in QA should be added to `CHANGELOG.md` and **NOT** `WIP-CHANGELOG.md`.
    Also, make sure to not merge any fixes into `release-<kubespray-version>` on this step.

1. When the QA is finished, create the release tag and push it.

    ```bash
    git tag v<kubespray-version>-<ck8s-patch>
    git push --tags
    ```

1. Create a PR against the release branch and request review.

1. Fast-forward merge the PR to finalize the release.

    This is to keep the commit hash and tag with it after the merge.

    *Since GitHub currently does not support fast-forward merge of PRs this has to be done manually.*

    ```bash
    git switch release-<kubespray-version>
    git merge --ff-only patch-<kubespray-version>-<patch-name>
    git push
    ```

    A [GitHub actions workflow pipeline](/.github/workflows/release.yml) will create a GitHub release from the tag.

    The release action will fail if the patch branch is merged in a way that does not preserve the commit hash and tag.
    To fix this remove the previously created tag, recreate it on the release branch, and rerun the release action workflow.

1. Follow the regular release from step 8 to merge eventual fixes into main and to update the public release notes.

## While developing

When a feature or change is developed on a branch fill out some human readable
bullet points in the `WIP-CHANGELOG.md` this will make it easier to track the changes.
Once the release is done this will be appended to the main changelog.

## Structure

The structure follow the guidelines of [keepachangelog](https://keepachangelog.com/en/1.0.0/).

Changelogs are for humans, not machines. Keep messages in human readable form rather
than commits or code. Commits or pull requests can off course be linked. Add messages
as bullet points under one of theese categories:

- Breaking changes
- Release notes
- Added
- Changed
- Deprecated
- Removed
- Fixed
- Security

When creating a major release a section of `Release highlights` should be added
on top of the WIP-changelog with a summary of the most important changes.

You can link comments to related pull requests with `PR#pr-number`. Commit ids can be linked
by just writing that commits short hash or full hash.

## Example changelog

```markdown
## v2.16.0-ck8s1 - 2020-01-14  (OBS! this line is automatically added by script)

### Breaking changes

* The API endpoint xxxx has been removed.

### Release notes

* To migrate the resources depending on yyyy you have to run this script.

### Added

* Option to add prometheus scrape endpoints
* Retetion for elasticsearch

### Changed

* Updated grafana version to 6.7.0
* Changed manifests for deploying ck8sdash into a helm chart PR#120

### Deprecated

* Option to disable OPA with `ENABLE_OPA` variable. Now always true

### Removed

* Curator has been removed. Now retention is configured with ILM.

### Fixed

* bugfix deploying elasticsearch operator 2310e74
```
