# This module deploys a Drupal site on Kubernetes using an image built with Composer.
# It creates a dedicated namespace, builds a Drupal image, deploys the Drupal pods (2 replicas)
# with a PVC for files, deploys a MariaDB database, and configures internal (ClusterIP) and external (Ingress)
# access via a Civo load balancer with Let's Encrypt TLS.
