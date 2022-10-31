# Upgrade v2.20.0-ck8s2 to v2.20.0-ck8s3

1. Checkout the new release: `git checkout v2.20.0-ck8s3`

1. Switch to the correct remote: `git submodule sync`

1. Update the kubespray submodule: `git submodule update --init --recursive`

    NOTE: This update requires a newer version of terraform, so make sure that you're using terraform 0.14 or later
