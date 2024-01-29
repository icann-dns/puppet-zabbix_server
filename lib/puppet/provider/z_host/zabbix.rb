require 'json'

# check out the following blog serious for info on greating type/providers
# http://garylarizza.com/blog/2013/12/15/seriously-what-is-this-provider-doing/
Puppet::Type.type(:z_host).provide(:zabbix) do
  commands zabbix_host: '/usr/local/bin/zabbix_host.py'
  defaultfor kernel: 'Linux'
  # create getters and setters
  mk_resource_methods

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  # like self.instances for `puppet apply/puppet agent`
  # argument is a hash of all managed resources
  def self.prefetch(resources)
    instances.each do |prov|
      # read the blog post refrenced above from the bit the title
      # "What the actual fuck?!" to understand this bit
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov
      end
    end
  end

  # Get all the current values i.e. `puppet resource nexpose_host`
  def self.instances
    JSON.parse(zabbix_host('--exists')).map do |host|
      # Puppet.debug("collecting #{host['host']}")
      result = { ensure: :present }
      result[:name] = host['host']
      result[:operational] = 'true'
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

  def templateids=(value)
    @property_flush[:templateids] = value
  end

  def flush
    @groupids =  @property_flush.key?(:groupids) ? @property_flush[:groupids] : @resource[:groupids]
    @templateids =  @property_flush.key?(:templateids) ? @property_flush[:templateids] : @resource[:templateids]
    if @property_flush[:ensure] == :absent
      zabbix_host('--delete', '--node', @resource[:name])
    else
      zabbix_host('-t', @templateids.join(','), '-g', @groupids.join(','), '--node', @resource[:name])
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
