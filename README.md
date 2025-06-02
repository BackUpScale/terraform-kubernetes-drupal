# Drubernetes

## Introduction

Drubernetes is a Terraform module for provisioning Drupal within a generic Kubernetes cluster.

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

## What's missing

While we try to as much as we can here, this project can't do everything.  Notably...

### Backups

It would be hard to find a generic way to automate backups for all Drupal site running in Kubernetes.  As such, this module does not support this feature, even though it's something you need.

**So make sure to get your own backups rolling!**

For our own instance, we have a GitLab CI pipeline schedule that runs a job to dump the database, compresses it, and then pushes it to a bucket at our object storage provider.

## References

* [Terraform registry module](https://registry.terraform.io/modules/BackUpScale/drupal/kubernetes)
* [Project tracker for issues, MRs, etc.](https://gitlab.com/backupscale/drubernetes)