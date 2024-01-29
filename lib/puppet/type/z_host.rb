require 'English'
Puppet::Type.newtype(:z_host) do
  @doc = 'This type provides the capability to manage hosts in zabbix'

  ensurable

  newparam(:host, namevar: true) do
    desc 'the FQFN'
    newvalues(%r{[\w\-\.]+})
  end

  newproperty(:groupids, array_matching: :all) do
    desc 'groups ids this host is a member of'
    newvalues(%r{\d+})
    def insync?(is)
      is.sort == should.sort
    end
  end

  newproperty(:templateids, array_matching: :all) do
    desc 'groups ids this host is a member of'
    newvalues(%r{\d+})
    def insync?(is)
      is.sort == should.sort
    end
  end

  # TODO: This property is now a no op and will be removed in future release
  # We also munge everything to true
  newproperty(:operational, boolean: true) do
    desc 'whether to monitor the host'
    newvalue(:true)
    newvalue(:false)
    munge do |value|
      :true
    end
  end

  # Borrowed from ipaddress library
  def valid_v4?(addr)
    if %r{^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$} =~ addr
      return $LAST_MATCH_INFO.captures.all? do |i|
        i = i.to_i
        i >= 0 && i <= 255
      end
    end
    false
  end

  def valid_ipv6?(addr)
    # IPv6 (normal)
    return true if %r{\A[\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*\Z} =~ addr
    return true if %r{\A[\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*::([\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*)?\Z} =~ addr
    return true if %r{\A::([\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*)?\Z} =~ addr
    # IPv6 (IPv4 compat)
    return true if %r{\A[\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*:} =~ addr && valid_ipv4?($')
    return true if %r{\A[\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*::([\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*:)?} =~ addr && valid_ipv4?($')
    return true if %r{\A::([\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*:)?} =~ addr && valid_ipv4?($')
    false
  end
end
