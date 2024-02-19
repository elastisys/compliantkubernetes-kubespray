# Migration steps

## Migration template and script

There is a script that can help you create the initial migration folder and `README.md` document.

This script must have ck8s-kubespray old and new versions as arguments.
These arguments should include as much of the versions as is necessary; for new minor versions include major/minor version, for new patch versions include major/minor/patch version, etc.

You can use the following command to run it from the root of compliantkubernetes-kubespray directory:

```bash
./migration/create-migration-document.sh v2.30 v2.31
```
