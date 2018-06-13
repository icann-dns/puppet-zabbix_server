# == Class: zabbix_server
#
class zabbix_server (
  Stdlib::Host         $db_host              = 'localhost',
  Stdlib::Port         $db_port              = 3306,
  String               $db_name              = 'zabbix',
  String               $db_user              = 'zabbix',
  String               $db_password          = 'changeme',
  String               $php_timezone         = 'UTC',
  Stdlib::Host         $zabbix_host          = $::fqdn,
  Stdlib::Port         $zabbix_port          = 10051,
  String               $cache_size           = '128M',
  String               $value_cache_size     = '256M',
  Stdlib::Absolutepath $log_file             = '/var/log/zabbix/zabbix_server.log',
  Integer[1,1000]      $pollers              = 100,
  Integer[1,1000]      $pingers              = 10,
  Integer[1,1000]      $pollers_unreachable  = 25,
  Integer[1,1000]      $trappers             = 25,
  Integer[1,30]        $timeout              = 3,
  Stdlib::Absolutepath $approot              = '/srv/www',
  String               $api_user             = 'user',
  String               $api_password         = 'password',
  String               $admin_password       = 'zabbix',
  Integer              $default_group_ids    = 2,
  Integer              $default_template_ids = 10001,
) {

  ensure_packages([
    'zabbix-server-mysql', 'zabbix-frontend-php', 'snmp-mibs-downloader',
    'php-ldap', 'php-bcmath', 'php-mbstring', 'php-xml',
  ])
  python::pip {'pyzabbix':
    ensure   => '0.7.4',
  }
  mysql::db{ $db_name :
    user           => $db_user,
    password       => $db_password,
    host           => $db_host,
    grant          => ['all'],
    sql            => '/usr/share/doc/zabbix-server-mysql/create.sql.gz',
    require        => Package['zabbix-server-mysql'],
    import_cat_cmd => 'zcat',
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
    'trappers':
      setting => 'StartTrappers',
      value   => $trappers;
    'timeout':
      setting => 'Timeout',
      value   => $timeout;
  }
  sysctl {'kernel.shmmax':
    value => '268435456',
  }
  service {'zabbix-server':
    ensure  => running,
    enable  => true,
    require => Mysql::Db[$db_name],
  }
  ensure_resource('file', '/srv/www', { 'ensure' => 'directory' })
  file {
    '/usr/local/bin/zabbix_host.py':
      ensure  => file,
      mode    => '0500',
      content => template('zabbix_server/zabbix_host.py.erb');
    '/usr/local/bin/zabbix_reset.py':
      ensure  => file,
      mode    => '0550',
      content => template('zabbix_server/reset_passwords.py.erb');
    '/etc/zabbix/apache.conf':
      ensure  => file,
      content => template('zabbix_server/apache.conf.erb'),
      require => Package['zabbix-frontend-php'],
      notify  => Service['apache2'];
    '/etc/zabbix/web/zabbix.conf.php':
      ensure  => file,
      content => template('zabbix_server/zabbix.conf.php.erb'),
      require => Package['zabbix-frontend-php'];
  }
  file {'/etc/ldap/ldap.conf':
      ensure => present,
  }-> file_line {
    'Append to /etc/ldap/ldap.conf':
      path => '/etc/ldap/ldap.conf',
      line => 'TLS_REQCERT never',
  }
  include apache
  apache::vhost {
    "${zabbix_host} non-ssl":
      servername          => $zabbix_host,
      docroot             => "${approot}/",
      port                => 80,
      additional_includes => ['/etc/zabbix/apache.conf',];
    $zabbix_host:
      servername          => $zabbix_host,
      docroot             => "${approot}/",
      port                => 443,
      additional_includes => ['/etc/zabbix/apache.conf',],
      ssl                 => true,
      ssl_cert            => '/etc/ssl/certs/wildcard.dns.icann.org.crt',
      ssl_key             => '/etc/ssl/private/wildcard.dns.icann.org.key',
      ssl_chain           => '/etc/ssl/certs/DigiCertCA.crt',
      ssl_protocol        => 'all -SSLv2 -SSLv3',
  }
  exec {'/usr/local/bin/zabbix_reset.py':
    command => '/usr/local/bin/zabbix_reset.py && touch /etc/zabbix/api_created',
    creates => '/etc/zabbix/api_created',
    require => [
      File['/usr/local/bin/zabbix_reset.py'],
      Apache::Vhost["${zabbix_host} non-ssl"],
      Service['apache2'],
    ],
  } -> Zabbix_host <<||>>
}
