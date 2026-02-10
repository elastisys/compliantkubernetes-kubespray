# Software Bill of Material

For each release we maintain a CycloneDX SBOM which targets to contain all _deployed_ software as part Welkin, although this works by analysing the content of the repository so it may contain more than that.

Additionally we maintain a copy of the SBOM on the `main` branch to be able to track changes in the software components over time.

Configuration is available in `sbom.config.yaml` and overrides in `overrides.yaml`.

Generation runs in a container via `scripts/run-from-container.sh` using the `ghcr.io/elastisys/sbom-generator` image.
Refer to the [sbom-generator documentation](https://github.com/elastisys/sbom-generator) for more details.

Prerequisites:

- Docker or Podman installed.
- Optional: `CK8S_GITHUB_TOKEN` set to avoid GitHub API rate limiting (forwarded to the container if set).
    This should not be required by default behaviour.

Use the script (version is optional and defaults to `latest`, for release it must be set).

Any additional flags are forwarded to the `sbom-generator` image:

```sh
./sbom/generate.sh X.Y.Z --require-evaluation
```

If `--require-evaluation` fails, it lists the components still marked with the default evaluation (from `sbom/sbom.config.yaml`).
Update `overrides.yaml` with an `evaluation` for each listed path, then rerun the command.

> [!tip]
> To verify drift without updating files, run `./sbom/diff.sh`.
