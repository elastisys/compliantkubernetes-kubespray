# Terraform for Exoscale kubespray cluster

## Quickstart

Edit tfvars to match your setup

```
$EDITOR tfvars.json
```

Create a encrypted file with your Exoscale credentials

```
cat << EOF > secrets.env
TF_VAR_exoscale_api_key=
TF_VAR_exoscale_secret_key=
EOF
sops --encrypt --in-place --pgp <PGP key fingerprint> secrets.env
sops secrets.env
```

Run terraform and create your inventory

```
sops exec-env secrets.env 'terraform apply -var-file tfvars.json'
./generate-inventory.sh terraform.tfstate
mv sc-inventory.ini $CK8S_CONFIG_PATH/sc-config/inventory.ini
mv wc-inventory.ini $CK8S_CONFIG_PATH/wc-config/inventory.ini
```
