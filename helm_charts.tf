resource "helm_release" "bitnami_drupal" {
  name       = "bitnami-drupal"
  namespace  = kubernetes_namespace.drupal_dashboard.metadata[0].name
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "drupal"
  version    = var.helm_chart_version

  # TODO: Set values as per
  # https://github.com/bitnami/charts/tree/main/bitnami/drupal#parameters
}
