resource "helm_release" "mariadb_operator_crds" {
  name             = "mariadb-operator-crds"
  namespace        = kubernetes_namespace.drupal_namespace.metadata[0].name
  create_namespace = false
  repository       = "https://helm.mariadb.com/mariadb-operator"
  chart            = "mariadb-operator-crds"
  version          = var.mariadb_operator_chart_version
}

resource "helm_release" "mariadb_operator" {
  name       = "mariadb-operator"
  namespace  = kubernetes_namespace.drupal_namespace.metadata[0].name
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
  # Server-side apply: manage only the fields declared here, so operator-defaulted
  # immutable fields (rootEmptyPassword, storage.ephemeral, metrics.username) aren't
  # nulled on apply. force_conflicts claims fields previously set via client-side
  # apply or manual kubectl patches.
  server_side_apply = true
  force_conflicts   = true
  depends_on = [
    helm_release.mariadb_operator_crds,
    helm_release.mariadb_operator
  ]
  yaml_body = <<YAML
    apiVersion: "k8s.mariadb.com/v1alpha1"
    kind: "MariaDB"
    metadata:
      name: "mariadb"
      namespace: ${kubernetes_namespace.drupal_namespace.metadata[0].name}
    spec:
      rootPasswordSecretKeyRef:
        name: ${kubernetes_secret.drupal_secrets.metadata[0].name}
        key: "MARIADB_ROOT_PASSWORD"
      storage:
        size: ${var.drupal_db_storage_size}
        storageClassName: ${var.db_storage_class}
      replicas: ${var.mariadb_number_of_replicas}
      replication:
        enabled: true
        primary:
          # Delay failover so a transient liveness blip on the primary doesn't
          # promote a new one and strand an un-replicated commit on the old one
          # (which then can't rejoin under gtidStrictMode and crash-loops).
          autoFailoverDelay: ${var.mariadb_auto_failover_delay}
        replica:
          # Seed and recover replicas from a fresh mariabackup of an up-to-date
          # node; without this the operator replicates from scratch, which can't
          # work once the primary's binlog is purged. recovery auto-rebuilds a
          # faulty replica from bootstrapFrom.
          bootstrapFrom:
            physicalBackupTemplateRef:
              name: ${var.mariadb_replica_bootstrap_name}
          recovery:
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
        serviceMonitor: {}
        exporter:
          resources:
            requests:
              cpu: ${var.mariadb_metrics_cpu_request}
              memory: ${var.mariadb_metrics_memory_request}
            limits:
              cpu: ${var.mariadb_metrics_cpu_limit}
              memory: ${var.mariadb_metrics_memory_limit}
YAML
}

# Non-running template (schedule suspended) the operator instantiates on demand
# to seed/recover replicas (spec.replication.replica.bootstrapFrom). Each
# recovery/scale-out spins up a transient backup PVC the operator does not
# reclaim -- prune the leftover *-pb-recovery PVC afterwards. Upstream:
# https://github.com/mariadb-operator/mariadb-operator/issues/1818
resource "kubectl_manifest" "mariadb_physicalbackup_template" {
  depends_on = [kubectl_manifest.mariadb_cluster]
  yaml_body  = <<YAML
    apiVersion: "k8s.mariadb.com/v1alpha1"
    kind: "PhysicalBackup"
    metadata:
      name: ${var.mariadb_replica_bootstrap_name}
      namespace: ${kubernetes_namespace.drupal_namespace.metadata[0].name}
    spec:
      mariaDbRef:
        name: "mariadb"
      schedule:
        cron: "0 0 1 1 *"
        suspend: true
      storage:
        persistentVolumeClaim:
          accessModes:
            - "ReadWriteOnce"
          storageClassName: ${var.db_storage_class}
          resources:
            requests:
              storage: ${var.drupal_db_storage_size}
YAML
}

resource "kubectl_manifest" "mariadb_database" {
  depends_on = [kubectl_manifest.mariadb_cluster]
  yaml_body  = <<YAML
    apiVersion: "k8s.mariadb.com/v1alpha1"
    kind: "Database"
    metadata:
      name: ${var.db_schema}
      namespace: ${kubernetes_namespace.drupal_namespace.metadata[0].name}
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
  yaml_body  = <<YAML
    apiVersion: "k8s.mariadb.com/v1alpha1"
    kind: "User"
    metadata:
      name: ${var.db_username}
      namespace: ${kubernetes_namespace.drupal_namespace.metadata[0].name}
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
      namespace: ${kubernetes_namespace.drupal_namespace.metadata[0].name}
    spec:
      mariaDbRef:
        name: "mariadb"
      privileges:
        - "ALL PRIVILEGES"
      database: ${var.db_schema}
      username: ${var.db_username}
YAML
}
