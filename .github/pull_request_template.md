**What this PR does / why we need it**:

**Which issue this PR fixes** *(use the format `fixes #<issue number>(, fixes #<issue_number>, ...)` to automatically close the issue when PR gets merged)*: fixes #

**Public facing documentation PR** *(if applicable)*
<!-- https://github.com/elastisys/compliantkubernetes/pull/ -->

**Special notes for reviewer**:

**Checklist:**

- [ ] Proper commit message prefix on all commits
- [ ] Updated the [public facing documentation](https://github.com/elastisys/compliantkubernetes)
- Is this changeset backwards compatible for existing clusters? Applying:
  - [ ] is completely transparent, will not impact the workload in any way.
  - [ ] requires running a migration script.
  - [ ] requires draining and/or replacing nodes.
  - [ ] will break the cluster.
        I.e. full cluster migration is required.

<!--
Here are the commit prefixes and comments on when to use them:
all: (things that touch on more than one of the areas below, or don't fit any of them)
apps: (changes to app installers e.g. rook)
docs: (documentation)
tests: (test related changes)
pipeline: (the pipeline)
config: (configuration, e.g. add/remove/change values under `config`)
bin: (changes to binaries or scripts)

Example commit prefix usage:

git commit -m "docs: Add instructions for how to do x"
-->
