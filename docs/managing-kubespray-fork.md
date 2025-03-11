# Managing kubespray fork

This document details the process to upgrade and/or make changes to the kubespray fork.

TL;DR:

We only create one release branch `release-X.Y.Z-ck8s` in our fork per upstream release `X.Y.Z`.
We then tag the latest commit of that release branch with `vX.Y.Z-ck8s<patch-number>`.

## The fork is a git submodule

`kubespray` is included in the `compliantkubernetes-kubespray` repo as a Git submodule, which means the only thing stored in `compliantkubernetes-kubespray` is metadata (path, url) in `.gitmodules` and a git tree object with a commit SHA-1 of where the submodule (our fork) is tracked.

### Make sure the submodule is initialized and up to date

Inspect the SHA-1 of the commit the superproject expects the fork working directory to be at:

```sh
git ls-tree <branch> kubespray
```

Inspect the SHA-1 of the currently checked out commit in the fork, along
with the submodule path and the output of git describe for the SHA-1:

```sh
git submodule status
```

Make the local fork match what the remote superproject expects the directory to look like:

```sh
git submodule update --init
```

## Modifications of the fork

### Step 1

Make sure the fork and its remotes are set up correctly:

```console
$ cd kubespray

$ git remote -v # make sure lines match
  origin    ssh://git@github.com/elastisys/kubespray (fetch)
  origin    ssh://git@github.com/elastisys/kubespray (push)
  upstream  ssh://git@github.com/kubernetes-sigs/kubespray.git (fetch)
  upstream  ssh://git@github.com/kubernetes-sigs/kubespray.git (push)

# If not:
$ git remote add upstream ssh://git@github.com/kubernetes-sigs/kubespray.git
```

### Step 2

Make sure the master branch is up to date with the latest upstream release version:

```console
$ cd kubespray
$ git fetch --all
$ git switch master

$ git status # Ensure these lines match. If they do skip to step 3.
On branch master
Your branch is up to date with 'origin/master'.

$ git branch master -u origin/master # Else if your local master branch tracks another remote branch, rerun git status.
$ git reset --hard origin/master # Else if your local master branch has diverged from origin/master.
$ git rebase -i <upstream-version>
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

```sh
git switch -c <development-branch>
```

Create a pull request to master within our fork, get it reviewed, and then merged.

### Step 4

Create or reuse a release branch for the fork based on an upstream release.

The releases will follow the version of the upstream version, with the version string `<version>-ck8s`.

- `<version>` - denotes the current version of the upstream version.
- `ck8s` - added to prevent confusion with upstream release branch

```sh
git fetch --all

# if a release/patch exists and you only want to add a fix to the fork:
git switch "release-<X.Y.Z>-ck8s"

# if no release branch exists in the fork:
git switch <X.Y.Z> # upstream release
git switch -c "release-<X.Y.Z>-ck8s"

git push -u origin "release-<X.Y.Z>-ck8s"
```

### Step 5

Backport the fixes to the release branch.

```sh
git cherry-pick <COMMIT-SHA> <[COMMIT-SHA ...]>
git push
```

### Step 6

Update the submodule reference in compliantkubernetes-kubespray.

```sh
cd compliantkubernetes-kubespray
git switch main
git pull
git submodule update --init
git switch -c <development-branch>

cd kubespray
git switch "release-<X.Y.Z>-ck8s"
cd ..
git add kubespray
git commit -m "Upgrade kubespray fork ..."
git push
# open pull request towards main branch of compliantkubernetes-kubespray
```

### Step 7 (Only do this when creating a release for compliantkubernetes-kubespray)

Tag the latest commit in the fork release branch. `patch-number` starts at 1 and increments by one for every new `compliantkubernetes-kubespray` release.

```sh
cd <fork-directory>
git switch "release-<X.Y.Z>-ck8s"
git pull
git tag -a "<vX.Y.Z>-ck8s<patch-number>"
git push --tags
```
