# Migration steps

## Migration template and script

There is a script that can help you create the initial migration folder and `upgrade-cluster.md` document.

This script must have ck8s-kubespray old and new versions as arguments including patch versions.
If patch version does not matter for this migration then replace it with x. The second argument should include the full new version.

You can use the following command to run it from the root of compliantkubernetes-kubespray directory:

```bash
./migration/create-migration-document.sh v2.30.x-ck8sx v2.31.0-ck8s1
```
