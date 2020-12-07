# Kubernetes on Exoscale with Terraform

## Quickstart

Edit tfvars to match your setup

```bash
$EDITOR tfvars.json
```

Create a encrypted file with your Exoscale credentials

```bash
cat << EOF > secrets.env
TF_VAR_exoscale_api_key=
TF_VAR_exoscale_secret_key=
EOF
sops --encrypt --in-place --pgp <PGP key fingerprint> secrets.env
sops secrets.env
```

Run terraform and create your inventory

```bash
sops exec-env secrets.env 'terraform apply -var-file tfvars.json'
./generate-inventory.sh terraform.tfstate > inventory.ini
```

You should now have a inventory file named `inventory.ini` that you can use with kubespray, e.g.

```bash
ansible-playbook -i /path/to/the/inventory.ini cluster.yml -b -v
```
