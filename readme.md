# Terraform

### 環境

+ WSL ubuntu 18.04
  
  目的creare AKS
  
  1. deploy wordpress (web)
  2. deploy mysql

### 使用 terraform 達到下面目的

+ creare AKS

+ deploy wordpress 

+ deploy mariadb

## Start

---

### install az command

```
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### install  terraform

```
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

### login azure

```
az login
az account show --subscription <subscription_name> --query id

# az account show --subscription "Corp IT" --query id
## output "b14cff6a-38c4-4aec-9335-b453xxxxxx"
```

### create a service rbac to creating aks

```
az ad sp create-for-rbac --name <service_principal_name> --role Contributor --scopes /subscriptions/<subscription_id>

# az ad sp create-for-rbac --name harry-test --role Contributor --scopes /subscriptions/"b14cff6a-38c4-4aec-9335-bxxxxxxx"
## output
{
  "appId": "bba80fdc-2876-4ea5-83c3-xxxxx",
  "displayName": "harry-test",
  "password": "QWv8Q~GkmAFjeV--kd-cSsyeQxxx",
  "tenant": "19f25823-17ff-421f-ad4e-8fed0xxxxx"

}
```

### create env

   edit  .connection.env file  && into os env

```
cat <<EOF >> .connection.env
export ARM_CLIENT_ID="xxx" <appID>
export ARM_CLIENT_SECRET="xxx" <Password>
export ARM_SUBSCRIPTION_ID="xxx" <SubscriptionID>
export ARM_TENANT_ID="xxx" <TenantID>
EOF

source .connection.env
```

### get aks aks_service_principal_app_id

```
## create terraform.tfvars

cat <<EOF >> terraform.tfvars
aks_service_principal_app_id = "your-principal-app-id"
aks_service_principal_client_secret = "your-principal-client-secret"
EOF
```

> **NOTE:** You will be needing an SSH key. If you don’t have one under “~/.ssh/” you must create it.

```
ssh-keygen -t rsa -b 4096
```

### File structure

    為了安全起見並不會上傳 .connection.env && terraform.tfvars
```
 └── azure
  ├── .connection.env
  ├── main.tf
  ├── outputs.tf
  ├── providers.tf
  ├── terraform.tfvars
  └── variables.tf
```
### Terraform Run

```
terraform init
terraform plan
--> output.txt # this is plan logs
terraform apply
```

get need kubeconfig && wordpress

```
terraform output -raw kube_config > aks_kubeconfig
kubectl --kubeconfig=aks_kubeconfig get svc
```

## ref.

+ [快速入門：使用 Terraform 部署適用于 AKS 叢集的 Azure Linux 容器主機 | Microsoft Learn](https://learn.microsoft.com/zh-tw/azure/azure-linux/quickstart-terraform)

+ [Deploy Kubernetes Load Balancer Service with Terraform | Google Cloud Skills Boost](https://www.cloudskillsboost.google/focuses/1205?parent=catalog)

+ https://akshayavb99.medium.com/hosting-wordpress-and-mysql-using-aws-kubernetes-and-terraform-efbb8c73950c

+ [在 Linux 上安裝 Azure CLI | Microsoft Learn](https://learn.microsoft.com/zh-tw/cli/azure/install-azure-cli-linux?pivots=apt)
