# Managing kubespray fork

This document details the process to upgrade and/or make changes to the `kubespray` fork.

## The fork is a git submodule

`compliantkubernetes-kubespray` depends on [our kubespray fork](https://github.com/elastisys/kubespray) of [Kubernetes SIG kubespray](https://github.com/kubernetes-sigs/kubespray).

The `kubespray` fork is included in the `compliantkubernetes-kubespray` repo as a Git submodule, which means the only thing stored in `compliantkubernetes-kubespray` is metadata (path, url) in `.gitmodules` and a git tree object with a commit SHA-1 of where the submodule (our kubespray fork) is tracked.

Inspect the SHA-1 of the commit the superproject expects the fork working directory to be at:

```sh
$ git ls-tree <branch> kubespray
```

Inspect the SHA-1 of the currently checked out commit in the fork, along
with the submodule path and the output of git describe for the SHA-1:

```sh
$ git submodule status
```

Make the local fork match what the remote `compliantkubernetes-kubespray` expects the directory to look like:

```sh
$ git submodule update --init
```

## Modifications of the fork

### Step 1

Make sure submodule fork and its remotes are set up correctly:

```sh
$ cd kubespray

$ git remote -v # Make sure these lines match
  origin    ssh://git@github.com/elastisys/kubespray (fetch)
  origin    ssh://git@github.com/elastisys/kubespray (push)
  upstream  ssh://git@github.com/kubernetes-sigs/kubespray.git (fetch)
  upstream  ssh://git@github.com/kubernetes-sigs/kubespray.git (push)

# If not:
$ git remote add upstream ssh://git@github.com/kubernetes-sigs/kubespray.git
```

### Step 2

Make sure the master branch is up to date with upstream:

```bash
$ git fetch --all

$ git switch master

$ git status # Ensure these lines match
On branch master
Your branch is up to date with 'origin/master'.

$ git branch master -u origin/master # Else if your local master branch tracks another remote branch, rerun git status.
$ git reset --hard origin/master # Else if your local master branch has diverged from origin/master.
$ git rebase -i <upstream-kubespray-version>
# Keep relevant commits we've previously included and resolve all merge conflicts.
$ git log
# Ensure the commit history has not diverged from upstream/master.
# The first commit after ours should be marked "upstream/master".
$ git status # Ensure these lines match
  On branch master
  Your branch and 'origin/master' have diverged,
  and have N and M different commits each, respectively.
$ git push --force-with-lease
```

### Step 3

Create a new feature branch and start developing:

```bash
git switch -c <development-branch>
```

Create a pull request to `master` within our fork, get it reviewed, and then merged.

### Step 4

Create or re-use a release branch for the fork based on an upstream release.

The releases will follow the version of the upstream Kubespray version, with the version string `<kubespray-version>-<ck8s-patch>`.

- `<kubespray-version>` - denotes the current version of the upstream Kubespray version, following `X.Y.Z`
- `<ck8s-patch>` - denotes the current patch of our additions and modifications to the fork, following `ck8sP`
  - The `<ck8s-patch>` will always start at `ck8s1` for each new Kubespray fork release and then increment the number for each patch release on top of that Kubespray fork release.

```sh
$ git fetch --all

# if a release/patch matching the current version of compliantkubernetes-kubespray exists and you only want to add a fix to the fork:
$ git switch "release-X.Y.Z-ck8sP"

# if no release brach exists in the fork:
$ git switch X.Y.Z # upstream release
$ git switch -c "release-X.Y.Z-ck8s1"

# For patch releases, only increment ck8s-patch version:
$ git switch "release-X.Y.Z-ck8sP"
$ git switch -c "release-X.Y.Z-ck8sP+1"

$ git push -u origin "release-X.Y.Z-ck8sP"
```

### Step 5

Add fixes to the release/patch branch

```bash
export CK8S_GIT_CHERRY_PICK="COMMIT-SHA [COMMIT-SHA ...]"

for sha in ${CK8S_GIT_CHERRY_PICK:-}; do
    git cherry-pick "${sha}"
done

git push
```

### Step 6

Update the submodule reference in `compliantkubernetes-kubespray`

```bash
cd compliantkubernetes-kubespray
git switch main
git pull
git submodule update --init
git switch -c <development-branch>

cd kubespray
git switch "release-X.Y.Z-ck8sP"
cd ..
git add kubespray
git commit -m "Upgrade kubespray ..."
git push
# open pull request towards main
```

### Step 7

Tag or retag the latest commit in the fork release branch to be used by `compliantkubernetes-kubespray`

```bash
cd compliantkubernetes-kubespray
git switch "release-X.Y.Z-ck8sP"
git pull
git tag -d "vX.Y.Z-ck8sP" # delete if already exists
git tag -a "vX.Y.Z-ck8sP"
git push --tags
```
