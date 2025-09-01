[[_TOC_]]

## Introduction

**Drubernetes** is a Terraform module for provisioning Drupal within a generic Kubernetes cluster.

It tries to not make any assumptions about your cluster or cloud provider so you should be able to run this in any modern Kubernetes cluster at an cloud provider.  If you can't, please open an issue to add support for your use case.

## Background

This project was created because we couldn't find any generic infrastructure as code (IaC) to do this kind of thing.

It shouldn't be that hard to run Drupal in Kubernetes, but all we could find were no-longer supported projects, projects that didn't do everything you'd typically want to do when running Drupal, or very opinionated projects that weren't generally usable.

## What it does

This module does a lot.  Here's what it can do for you at a high level:

* Sets up a namespace for the installation
* Sets up a MariaDB database
* Sets up a Drupal deployment
* Creates a persistent volume claim (PVC) for Drupal's file system
* Uses Nginx Ingress for setting up the load balancer
* Automatically manages Let's Encrypt TLS certificates for HTTPS
* Provides VPN-only access to Drupal's administration pages
* Sets up a Kubernetes cron job to run Drupal's cron tasks
* Stores sensitive passed-in data as Kubernetes secrets
* Sets your [trusted host patterns](https://www.drupal.org/docs/getting-started/installing-drupal/trusted-host-settings)
* Sets your [reverse proxy addresses](https://www.drupal.org/docs/getting-started/installing-drupal/using-a-load-balancer-or-reverse-proxy)
* Provides a mechanism to inject [configuration overrides](https://www.drupal.org/docs/drupal-apis/configuration-api/configuration-override-system) into Drupal settings (e.g. secrets that you don't want in the DB)
* Makes just about everything configurable via variables

## Non-Terraform components

### Dockerfile

You'll need a Drupal image that the deployment can use, which can be built from a Dockerfile.  As we couldn't find a good one, we [made one ourselves](examples/Dockerfile).  Feel free to modify the example to your liking, and then use that.

You can have your continuous integration (CI) system (e.g. GitLab CI) build it from your Drupal code repository, and then push it to your container registry.

### Drupal settings

Our example [settings.kubernetes.php](examples/settings.kubernetes.php) shouldn't require any modification.  You can add it to your Drupal code repository, and the Dockerfile will use it.

### Configuration overrides

It's possible to pass a list of [configuration overrides](https://www.drupal.org/docs/drupal-apis/configuration-api/configuration-override-system) (e.g. secrets that you don't want in the Drupal DB) into the module.  We use [Platform.sh's methodology](https://docs.platform.sh/development/variables.html#implementation-example).  Here's an example of how to pass a single entry, but you can add more, one per line:


```terraform
  drupal_config_overrides = {
    "drupalconfig:symfony_mailer.mailer_transport.proton_mail:configuration:pass" = var.public_address_smtp_password
  }
```

## Module metadata

These can be found at the Terraform Registry:

* [Inputs](https://registry.terraform.io/modules/BackUpScale/drupal/kubernetes/latest?tab=inputs)
* [Outputs](https://registry.terraform.io/modules/BackUpScale/drupal/kubernetes/latest?tab=outputs)
* [Dependencies](https://registry.terraform.io/modules/BackUpScale/drupal/kubernetes/latest?tab=dependencies)
* [Resources](https://registry.terraform.io/modules/BackUpScale/drupal/kubernetes/latest?tab=resources)

The [Provisioning Instructions](https://registry.terraform.io/modules/BackUpScale/drupal/kubernetes/latest) are on that page too.

## Example implementation

Here's an example of a minimal implementation.  There is more information on some of these below the module inclusion.

For sensitive values (i.e. secrets), don't set these directly in your root variables file because you don't want them in your Git repository.  Instead, get them from [environment variables](https://developer.hashicorp.com/terraform/language/values/variables#environment-variables) (e.g. `TF_VAR_drupal_dashboard_root_password`).  You can set all of these by exporting your vault (e.g. [SOPS](https://getsops.io/) or [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html)) to your environment beforehand.

### Module inclusion

```hcl
module "drupal" {
  # This can also be a relative path if you've installed it as a Git submodule.
  # If you're doing that, leave out the "version".
  source  = "BackUpScale/drupal/kubernetes"
  version = "1.0.0"
  # Assuming you have `alias = "main"` in your `kubernetes` provider definition.
  providers = {
    kubernetes = kubernetes.main
  }
  cluster_terraform_id = civo_kubernetes_cluster.my_cluster.id
  namespace = var.drupal_namespace
  container_registry_credentials = module.gitlab.rendered_container_registry_credentials
  cron_key = var.drupal_cron_key
  db_admin_password = var.drupal_dashboard_root_password
  db_password = var.drupal_dashboard_db_password
  drupal_container_image_url = "registry.gitlab.com/myorg/infrastructure/drupal-${var.cloud_environment}:latest"
  firewall_id_annotation_value = civo_firewall.myfirewall.id
  hash_salt = var.drupal_hash_salt
  public_hostname = cloudflare_record.drupal_public_hostname.name
  private_hostname = cloudflare_record.drupal_private_hostname.name
  technical_contact_email = var.technical_contact_email
}
```

### Container registry credentials

You container registry credentials should probably come from another module (e.g. `gitlab`, if you're using the GitLab container registry) like this:

```hcl
output "rendered_container_registry_credentials" {
  value = data.template_file.container_registry_credentials.rendered
}
```

...where the data is defined like so:

```hcl
data "template_file" "container_registry_credentials" {
  template = file("${path.module}/container_registry_credentials_template.json")
  vars = {
    docker-username = var.registry_pull_token_user
    docker-password = var.registry_pull_token_pass
    docker-server = "https://registry.gitlab.com"
    docker-email = "placeholder@example.com"
    auth = base64encode("${var.registry_pull_token_user}:${var.registry_pull_token_pass}")
  }
}
```

...and `container_registry_credentials.json` has the contents:

```json
{"auths":{"${docker-server}":{"username":"${docker-username}","password":"${docker-password}","email":"${docker-email}","auth":"${auth}"}}}
```

## Drupal operations

### Importing a database

* `gunzip --stdout /tmp/drupal.sql.gz | kubectl --namespace=drupal exec -i service/drupal-service -- drush sql-cli`

### Dumping a database

Normally, one would expect to be able to do something like this:

* `kubectl --namespace=drupal exec -i service/drupal-service -- drush sql:dump --gzip > /tmp/drupal.dump.sql.gz`

It will create a valid dump inside the pod, but all of the bytes probably won't make it back to your workstation, which will produce a dump file that can't be imported. The culprit is almost always the way `kubectl exec` streams large amounts to `stdout`: the SPDY stream can be interrupted, silently truncated, or timed-out long before the database dump is finished, so the file you redirect locally stops in the middle without any error message. This is [a known issue in Kubernetes](https://github.com/kubernetes/kubernetes/issues/124571).  It should work better with Kubernetes clusters ≥ v1.31, which defaults to WebSocket streaming (which has fewer truncation bugs﻿).

In any case, a better option is to download one of your backups, and use that instead.  Besides avoiding the above issue, this process also forces you to test your backups, which is always a good idea.  For more information on backups, see [the section here](#backups).

### Running non-interactive Drush commands

Clear caches:
* `kubectl --namespace=drupal exec -i service/drupal-service -- drush cache:rebuild`

### Running interactive Drush commands

Get a MariaDB database shell:
* `kubectl --namespace=drupal exec -it service/drupal-service -- drush sql:cli`

Get a shell on one of the Drupal containers:
* `kubectl --namespace=drupal exec -it service/drupal-service -- /bin/bash`

## What's missing

While we try to as much as we can here, this project can't do everything.  Notably...

### Backups

It would be hard to find a generic way to automate backups for all Drupal site running in Kubernetes.  As such, this module does not support this feature, even though it's something you need.

**So make sure to get your own backups rolling!**

One option is to set up a GitLab CI pipeline schedule that runs a job to dump the database, compresses it, and then pushes it to a bucket at your object storage provider.  Here's an example of such a job that pushes a DB dump to BackBlaze:

```yaml
backup_drupal_db:
  image: $KUBECTL_IMAGE
  stage: backup
  rules:
    - if: '$CI_PIPELINE_SOURCE == "schedule"'
  script:
    - >
      apk add --no-cache
      --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
      --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community
      --repository=https://dl-cdn.alpinelinux.org/alpine/edge/testing
      b2-tools
    - kubectl config use-context mygroup/myproject:prod  # group/project:agent
    - kubectl --namespace=$DRUPAL_NAMESPACE exec deploy/drupal -- sh -c 'drush sql-dump' | gzip > "$DRUPAL_DB_DUMP_SOURCE_PATH"
    - b2 account authorize "$B2_ID" "$B2_KEY"
    - b2 file upload --no-progress "$DRUPAL_DB_BACKUP_BUCKET" "$DRUPAL_DB_DUMP_SOURCE_PATH" "$DRUPAL_DB_DUMP_UPLOAD_FOLDER/db-$(date +%FT%T%Z).sql.gz"
```

## References

* [Introductory article: Want to Run Drupal in Kubernetes? Try Our New Terraform Module](https://backupscale.com/posts/drubernetes-terraform-module-for-kubernetes-clusters/)
* [Drubernetes on the Terraform Registry](https://registry.terraform.io/modules/BackUpScale/drupal/kubernetes)
* [Drubernetes project tracker for issues, MRs, etc.](https://gitlab.com/backupscale/drubernetes)

## Feedback and contributions

Feedback and contributions are welcome!  To contribute, please:

1. [Create an issue on the board](https://gitlab.com/backupscale/drubernetes/-/boards), and then
2. a merge request (MR) from within the issue (if you can).
