# @summary Installs and configures a Zabbix server with MySQL and Apache.
# @param ssl_cert Absolute path to the TLS certificate file used by the Apache vhost.
# @param ssl_key Absolute path to the TLS private key file used by the Apache vhost.
# @param db_host Database host used by the Zabbix server backend.
# @param db_port Database port used by the Zabbix server backend.
# @param db_name Name of the MySQL database created for Zabbix.
# @param db_user Database username granted access to the Zabbix database.
# @param db_password Database password for `db_user`.
# @param php_timezone PHP timezone value written to the frontend configuration.
# @param zabbix_host Hostname used for Apache virtual hosts and Zabbix API access.
# @param zabbix_port Port where the Zabbix server listens for trapper and agent data.
# @param cache_size Value for the `CacheSize` setting in `zabbix_server.conf`.
# @param history_index_cache_size Value for the `HistoryIndexCacheSize` setting.
# @param trend_cache_size Value for the `TrendCacheSize` setting.
# @param value_cache_size Value for the `ValueCacheSize` setting.
# @param log_file Absolute path to the Zabbix server log file.
# @param mysql_schema Path to the initial Zabbix MySQL schema archive imported at setup time.
# @param charset MySQL character set used when creating the Zabbix database.
# @param collate MySQL collation used when creating the Zabbix database.
# @param import_cat_cmd Command used by `mysql::db` to read compressed schema files.
# @param pollers Number of poller processes (`StartPollers`).
# @param pingers Number of ICMP pinger processes (`StartPingers`).
# @param pollers_unreachable Number of unreachable poller processes (`StartPollersUnreachable`).
# @param proxy_pollers Number of proxy poller processes (`StartProxyPollers`).
# @param trappers Number of trapper processes (`StartTrappers`).
# @param timeout Zabbix server processing timeout in seconds.
# @param approot Document root base path used by the Apache virtual host.
# @param api_user Username used by the local API bootstrap script.
# @param api_password Password used by the local API bootstrap script.
# @param admin_password Desired Zabbix Admin account password set by the API bootstrap script.
# @param default_group_ids Default host group ID(s) assigned by the API bootstrap script.
# @param default_template_ids Default template ID(s) linked by the API bootstrap script.
# @param icann_nodes_repo Base path to node data consumed by the host sync script.
class zabbix_server (
  Stdlib::Unixpath     $ssl_cert,
  Stdlib::Unixpath     $ssl_key,
  Stdlib::Host         $db_host                  = 'localhost',
  Stdlib::Port         $db_port                  = 3306,
  String               $db_name                  = 'zabbix',
  String               $db_user                  = 'zabbix',
  String               $db_password              = 'changeme',
  String               $php_timezone             = 'UTC',
  Stdlib::Host         $zabbix_host              = $facts['networking']['fqdn'],
  Stdlib::Port         $zabbix_port              = 10051,
  String               $cache_size               = '8M',
  String               $history_index_cache_size = '4M',
  String               $trend_cache_size         = '4M',
  String               $value_cache_size         = '8M',
  Stdlib::Absolutepath $log_file                 = '/var/log/zabbix/zabbix_server.log',
  Stdlib::Absolutepath $mysql_schema             = '/usr/share/doc/zabbix-sql-scripts/mysql/create.sql.gz',
  String               $charset                  = 'utf8mb4',
  String               $collate                  = 'utf8mb4_bin',
  String               $import_cat_cmd           = 'zcat',
  Integer[1, 1000]     $pollers                  = 5,
  Integer[1, 1000]     $pingers                  = 1,
  Integer[1, 1000]     $pollers_unreachable      = 1,
  Integer[1, 1000]     $proxy_pollers            = 1,
  Integer[1, 1000]     $trappers                 = 5,
  Integer[1, 30]       $timeout                  = 3,
  Stdlib::Absolutepath $approot                  = '/srv/www',
  String               $api_user                 = 'user',
  String               $api_password             = 'password',
  String               $admin_password           = 'zabbix',
  Integer              $default_group_ids        = 2,
  Integer              $default_template_ids     = 10001,
  Stdlib::Unixpath     $icann_nodes_repo         = '/etc/hieradata',
) {
  stdlib::ensure_packages([
    'zabbix-server-mysql', 'zabbix-frontend-php', 'zabbix-sql-scripts',
    'snmp-mibs-downloader', 'php-ldap', 'php-bcmath', 'php-mbstring', 'php-xml',
    'python3-yaml',
  ])
  python::pip { 'pyzabbix':
    ensure       => '1.3.1',
    pip_provider => 'pip3',
  }
  mysql::db { $db_name :
    user           => $db_user,
    password       => $db_password,
    host           => $db_host,
    charset        => $charset,
    collate        => $collate,
    grant          => ['all'],
    sql            => [$mysql_schema],
    require        => Package['zabbix-server-mysql'],
    import_cat_cmd => $import_cat_cmd,
  }
  Ini_setting {
    path    => '/etc/zabbix/zabbix_server.conf',
    section => '',
    ensure  => present,
    notify  => Service['zabbix-server'],
  }
  ini_setting {
    'zabbix_port':
      setting => 'ListenPort',
      value   => $zabbix_port;
    'zabbix_db':
      setting => 'DBName',
      value   => $db_name;
    'zabbix_dbhost':
      setting => 'DBHost',
      value   => $db_host;
    'zabbix_dbport':
      setting => 'DBPort',
      value   => $db_port;
    'zabbix_dbpassword':
      setting => 'DBPassword',
      value   => $db_password;
    'cache_size':
      setting => 'CacheSize',
      value   => $cache_size;
    'history_index_cache_size':
      setting => 'HistoryIndexCacheSize',
      value   => $history_index_cache_size;
    'trend_cache_size':
      setting => 'TrendCacheSize',
      value   => $trend_cache_size;
    'value_cache_size':
      setting => 'ValueCacheSize',
      value   => $value_cache_size;
    'log_file':
      setting => 'LogFile',
      value   => $log_file;
    'pollers':
      setting => 'StartPollers',
      value   => $pollers;
    'pingers':
      setting => 'StartPingers',
      value   => $pingers;
    'pollers_unreachable':
      setting => 'StartPollersUnreachable',
      value   => $pollers_unreachable;
    'proxy_pollers':
      setting => 'StartProxyPollers',
      value   => $proxy_pollers;
    'trappers':
      setting => 'StartTrappers',
      value   => $trappers;
    'timeout':
      setting => 'Timeout',
      value   => $timeout;
  }
  service { 'zabbix-server':
    ensure  => running,
    enable  => true,
    require => Mysql::Db[$db_name],
  }
  ensure_resource('file', '/srv/www', { 'ensure' => 'directory' })
  file {
    default:
      ensure => file,
      mode   => '0500';
    '/usr/local/bin/zabbix_host.py':
      content => template('zabbix_server/zabbix_host.py.erb');
    '/usr/local/bin/zabbix_api_setup.py':
      content => template('zabbix_server/zabbix_api_setup.py.erb');
    '/usr/local/sbin/zabbix-maintenance':
      source => 'puppet:///modules/zabbix_server/zabbix_maintenance.py';
  }
  # TODO: should this be https
  $config = {
    'server'   => "http://${zabbix_host}",
    'username' => $api_user,
    'password' => $api_password,
    'repo'     => "${icann_nodes_repo}/nodes",
  }
  file {
    default:
      ensure  => file,
      mode    => '0444',
      require => Package['zabbix-frontend-php'];
    '/etc/zabbix/apache.conf':
      content => template('zabbix_server/apache.conf.erb'),
      notify => Service['apache2'];
    '/etc/zabbix/web/zabbix.conf.php':
      content => template('zabbix_server/zabbix.conf.php.erb');
    '/etc/zabbix/api.yaml':
      mode    => '0400',
      content => $config.to_yaml,
  }
  file { '/etc/ldap/ldap.conf':
    ensure => file,
  }
  file_line { 'Append to /etc/ldap/ldap.conf':
    path    => '/etc/ldap/ldap.conf',
    line    => 'TLS_REQCERT never',
    require => File['/etc/ldap/ldap.conf'],
  }
  include apache
  apache::vhost {
    default:
      servername          => $zabbix_host,
      docroot             => "${approot}/",
      additional_includes => ['/etc/zabbix/apache.conf'];
    "${zabbix_host} non-ssl":
      port => 80;
    $zabbix_host:
      port                 => 443,
      ssl                  => true,
      ssl_cert             => $ssl_cert,
      ssl_key              => $ssl_key,
      ssl_protocol         => '-all +TLSv1.2',
      ssl_cipher           => 'EECDH+AESGCM:EDH+AESGCM',
      ssl_stapling         => true,
      ssl_honorcipherorder => 'on',
      ssl_openssl_conf_cmd => 'DHParameters "/etc/ssl/certs/dhparam.pem"';
  }
  exec { '/usr/local/bin/zabbix_api_setup.py':
    command => '/usr/local/bin/zabbix_api_setup.py && touch /etc/zabbix/api_created',
    creates => '/etc/zabbix/api_created',
    require => [
      File['/usr/local/bin/zabbix_api_setup.py'],
      Apache::Vhost["${zabbix_host} non-ssl"],
      Service['apache2'],
    ],
  } -> Z_host <<||>>
}
