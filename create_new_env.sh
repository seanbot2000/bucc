#!/bin/bash
echo "IAAS = " $1
echo "Environment Name = " $2

if [ $# != 2 ]; then
  echo "This requires 2 arguments i.e : create_new_env.sh gcp new_gcp_environment_name"
  exit 1
fi

echo "Adding $2 environment in $1 cloud"
credhub set -n /concourse/$2/iaas -t value -v $1
credhub set -n /concourse/$2/environment_name -t value -v $2
credhub set -n /concourse/$2/email -t value -v "$(credhub get -n /concourse/pa/email -j | jq .value)"

#echo "Adding app.terraform.io"
#credhub set -n /concourse/$2/app_terraform_io_token -t value -v "$(credhub get -n /concourse/pa/app_terraform_io_token -j | jq .value)"
#credhub set -n /concourse/$2/app_terraform_io_org -t value -v "$(credhub get -n /concourse/pa/app_terraform_io_org -j | jq .value)"

echo "Adding Pivnet token"
credhub set -n /concourse/$2/pivnet_token -t value -v "$(credhub get -n /concourse/pa/pivnet_token -j | jq .value)"

echo "Adding CredHub vals"
credhub set -n /concourse/$2/credhub_url -t value -v "$(credhub get -n /concourse/main/credhub_url -j | jq .value)"
credhub set -n /concourse/$2/credhub_ca_cert -t value -v "$(credhub get -n /concourse/main/credhub_ca_cert -j | jq .value)"
credhub set -n /concourse/$2/credhub_username -t value -v "$(credhub get -n /concourse/main/credhub_username -j | jq .value)"
credhub set -n /concourse/$2/credhub_password -t value -v "$(credhub get -n /concourse/main/credhub_password -j | jq .value)"

echo "Adding git ssh key"
credhub set -n /concourse/$2/git_ssh_key -t value -v "$(credhub get -n /concourse/pa/git_ssh_key -j | jq .value)"

echo "Adding OpsManager credentials"
credhub set -n /concourse/$2/opsman_admin_username -t value -v admin
credhub generate -n /concourse/$2/opsman_admin_password -t password

echo "Adding Decryption Passphrase"
credhub generate -n /concourse/$2/decryption_passphrase -t password

if [ "$1" = "gcp" ]; then
  echo "Adding GCP vals"
  credhub set -n /concourse/$2/project -t value -v "$(credhub get -n /concourse/pa/project -j | jq .value)"
  credhub set -n /concourse/$2/gcp_credentials_json -t value -v "$(credhub get -n /concourse/pa/gcp_credentials_json -j | jq .value)"
fi

if [ "$1" = "aws" ]; then
  echo "Adding AWS vals"
  credhub set -n /concourse/$2/aws_access_key -t value -v "$(credhub get -n /concourse/pa/aws_access_key -j | jq .value)"
  credhub set -n /concourse/$2/aws_secret_key -t value -v "$(credhub get -n /concourse/pa/aws_secret_key -j | jq .value)"
fi

if [ "$1" = "azure" ]; then
  echo "Adding Azure vals"
  credhub set -n /concourse/$2/azure_access_key -t value -v "$(credhub get -n /concourse/pa/azure_access_key -j | jq .value)"
  credhub set -n /concourse/$2/azure_cf_resource_group_name -t value -v "$(credhub get -n /concourse/pa/azure_cf_resource_group_name -j | jq .value)"
  credhub set -n /concourse/$2/azure_cf_storage_account_name -t value -v "$(credhub get -n /concourse/pa/azure_cf_storage_account_name -j | jq .value)"
  credhub set -n /concourse/$2/azure_client_id -t value -v "$(credhub get -n /concourse/pa/azure_client_id -j | jq .value)"
  credhub set -n /concourse/$2/azure_client_secret -t value -v "$(credhub get -n /concourse/pa/azure_client_secret -j | jq .value)"
  credhub set -n /concourse/$2/azure_subscription_id -t value -v "$(credhub get -n /concourse/pa/azure_subscription_id -j | jq .value)"
  credhub set -n /concourse/$2/azure_tenant_id -t value -v "$(credhub get -n /concourse/pa/azure_tenant_id -j | jq .value)"
  credhub set -n /concourse/$2/azure_terraform_container_name -t value -v "$(credhub get -n /concourse/pa/azure_terraform_container_name -j | jq .value)"
  credhub set -n /concourse/$2/azure_terraform_resource_group_name -t value -v "$(credhub get -n /concourse/pa/azure_terraform_resource_group_name -j | jq .value)"
  credhub set -n /concourse/$2/azure_terraform_storage_account_name -t value -v "$(credhub get -n /concourse/pa/azure_terraform_storage_account_name -j | jq .value)"
fi

# Create temporary cloudflare.ini file
echo "dns_cloudflare_email = "$(credhub get -n /concourse/pa/cloudflare_email -j | jq .value)"" >> ./cloudflare.ini
echo "dns_cloudflare_api_key = "$(credhub get -n /concourse/pa/cloudflare_key -j | jq .value)"" >> ./cloudflare.ini

# Create or update the certificate
sudo certbot certonly --dns-cloudflare \
                      --dns-cloudflare-propagation-seconds 60  \
                      --dns-cloudflare-credentials ./cloudflare.ini \
                      --preferred-challenges dns-01 \
                      -d $2.$1.codeinthecloud.io \
                      -d *.apps.$2.$1.codeinthecloud.io \
                      -d *.sys.$2.$1.codeinthecloud.io \
                      -d opsmanager.$2.$1.codeinthecloud.io \
                      -d *.pks.$2.$1.codeinthecloud.io \
                      --agree-tos \
                      -m snoyes@pivotal.io \
                      --cert-path ./

echo "Certs exist"

credhub delete -n /concourse/$2/acme_cert

# Store the certificate bits in credhub
credhub set -n /concourse/$2/acme_cert \
            -t certificate \
            -c "$(sudo cat /etc/letsencrypt/live/$2.$1.codeinthecloud.io/fullchain.pem)" \
            -p "$(sudo cat /etc/letsencrypt/live/$2.$1.codeinthecloud.io/privkey.pem)"

echo "Certs updated"

# Delete the temporary cloudflare.ini file
rm ./cloudflare.ini

echo "Cleanup complete"
