require 'json'
Puppet::Type.type(:zabbix_host).provide(:zabbix) do
  commands zabbix_host: '/usr/local/bin/zabbix_host.py'
  defaultfor kernel: 'Linux'
  mk_resource_methods

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  def self.instances
    JSON.parse(zabbix_host('--exists')).map do |host|
      # Puppet.debug("collecting #{host['host']}")
      result = { ensure: :present }
      result[:name] = host['host']
      result[:operational] = (host['status'] == '0') ? 'true' : 'false'
      result[:templateids] = []
      result[:groupids] = []
      host['parentTemplates'].each do |template|
        result[:templateids].push(template['templateid'])
      end
      host['groups'].each do |group|
        result[:groupids].push(group['groupid'])
      end
      new(result)
    end
  end

  def groupids=(value)
    @property_flush[:groupids] = value
  end

  def operational=(value)
    @property_flush[:operational] = value
  end

  def templateids=(value)
    @property_flush[:templateids] = value
  end

  def flush
    @groupids =  @property_flush.key?(:groupids) ? @property_flush[:groupids] : @resource[:groupids]
    @templateids =  @property_flush.key?(:templateids) ? @property_flush[:templateids] : @resource[:templateids]
    @operational =  @property_flush.key?(:operational) ? @property_flush[:operational] : @resource[:operational]
    if @property_flush[:ensure] == :absent
      zabbix_host('--delete', '--node', @resource[:name])
    else
      zabbix_host('-t', @templateids.join(','), '-g', @groupids.join(','),
                  '--operational', @operational, '--node', @resource[:name])
    end
  end

  def create
    @property_flush[:ensure] = :present
  end

  def destroy
    @property_flush[:ensure] = :absent
  end

  def exists?
    @property_hash[:ensure] == :present
  end
end
