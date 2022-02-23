
# zabbix_server

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with zabbix_server](#setup)
    * [What zabbix_server affects](#what-zabbix_server-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with zabbix_server](#beginning-with-zabbix_server)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Limitations - OS compatibility, etc.](#limitations)
5. [Development - Guide for contributing to the module](#development)

## Description

This module installas and manages the zabbix server.  It also adds a custom type which allows users to add zabbix hosts via the zabbix API.

## Setup

### What zabbix\_server affects

This module installs a a number of scripts to help the providers work

* /usr/local/bin/zabbix\_host.py
* /usr/local/bin/zabbix\_reset.py

This module also requires the apache module to configuer the zabbix vhost

### Setup Requirements

* This modules needs to `zabbix (0.9.8)` installed on the puppet master. 

you can install this manully with 
```bash
sudo pupetserver gem install zabbix -v 0.9.8
```

or using the `puppetlabs-puppetserver_gem` module

```puppet
package {'zabbix':
  ensure => '0.9.8',
  provider => puppetserver_gem,
}
```

### Beginning with zabbix\_server

You should be able to just `include zabbix_server` to get a basic server up and running. You can add hosts using the`z_host` type.

## Usage

A simple example would be to have all nodes allooceted to one zabbix group and template. Unfortunatly we need to use the template id number and not the description, also this module tose not manage the group and template creation

zabbix.example.com manifest
```puppet
node 'zabbix.example.com' {
  include zabbix
  Z_host <<||>>
}

node /\.servers\.example\.com$/ {
  @@z_host {$::trusted['certname']:
    ensure      => present,
    operational => true,
    groupids    => ['1',]
    templateids => ['10001',]
  }
}
```

## Reference

### Classes

#### zabbix_server

* `db_host` (Stdlib::Host, Default: 'localhost'): The database server name
* `db_port` (Stdlib::Port, Default: 3306): The database server port
* `db_name` (String, Default: 'zabbix'): The name of the database
* `db_user` (String, Default: 'zabbix'): The username to use for creating the databaser
* `db_password` (String, Default: 'changeme'): The password to use for creating the databaser
* `php_timezone` (String, Default: 'UTC'): The timezone to use in php
* `zabbix_host` (Stdlib::Host, Default: $::fqdn): The zabbix host fqdn used for vhosts
* `zabbix_port` (Stdlib::Port, Default: 10051): The port zabbix will use to pole 
* `cache_size` (String, Default: '128M'):  Memory allocation params
* `history_index_cache_size` (String, Default: '16M'): Memory allocation params
* `trend_cache_size` (String, Default: '16M'): Memory allocation params
* `value_cache_size` (String, Default: '256M'): Memory allocation params
* `log_file` (Stdlib::Absolutepath, Default: '/var/log/zabbix/zabbix\_server.log'): log file location
* `pollers` (Integer[11000], Default: 100): Number of pollers
* `pingers` (Integer[11000], Default: 10): Number of Pingers
* `pollers_unreachable` (Integer[11000], Default: 25): How many unreachable Pollers
* `trappers` (Integer[11000], Default: 25): Number of trappers
* `timeout` (Integer[130], Default: 3): The zabbix agent time out value
* `approot` (Stdlib::Absolutepath, Default: '/srv/www'): Apache web root
* `api_user` (String, Default: 'user'): user to use for API calls
* `api_password` (String, Default: 'password'): Password to use for API calls
* `admin_password` (String, Default: 'zabbix'): Admin password for zabbix
* `default_group_ids` (Integer, Default: 2): default group ids to use when creating hosts
* `default_template_ids` (Integer, Default: 10001): Default template id to use when creatng hosts

### Types

#### zabbix\_host

* `host (namevar)` (%r{[\w\-\.]+}): the host name to use for the zabbix host.  the IP addresses of this host wiull be lookedup and added to the host definition as its created
* `operational` (Boolean): This indecates to zabbix if the host is operational or not
* `groupids` (Array[Integer]): Group IDs to add specific host to
* `templateids` (Array[Integer]): Template IDs to add specific host to
