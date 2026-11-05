<?php

/**
 * @file
 * Local settings override for Drupal.
 *
 * This file is loaded after settings.php and is intended for environment-
 * specific settings.
 */

// Ensure the $databases array exists.
if (!isset($databases)) {
  $databases = [];
}

$databases['default']['default'] = [
  'driver'   => 'mysql',
  'database' => getenv('DB_NAME') ? getenv('DB_NAME') : 'drupal',
  'username' => getenv('DB_USER') ? getenv('DB_USER') : 'drupal',
  'password' => getenv('DB_PASSWORD') ? getenv('DB_PASSWORD') : '',
  'host'     => getenv('DB_HOST') ? getenv('DB_HOST') : '127.0.0.1',
  'port'     => getenv('DB_PORT') ? getenv('DB_PORT') : '3306',
  'prefix'   => '',
];

// Set the Drupal hash salt from an environment variable. Fail closed: with a
// predictable salt, session and one-time-login tokens are forgeable.
$hash_salt = getenv('DRUPAL_HASH_SALT');
if (!$hash_salt) {
  http_response_code(500);
  exit('DRUPAL_HASH_SALT is not set.');
}
$settings['hash_salt'] = $hash_salt;

/**
 * Trusted Host Patterns from environment variable
 *
 * Expecting TRUSTED_HOST_PATTERNS to be a comma-separated string, e.g.
 * "^example\.com$,^.+\.example\.com$"
 */
$trusted_hosts_env = getenv('TRUSTED_HOST_PATTERNS');
if (!$trusted_hosts_env) {
  http_response_code(500);
  exit('TRUSTED_HOST_PATTERNS is not set.');
}
$settings['trusted_host_patterns'] = array_map('trim', explode(',', $trusted_hosts_env));

/**
 * Reverse Proxy Settings from environment variables
 */
$settings['reverse_proxy'] = TRUE;
// For `reverse_proxy_addresses`, we expect a comma-separated list of IPs/CIDRs.
$reverse_proxy_addresses_env = getenv('REVERSE_PROXY_ADDRESSES');
if ($reverse_proxy_addresses_env) {
  $settings['reverse_proxy_addresses'] = array_map('trim', explode(',', $reverse_proxy_addresses_env));
} else {
  // You might provide defaults or leave empty.
  $settings['reverse_proxy_addresses'] = [];
}
// Trust only the X-Forwarded-* headers the gateway manages. Core's fallback
// also trusts RFC 7239 "Forwarded", which the gateway passes through
// unmodified, so a client sending one makes Symfony throw
// ConflictingHeadersException on the two disagreeing trusted sources.
$settings['reverse_proxy_trusted_headers'] =
  \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_FOR
  | \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_HOST
  | \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_PORT
  | \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_PROTO;

/**
 * @todo Work around the compiled-container race during rolling updates.
 *
 * All pods share one database, and the compiled service container is cached
 * in the cache_container table. When an update that changes service
 * definitions rolls out, a pod running the old code can recompile and write
 * a container that the new pods then load, fataling with a class-not-found
 * error on every request and crash-looping until the cache is cleared. A
 * possible fix is pinning the container cache to a per-pod backend:
 * @code
 * $settings['cache']['bins']['container'] = 'cache.backend.apcu';
 * @endcode
 * but APCu is typically disabled for CLI, so verify Drush still works before
 * adopting it. Recovery without the fix: scale the Drupal deployment to 0,
 * run `DELETE FROM cache_container;` on the database, then scale back up.
 */

// Prepare configuration overrides for import.  Environment variables can't have underscores or colons so these must be
// converted back into Platform.sh's format (https://docs.platform.sh/development/variables.html#implementation-example).
$config_overrides = [];
foreach (getenv() as $sanitized_env_var_key => $env_var_value) {
  if (str_starts_with($sanitized_env_var_key, 'drupalsettings__') || str_starts_with($sanitized_env_var_key, 'drupalconfig__')) {
    $dotted_env_var_key = str_replace('__DOT__', '.', $sanitized_env_var_key);
    $unsanitized_env_var_key = str_replace('__', ':', $dotted_env_var_key);
    $config_overrides[$unsanitized_env_var_key] = $env_var_value;
  }
}
/**
 * Import configuration overrides.
 *
 * @see https://github.com/platformsh-templates/drupal11/blob/master/web/sites/default/settings.platformsh.php#L133
 */
// Import variables prefixed with 'drupalsettings:' into $settings
// and 'drupalconfig:' into $config.
foreach ($config_overrides as $name => $value) {
  $parts = explode(':', $name);
  list($prefix, $key) = array_pad($parts, 3, null);
  switch ($prefix) {
    // Variables that begin with `drupalsettings` or `drupal` get mapped
    // to the $settings array verbatim, even if the value is an array.
    // For example, a variable named drupalsettings:example-setting' with
    // value 'foo' becomes $settings['example-setting'] = 'foo';
    case 'drupalsettings':
    case 'drupal':
      $settings[$key] = $value;
      break;
    // Variables that begin with `drupalconfig` get mapped to the $config
    // array.  Deeply nested variable names, with colon delimiters,
    // get mapped to deeply nested array elements. Array values
    // get added to the end just like a scalar. Variables without
    // both a config object name and property are skipped.
    // Example: Variable `drupalconfig:conf_file:prop` with value `foo` becomes
    // $config['conf_file']['prop'] = 'foo';
    // Example: Variable `drupalconfig:conf_file:prop:subprop` with value `foo` becomes
    // $config['conf_file']['prop']['subprop'] = 'foo';
    // Example: Variable `drupalconfig:conf_file:prop:subprop` with value ['foo' => 'bar'] becomes
    // $config['conf_file']['prop']['subprop']['foo'] = 'bar';
    // Example: Variable `drupalconfig:prop` is ignored.
    case 'drupalconfig':
      if (count($parts) > 2) {
        $temp = &$config[$key];
        foreach (array_slice($parts, 2) as $n) {
          $prev = &$temp;
          $temp = &$temp[$n];
        }
        $prev[$n] = $value;
      }
      break;
  }
}
