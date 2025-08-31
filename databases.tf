resource "helm_release" "mariadb_operator_crds" {
  name             = "mariadb-operator-crds"
  namespace        = kubernetes_namespace.drupal_dashboard.metadata[0].name
  create_namespace = false
  repository       = "https://helm.mariadb.com/mariadb-operator"
  chart            = "mariadb-operator-crds"
  version          = var.mariadb_operator_chart_version
}

resource "helm_release" "mariadb_operator" {
  name       = "mariadb-operator"
  namespace  = kubernetes_namespace.drupal_dashboard.metadata[0].name
  repository = "https://helm.mariadb.com/mariadb-operator"
  chart      = "mariadb-operator"
  version    = var.mariadb_operator_chart_version
  values = [yamlencode({
    metrics = {
      enabled = true
      serviceMonitor = {
        enabled = true
      }
    }
  })]
}

resource "kubectl_manifest" "mariadb_cluster" {
  depends_on = [
    helm_release.mariadb_operator_crds,
    helm_release.mariadb_operator
  ]
  yaml_body = <<YAML
    apiVersion: "k8s.mariadb.com/v1alpha1"
    kind: "MariaDB"
    metadata:
      name: "mariadb"
      namespace: ${kubernetes_namespace.drupal_dashboard.metadata[0].name}
    spec:
      rootPasswordSecretKeyRef:
        name: ${kubernetes_secret.drupal_secrets.metadata[0].name}
        key: "MARIADB_ROOT_PASSWORD"
      storage:
        size: ${var.drupal_db_storage_size}
        storageClassName: ${var.db_storage_class}
      replicas: ${var.mariadb_replicas}
      replication:
        enabled: true
      primaryService:
        type: "ClusterIP"
      secondaryService:
        type: "ClusterIP"
      resources:
        requests:
          cpu: ${var.mariadb_cpu_request}
          memory: ${var.mariadb_memory_request}
        limits:
          cpu: ${var.mariadb_cpu_limit}
          memory: ${var.mariadb_memory_limit}
      myCnf: |-
        [mariadb]
        transaction-isolation=READ-COMMITTED
      # Enable DB metrics (mysqld-exporter + ServiceMonitor)
      metrics:
        enabled: true
        serviceMonitor:
          enabled: true
          # optionally add labels/selectors to match your Prometheus Operator
          # additionalLabels:
          #   release: "prometheus"
        resources:
          requests:
            cpu: ${var.mariadb_metrics_cpu_request}
            memory: ${var.mariadb_metrics_memory_request}
          limits:
            cpu: ${var.mariadb_metrics_cpu_limit}
            memory: ${var.mariadb_metrics_memory_limit}
YAML
}

resource "kubectl_manifest" "mariadb_database" {
  depends_on = [kubectl_manifest.mariadb_cluster]
  yaml_body = <<YAML
    apiVersion: "k8s.mariadb.com/v1alpha1"
    kind: "Database"
    metadata:
      name: ${var.db_schema}
      namespace: ${kubernetes_namespace.drupal_dashboard.metadata[0].name}
    spec:
      name: ${var.db_schema}
      mariaDbRef:
        name: "mariadb"
      characterSet: "utf8mb4"
      collate: "utf8mb4_general_ci"
YAML
}

resource "kubectl_manifest" "mariadb_user" {
  depends_on = [kubectl_manifest.mariadb_cluster]
  yaml_body = <<YAML
    apiVersion: "k8s.mariadb.com/v1alpha1"
    kind: "User"
    metadata:
      name: ${var.db_username}
      namespace: ${kubernetes_namespace.drupal_dashboard.metadata[0].name}
    spec:
      mariaDbRef:
        name: "mariadb"
      passwordSecretKeyRef:
        name: ${kubernetes_secret.drupal_secrets.metadata[0].name}
        key: "DATABASE_PASSWORD"
YAML
}

resource "kubectl_manifest" "mariadb_grant" {
  depends_on = [
    kubectl_manifest.mariadb_user,
    kubectl_manifest.mariadb_database
  ]
  yaml_body = <<YAML
    apiVersion: "k8s.mariadb.com/v1alpha1"
    kind: "Grant"
    metadata:
      name: "${var.db_username}-on-${var.db_schema}"
      namespace: ${kubernetes_namespace.drupal_dashboard.metadata[0].name}
    spec:
      mariaDbRef:
        name: "mariadb"
      privileges:
        - "ALL PRIVILEGES"
      database: ${var.db_schema}
      username: ${var.db_username}
YAML
}
