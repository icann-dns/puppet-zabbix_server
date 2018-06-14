
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

You should be able to just `include zabbix` to get a basic server up and running.  you can add hosts and sites using the `zabbix_site` and `zabbix_host` types.

## Usage

A simple example would be to have all nodes allooceted to one zabbix group and template.  Unfortunatly we need to use the template id number and not the description, also this module tose not manage the group and template creation


zabbix.example.com manifest
```puppet
node 'zabbix.example.com' {
  include zabbix
  Zabbix_host <<||>>
}

node /\.servers\.example\.com$/ {
  @@zabbix_host {$::trusted['certname']:
    ensure      => present,
    operational => true,
    groupids    => ['1',]
    templateids => ['10001',]
  }
}
```

## Reference

This section is deprecated. Instead, add reference information to your code as Puppet Strings comments, and then use Strings to generate a REFERENCE.md in your module. For details on how to add code comments and generate documentation with Strings, see the Puppet Strings [documentation](https://puppet.com/docs/puppet/latest/puppet_strings.html) and [style guide](https://puppet.com/docs/puppet/latest/puppet_strings_style.html)

If you aren't ready to use Strings yet, manually create a REFERENCE.md in the root of your module directory and list out each of your module's classes, defined types, facts, functions, Puppet tasks, task plans, and resource types and providers, along with the parameters for each.

For each element (class, defined type, function, and so on), list:

  * The data type, if applicable.
  * A description of what the element does.
  * Valid values, if the data type doesn't make it obvious.
  * Default value, if any.

For example:

```
### `pet::cat`

#### Parameters

##### `meow`

Enables vocalization in your cat. Valid options: 'string'.

Default: 'medium-loud'.
```

## Limitations

In the Limitations section, list any incompatibilities, known issues, or other warnings.

## Development

In the Development section, tell other users the ground rules for contributing to your project and how they should submit their work.

## Release Notes/Contributors/Etc. **Optional**

If you aren't using changelog, put your release notes here (though you should consider using changelog). You can also add any additional sections you feel are necessary or important to include here. Please use the `## ` header.
