require 'spec_helper'

describe 'zabbix_server' do
  let(:node) { 'zabbix-server.example.com' }
  let(:params) do
    {
      # db_host: "localhost",
      # db_port: "3306",
      # db_name: "zabbix",
      # db_user: "zabbix",
      # db_password: "changeme",
      # php_timezone: "UTC",
      zabbix_host: "zabbix-server.example.com",
      # zabbix_port: "10051",
      # cache_size: "128M",
      # value_cache_size: "256M",
      # log_file: "/var/log/zabbix/zabbix-server.log",
      # pollers: "100",
      # pingers: "10",
      # pollers_unreachable: "25",
      # trappers: "25",
      # timeout: "3",
      # approot: "/srv/www",
      # api_user: "user",
      # api_password: "password",
      # admin_password: "zabbix",
      # default_group_ids: "2",
      # default_template_ids: "10001",
    }
  end

  # Puppet::Util::Log.level = :debug
  # Puppet::Util::Log.newdestination(:console)
  # This will need to get moved
  # it { pp catalogue.resources }
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }

      describe 'check default config' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_python__pip('pyzabbix').with_ensure('0.7.4') }
        it do
          is_expected.to contain_mysql__db('zabbix').with(
            user: 'zabbix',
            password: 'changeme',
            host: 'localhost',
            grant: ['all'],
            sql: '/usr/share/doc/zabbix-server-mysql/create.sql.gz',
            require: 'Package[zabbix-server-mysql]',
            import_cat_cmd: 'zcat',
          )
        end
        it do
          is_expected.to contain_ini_setting('zabbix_port').with(
            setting: 'ListenPort',
            value: '10051',
          )
        end
        it do
          is_expected.to contain_ini_setting('zabbix_db').with(
            setting: 'DBName',
            value: 'zabbix',
          )
        end
        it do
          is_expected.to contain_ini_setting('zabbix_dbhost').with(
            setting: 'DBHost',
            value: 'localhost',
          )
        end
        it do
          is_expected.to contain_ini_setting('zabbix_dbport').with(
            setting: 'DBPort',
            value: '3306',
          )
        end
        it do
          is_expected.to contain_ini_setting('zabbix_dbpassword').with(
            setting: 'DBPassword',
            value: 'changeme',
          )
        end
        it do
          is_expected.to contain_ini_setting('cache_size').with(
            setting: 'CacheSize',
            value: '128M',
          )
        end
        it do
          is_expected.to contain_ini_setting('value_cache_size').with(
            setting: 'ValueCacheSize',
            value: '256M',
          )
        end
        it do
          is_expected.to contain_ini_setting('log_file').with(
            setting: 'LogFile',
            value: '/var/log/zabbix/zabbix_server.log',
          )
        end
        it do
          is_expected.to contain_ini_setting('pollers').with(
            setting: 'StartPollers',
            value: '100',
          )
        end
        it do
          is_expected.to contain_ini_setting('pingers').with(
            setting: 'StartPingers',
            value: '10',
          )
        end
        it do
          is_expected.to contain_ini_setting('pollers_unreachable').with(
            setting: 'StartPollersUnreachable',
            value: '25',
          )
        end
        it do
          is_expected.to contain_ini_setting('trappers').with(
            setting: 'StartTrappers',
            value: '25',
          )
        end
        it do
          is_expected.to contain_ini_setting('timeout').with(
            setting: 'Timeout',
            value: '3',
          )
        end
        it do
          is_expected.to contain_sysctl('kernel.shmmax').with_value('268435456')
        end
        it do
          is_expected.to contain_service('zabbix-server').with(
            ensure: 'running',
            enable: true,
          )
        end
        it do
          is_expected.to contain_file('/usr/local/bin/zabbix_host.py').with(
            ensure: 'file',
            mode: '0500',
          ).with_content(
            %r{'--user', default='user'}
          ).with_content(
            %r{'--password', default='password'}
          ).with_content(
            %r{'--group-ids', default='2'}
          ).with_content(
            %r{'--template-ids', default='10001'}
          )
        end
        it do
          is_expected.to contain_file('/usr/local/bin/zabbix_reset.py').with(
            ensure: 'file',
            mode: '0550',
          ).with_content(
            %r{NEW_PASSWORD\s+=\s+'zabbix'}
          ).with_content(
            %r{API_USER\s+=\s+'user'}
          ).with_content(
            %r{API_PASSWORD\s+=\s+'password'}
          ).with_content(
            %r{ZABBIX_HOST\s+=\s+'http://zabbix-server.example.com'}
          )
        end
        it do
          is_expected.to contain_file('/etc/zabbix/apache.conf').with(
            ensure: 'file',
            require: 'Package[zabbix-frontend-php]',
            notify: 'Service[apache2]',
          ).with_content(
            %r{php_value date.timezone UTC}
          )
        end
        it do
          is_expected.to contain_file('/etc/zabbix/web/zabbix.conf.php').with(
            ensure: 'file',
            require: 'Package[zabbix-frontend-php]',
          ).with_content(
            %r{\$DB\['SERVER'\]\s+=\s+'localhost';}
          ).with_content(
            %r{\$DB\['PORT'\]\s+=\s+'3306';}
          ).with_content(
            %r{\$DB\['DATABASE'\]\s+=\s+'zabbix';}
          ).with_content(
            %r{\$DB\['USER'\]\s+=\s+'zabbix';}
          ).with_content(
            %r{\$DB\['PASSWORD'\]\s+=\s+'changeme';}
          ).with_content(
            %r{\$ZBX_SERVER\s+=\s+'zabbix-server.example.com';}
          ).with_content(
            %r{\$ZBX_SERVER_PORT\s+=\s+'10051';}
          ).with_content(
            %r{\$ZBX_SERVER_NAME\s+=\s+'zabbix-server.example.com';}
          )
        end
        it do
          is_expected.to contain_file('/etc/ldap/ldap.conf').with_ensure('present')
        end
        it do
          is_expected.to contain_file_line('Append to /etc/ldap/ldap.conf').with(
            path: '/etc/ldap/ldap.conf',
            line: 'TLS_REQCERT never',
          )
        end
        it do
          is_expected.to contain_apache__vhost(
            'zabbix-server.example.com non-ssl'
          ).with(
            servername: 'zabbix-server.example.com',
            docroot: '/srv/www/',
            port: '80',
            additional_includes: ['/etc/zabbix/apache.conf'],
          )
        end
        it do
          is_expected.to contain_apache__vhost('zabbix-server.example.com').with(
            servername: 'zabbix-server.example.com',
            docroot: '/srv/www/',
            port: '443',
            additional_includes: ['/etc/zabbix/apache.conf'],
            ssl: true,
            ssl_cert: '/etc/ssl/certs/wildcard.dns.icann.org.crt',
            ssl_key: '/etc/ssl/private/wildcard.dns.icann.org.key',
            ssl_chain: '/etc/ssl/certs/DigiCertCA.crt',
            ssl_protocol: 'all -SSLv2 -SSLv3',
          )
        end
        it do
          is_expected.to contain_exec('/usr/local/bin/zabbix_reset.py').with(
            command: '/usr/local/bin/zabbix_reset.py && touch /etc/zabbix/api_created',
            creates: '/etc/zabbix/api_created',
          )
        end
      end
      describe 'Change Defaults' do
        context 'db_host' do
          before(:each) { params.merge!(db_host: 'foo.bar') }
          it { is_expected.to compile }
          it { is_expected.to contain_mysql__db('zabbix').with_host('foo.bar') }
          it do
            is_expected.to contain_file(
              '/etc/zabbix/web/zabbix.conf.php'
            ).with_content(
              %r{\$DB\['SERVER'\]\s+=\s+'foo.bar';}
            )
          end
          it do
            is_expected.to contain_ini_setting('zabbix_dbhost').with(
              setting: 'DBHost',
              value: 'foo.bar',
            )
          end
        end
        context 'db_port' do
          before(:each) { params.merge!(db_port: 42) }
          it { is_expected.to compile }
          it do
            is_expected.to contain_file(
              '/etc/zabbix/web/zabbix.conf.php'
            ).with_content(
              %r{\$DB\['PORT'\]\s+=\s+'42';}
            )
          end
          it do
            is_expected.to contain_ini_setting('zabbix_dbport').with(
              setting: 'DBPort',
              value: '42',
            )
          end
        end
        context 'db_name' do
          before(:each) { params.merge!(db_name: 'foobar') }
          it { is_expected.to compile }
          it do
            is_expected.to contain_mysql__db('foobar').with(
              user: 'zabbix',
              password: 'changeme',
              host: 'localhost',
            )
          end
          it do
            is_expected.to contain_file(
              '/etc/zabbix/web/zabbix.conf.php'
            ).with_content(
              %r{\$DB\['DATABASE'\]\s+=\s+'foobar';}
            )
          end
          it do
            is_expected.to contain_ini_setting('zabbix_db').with(
              setting: 'DBName',
              value: 'foobar',
            )
          end
        end
        context 'db_user' do
          before(:each) { params.merge!(db_user: 'foobar') }
          it { is_expected.to compile }
          it { is_expected.to contain_mysql__db('zabbix').with_user('foobar') }
          it do
            is_expected.to contain_file(
              '/etc/zabbix/web/zabbix.conf.php'
            ).with_content(
              %r{\$DB\['USER'\]\s+=\s+'foobar';}
            )
          end
        end
        context 'db_password' do
          before(:each) { params.merge!(db_password: 'foobar') }
          it { is_expected.to compile }
          it do
            is_expected.to contain_mysql__db('zabbix').with_password('foobar')
          end
          it do
            is_expected.to contain_file(
              '/etc/zabbix/web/zabbix.conf.php'
            ).with_content(
              %r{\$DB\['PASSWORD'\]\s+=\s+'foobar';}
            )
          end
          it do
            is_expected.to contain_ini_setting('zabbix_dbpassword').with(
              setting: 'DBPassword',
              value: 'foobar',
            )
          end
        end
        context 'php_timezone' do
          before(:each) { params.merge!(php_timezone: 'Foo/Bar') }
          it { is_expected.to compile }
          it do
            is_expected.to contain_file('/etc/zabbix/apache.conf').with(
              ensure: 'file',
              require: 'Package[zabbix-frontend-php]',
              notify: 'Service[apache2]',
            ).with_content(
              %r{php_value date.timezone Foo/Bar}
            )
          end
        end
        context 'zabbix_host' do
          before(:each) { params.merge!(zabbix_host: 'foo.bar') }
          it { is_expected.to compile }
          it do
            is_expected.to contain_file(
              '/etc/zabbix/web/zabbix.conf.php'
            ).with_content(
              %r{\$ZBX_SERVER\s+=\s+'foo.bar';}
            )
          end
          it do
            is_expected.to contain_file(
              '/usr/local/bin/zabbix_reset.py'
            ).with_content(
              %r{ZABBIX_HOST\s+=\s+'http://foo.bar'}
            )
          end
        end
        context 'zabbix_port' do
          before(:each) { params.merge!(zabbix_port: 42) }
          it { is_expected.to compile }
          it do
            is_expected.to contain_file(
              '/etc/zabbix/web/zabbix.conf.php'
            ).with_content(
              %r{\$ZBX_SERVER_PORT\s+=\s+'42';}
            )
          end
        end
        context 'cache_size' do
          before(:each) { params.merge!(cache_size: '42M') }
          it { is_expected.to compile }
          it do
            is_expected.to contain_ini_setting('cache_size').with(
              setting: 'CacheSize',
              value: '42M',
            )
          end
        end
        context 'value_cache_size' do
          before(:each) { params.merge!(value_cache_size: '42M') }
          it { is_expected.to compile }
          it do
            is_expected.to contain_ini_setting('value_cache_size').with(
              setting: 'ValueCacheSize',
              value: '42M',
            )
          end
        end
        context 'log_file' do
          before(:each) { params.merge!(log_file: '/foo/bar') }
          it { is_expected.to compile }
          it do
            is_expected.to contain_ini_setting('log_file').with(
              setting: 'LogFile',
              value: '/foo/bar',
            )
          end
        end
        context 'pollers' do
          before(:each) { params.merge!(pollers: 42) }
          it { is_expected.to compile }
          it do
            is_expected.to contain_ini_setting('pollers').with(
              setting: 'StartPollers',
              value: 42,
            )
          end
        end
        context 'pingers' do
          before(:each) { params.merge!(pingers: 42) }
          it { is_expected.to compile }
          it do
            is_expected.to contain_ini_setting('pingers').with(
              setting: 'StartPingers',
              value: 42,
            )
          end
        end
        context 'pollers_unreachable' do
          before(:each) { params.merge!(pollers_unreachable: 42) }
          it { is_expected.to compile }
          it do
            is_expected.to contain_ini_setting('pollers_unreachable').with(
              setting: 'StartPollersUnreachable',
              value: 42,
            )
          end
        end
        context 'trappers' do
          before(:each) { params.merge!(trappers: 42) }
          it { is_expected.to compile }
          it do
            is_expected.to contain_ini_setting('trappers').with(
              setting: 'StartTrappers',
              value: 42,
            )
          end
        end
        context 'timeout' do
          before(:each) { params.merge!(timeout: 21) }
          it { is_expected.to compile }
          it do
            is_expected.to contain_ini_setting('timeout').with(
              setting: 'Timeout',
              value: 21,
            )
          end
        end
        context 'approot' do
          before(:each) { params.merge!(approot: '/foo/bar') }
          it { is_expected.to compile }
          it do
            is_expected.to contain_apache__vhost(
              'zabbix-server.example.com non-ssl'
            ).with_docroot('/foo/bar/')
          end
          it do
            is_expected.to contain_apache__vhost(
              'zabbix-server.example.com'
            ).with_docroot('/foo/bar/')
          end
        end
        context 'api_user' do
          before(:each) { params.merge!(api_user: 'foobar') }
          it { is_expected.to compile }
          it do
            is_expected.to contain_file(
              '/usr/local/bin/zabbix_host.py'
            ).with_content(
              %r{'--user', default='foobar'}
            )
          end
          it do
            is_expected.to contain_file(
              '/usr/local/bin/zabbix_reset.py'
            ).with_content(
              %r{API_USER\s+=\s+'foobar'}
            )
          end
        end
        context 'api_password' do
          before(:each) { params.merge!(api_password: 'foobar') }
          it { is_expected.to compile }
          it do
            is_expected.to contain_file(
              '/usr/local/bin/zabbix_host.py'
            ).with_content(
              %r{'--password', default='foobar'}
            )
          end
          it do
            is_expected.to contain_file(
              '/usr/local/bin/zabbix_reset.py'
            ).with_content(
              %r{API_PASSWORD\s+=\s+'foobar'}
            )
          end
        end
        context 'admin_password' do
          before(:each) { params.merge!(admin_password: 'foobar') }
          it { is_expected.to compile }
          it do
            is_expected.to contain_file(
              '/usr/local/bin/zabbix_reset.py'
            ).with_content(
              %r{NEW_PASSWORD\s+=\s+'foobar'}
            )
          end
        end
        context 'default_group_ids' do
          before(:each) { params.merge!(default_group_ids: 42) }
          it { is_expected.to compile }
          it do
            is_expected.to contain_file(
              '/usr/local/bin/zabbix_host.py'
            ).with_content(
              %r{'--group-ids', default='42'}
            )
          end
        end
        context 'default_template_ids' do
          before(:each) { params.merge!(default_template_ids: 42) }
          it { is_expected.to compile }
          it do
            is_expected.to contain_file(
              '/usr/local/bin/zabbix_host.py'
            ).with_content(
              %r{'--template-ids', default='42'}
            )
          end
        end
      end
      describe 'check bad type' do
        context 'db_host' do
          before(:each) { params.merge!(db_host: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'db_port' do
          before(:each) { params.merge!(db_port: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'db_name' do
          before(:each) { params.merge!(db_name: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'db_user' do
          before(:each) { params.merge!(db_user: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'db_password' do
          before(:each) { params.merge!(db_password: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'php_timezone' do
          before(:each) { params.merge!(php_timezone: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'zabbix_host' do
          before(:each) { params.merge!(zabbix_host: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'zabbix_port' do
          before(:each) { params.merge!(zabbix_port: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'cache_size' do
          before(:each) { params.merge!(cache_size: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'value_cache_size' do
          before(:each) { params.merge!(value_cache_size: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'log_file' do
          before(:each) { params.merge!(log_file: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'pollers' do
          before(:each) { params.merge!(pollers: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'pingers' do
          before(:each) { params.merge!(pingers: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'pollers_unreachable' do
          before(:each) { params.merge!(pollers_unreachable: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'trappers' do
          before(:each) { params.merge!(trappers: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'timeout' do
          before(:each) { params.merge!(timeout: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'approot' do
          before(:each) { params.merge!(approot: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'api_user' do
          before(:each) { params.merge!(api_user: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'api_password' do
          before(:each) { params.merge!(api_password: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'admin_password' do
          before(:each) { params.merge!(admin_password: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'default_group_ids' do
          before(:each) { params.merge!(default_group_ids: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'default_template_ids' do
          before(:each) { params.merge!(default_template_ids: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
      end
    end
  end
end
