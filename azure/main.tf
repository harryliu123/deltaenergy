# Generate random resource group name
    resource "random_pet" "rg_name" {
      prefix = var.resource_group_name_prefix
    }

    resource "azurerm_resource_group" "rg" {
      location = var.resource_group_location
      name     = random_pet.rg_name.id
    }

    resource "random_id" "log_analytics_workspace_name_suffix" {
      byte_length = 8
    }

    resource "azurerm_log_analytics_workspace" "test" {
      location            = var.log_analytics_workspace_location
      # The WorkSpace name has to be unique across the whole of azure;
      # not just the current subscription/tenant.
      name                = "${var.log_analytics_workspace_name}-${random_id.log_analytics_workspace_name_suffix.dec}"
      resource_group_name = azurerm_resource_group.rg.name
      sku                 = var.log_analytics_workspace_sku
    }

    resource "azurerm_log_analytics_solution" "test" {
      location              = azurerm_log_analytics_workspace.test.location
      resource_group_name   = azurerm_resource_group.rg.name
      solution_name         = "ContainerInsights"
      workspace_name        = azurerm_log_analytics_workspace.test.name
      workspace_resource_id = azurerm_log_analytics_workspace.test.id

      plan {
        product   = "OMSGallery/ContainerInsights"
        publisher = "Microsoft"
      }
    }

    resource "azurerm_kubernetes_cluster" "k8s" {
      location            = azurerm_resource_group.rg.location
      name                = var.cluster_name
      resource_group_name = azurerm_resource_group.rg.name
      dns_prefix          = var.dns_prefix
      tags                = {
        Environment = "Development"
      }

      default_node_pool {
        name       = "harrypool"
        vm_size    = "Standard_D2_v2"
        node_count = var.agent_count
        os_sku = "AzureLinux"
      }
      linux_profile {
        admin_username = "azurelinux"

        ssh_key {
          key_data = file(var.ssh_public_key)
        }
      }
      network_profile {
        network_plugin    = "kubenet"
        load_balancer_sku = "standard"
      }
      service_principal {
        client_id     = var.aks_service_principal_app_id
        client_secret = var.aks_service_principal_client_secret
      }
    }
    
# 定義Kubernetes服務
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.k8s.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.k8s.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.k8s.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.k8s.kube_config.0.cluster_ca_certificate)
}

# 部署WordPress到AKS
resource "kubernetes_deployment" "wordpress" {
  metadata {
    name = "wordpress"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "wordpress"
      }
    }

    template {
      metadata {
        labels = {
          app = "wordpress"
        }
      }

      spec {
        container {
          image = "wordpress:latest"
          name  = "wordpress"

          env {
            name  = "WORDPRESS_DB_HOST"
            value = "mariadb-service"
          }
          
          env {
            name  = "WORDPRESS_DB_USER"
            value = "wordpress"
          }
          env {
            name  = "WORDPRESS_DB_PASSWORD"
            value = "P@ssw0rd"
          }

          port {
            container_port = 80
          }
        }
      }
    }
  }
}



## 定義 mariadb_pvc
resource "kubernetes_persistent_volume_claim" "mariadb-pvc" {
  metadata {
    name = "mariadb-pvc"
    labels = {
      app = "mariadb-pvc"
    }
  }
  spec {
#   storage_class_name = "managed-csi"
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

## 定義 mariadb
resource "kubernetes_deployment" "mariadb" {
  metadata {
    name = "mariadb"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mariadb"
      }
    }

    template {
      metadata {
        labels = {
          app = "mariadb"
        }
      }

      spec {
        volume {
          name = "mariadb-pvc"
#         persistent_volume_claim {
#            claim_name = kubernetes_persistent_volume_claim.mariadb-pvc.metadata.0.name
#          }
        }
        
        container {
          image = "mariadb:latest"
          name  = "mariadb"

          env {
            name  = "MARIADB_ROOT_PASSWORD"
            value = "P@ssw0rd"
          }

          env {
            name  = "MARIADB_DATABASE"
            value = "wordpress"
          }         

          env {
            name  = "MARIADB_USER"
            value = "wordpress"
          }  
          
          env {
            name  = "MARIADB_PASSWORD"
            value = "P@ssw0rd"
          }  
          
          port {
            container_port = 3306
          }
        }
      }
    }
  }
}


# 定義mariadb service
resource "kubernetes_service" "mariadb" {
  metadata {
    name = "mariadb-service"
  }

  spec {
    selector = {
      app = "mariadb"
    }

    port {
      protocol    = "TCP"
      port        = 3306
      target_port = 3306
    }
  }
}

# 定義wordpress service
resource "kubernetes_service" "wordpress" {
  metadata {
    name = "wordpress-service"
  }

  spec {
    selector = {
      app = "wordpress"
    }

    port {
      protocol    = "TCP"
      port        = 80
      target_port = 80
    }
    type = "LoadBalancer"
  }
}
