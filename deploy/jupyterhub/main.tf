## Built on: http://danielfrg.com/blog/2016/09/03/jupyterhub-kubernetes-ldap/

##############################
## Create kubernetes configuration for jupyterhub
#

//variable "ssl_cert" {
//  description = "Map of cert and key with SSL creds for proxy"
//  type        = "map"
//}

output "jupyter_service_lbip" {
  value = "${kubernetes_service.jupyter-public.load_balancer_ingress.0.ip}"
}

##############################
## Start Main Module
#

#service account for PODs, this service account is for Kubernetes, not Google
resource "kubernetes_service_account" "kube-sa" {
  metadata {
    name = "kube-sa"
  }

  secret {
    name = "${kubernetes_secret.kube-secret.metadata.0.name}"
  }
}

resource "kubernetes_secret" "kube-secret" {
  metadata {
    name = "kube-secret"
  }
}

## Secret key and cert for SSL Support in Jupyterhub proxy
//resource "kubernetes_secret" "proxy-ssl" {
//  metadata {
//    name = "proxy-ssl"
//  }
//
//  data {
//    jupyterhub-cert.pem = "${file("${var.ssl_cert["cert"]}")}"
//    jupyterhub-key.key  = "${file("${var.ssl_cert["key"]}")}"
//  }
//}

## assign the container "pod"
resource "kubernetes_pod" "jupyterhub" {
  metadata {
    name = "jupyter-notebook"

    labels {
      app = "jupyter-app"
    }
  }

  spec {
    service_account_name = "${kubernetes_service_account.kube-sa.metadata.0.name}"

//    container {
//      image = "jupyterhub/configurable-http-proxy"
//      name  = "proxy"
//
//      port {
//        container_port = 8000
//      }
//
//      port {
//        container_port = 8001
//      }
//
//      command = [
//        "configurable-http-proxy",
//        "--ip",
//        "0.0.0.0",
//        "--api-ip",
//        "0.0.0.0",
//        "--default-target",
//        "http://127.0.0.1:8081",
//        "--error-target",
//        "http://127.0.0.1:8081/hub/error",
//        "--ssl-key",
//        "/srv/configurable-http-proxy/ssl/jupyterhub-key.key",
//        "--ssl-cert",
//        "/srv/configurable-http-proxy/ssl/jupyterhub-cert.pem",
//      ]
//
//      volume_mount {
//        mount_path = "/srv/configurable-http-proxy/ssl/"
//        name       = "proxy-ssl"
//        read_only  = true
//      }
//    }

    container {
      image = ""
      name  = "hub"

      port {
        container_port = 8000
      }

      command = [
        "jupyterhub",
        "-f",
        "/srv/jupyterhub/config/jupyterhub-config.py",
        "--debug",
      ]

      volume_mount {
        mount_path = "/var/run/secrets/kubernetes.io/serviceaccount"
        name       = "${kubernetes_service_account.kube-sa.default_secret_name}"
        read_only  = true
      }

      volume_mount {
        mount_path = "/srv/jupyterhub/config/"
        name       = "jupyterhub-config"
        read_only  = false
      }

    }


    volume {
      name = "${kubernetes_service_account.kube-sa.default_secret_name}"

      secret {
        secret_name = "${kubernetes_service_account.kube-sa.default_secret_name}"
      }
    }

//    volume {
//      name = "proxy-ssl"
//
//      secret {
//        secret_name = "${kubernetes_secret.proxy-ssl.metadata.0.name}"
//      }
//    }
  volume {
      name = "jupyterhub-config"

     config_map {
       name = "${var.jupyterhub-config}"
      }
    }


  }
}

resource "kubernetes_service" "jupyter-public" {
  metadata {
    name = "jupyter-public"
  }

  spec {
    selector {
      app = "${kubernetes_pod.jupyterhub.metadata.0.labels.app}"
    }

    port {
      port        = 8000
      target_port = 8000
    }

    type = "LoadBalancer"
  }
}

## create a service that exposes the pod as part of a load balancer
resource "kubernetes_service" "hub-internal" {
  metadata {
    name = "jupyter-notebook"
  }

  spec {
    selector {
      app = "${kubernetes_pod.jupyterhub.metadata.0.labels.app}"
    }

    port {
      port = 8081
    }

    type = "ClusterIP"
  }
}