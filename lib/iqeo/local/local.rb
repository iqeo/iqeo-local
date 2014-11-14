
require 'socket'
require 'json'

module Iqeo
module Local

  class NetInfo

    attr_reader :hostname, :interfaces, :addresses, :routes, :arp, :nmcli, :dns, :dhcp

    def initialize
      collect
    end

    def collect
      hostname ; interfaces ; addresses ; routes ; arp ; nmcli ; dns ; dhcp
    end

    def all
      { hostname: @hostname, interfaces: @interfaces, addresses: @addresses, routes: @routes, arp: @arp, dns: @dns, dhcp: @dhcp }
    end

    def to_json
      all.to_json
    end

    def pretty_json
      all.to_json( indent: '  ', space: ' ', array_nl: "\n", object_nl: "\n" )
    end

    def hostname
      @hostname ||= Socket.gethostname
    end

    def interfaces
      # todo: also get interface info...  hardware type ?  speed/duplex ?  statistics ?
      # ...Socket.constants.grep(/IFF_/).select { |iff| i.flags & Socket.const_get(iff) != 0 } 
      if defined? JRuby
        # jruby (only interfaces with IP addresses)...
        # nis = java.net.NetworkInterface.getNetworkInterfaces.collect { |ni| { :name => ni.name, :hwaddr => ni.hardware_address } }
        # ba = nis[0][:hwaddr]
        # ba.collect { |b| "%02x" % (b & 0xff) }.join(':')
        @interfaces ||= Socket.getifaddrs.collect do |ifa|
          {
            name:  ifa.name,
            mac:   case # jruby Addrinfo#to_sockaddr is not implemented
                   when match = ifa.inspect.match(/HWADDR=(?<mac>\h\h:\h\h:\h\h:\h\h:\h\h:\h\h)/) then match[:mac]
                   when ifa.name == 'lo' then '00:00:00:00:00:00'
                   end,  
            up:    nil,
            flags: nil
          }
        end.uniq
      else
        @interfaces ||= Socket.getifaddrs.collect do |ifa|
          # hardware interfaces only (no IP interfaces, get those in #addresses)
          unless ifa.addr.ip?
            {
              name:  ifa.name,
              mac:   ifa.addr.to_sockaddr[-6,6].each_byte.collect { |b| "%02x" % (b & 0xff) }.join(':'),
              up:    ifa.flags & 0x1 == 1 ? true : false,
              flags: ifa.flags
            }
          end
        end.compact
      end
    end

    def addresses
      if defined? JRuby
        @addresses ||= Socket.getifaddrs.collect do |ifa|
          begin
            ifa.addr.ip_address # raise SocketError if bogus Addrinfo without an IP address
            {
              interface: ifa.name,
              flags:     ifa.flags,
              address:   ifa.addr.ip_address,
              netmask:   ifa.netmask   ? ifa.netmask.ip_address   : nil,  # point-to-point - no netmask
              broadcast: ifa.broadaddr ? ifa.broadaddr.ip_address : nil,  # ipv6 - no broadcast
              type:      ifa.addr.ipv4? ? :ipv4 : :ipv6 
            }
          rescue SocketError
            nil
          end
        end.compact
      else
        @addresses ||= Socket.getifaddrs.collect do |ifa|
          if ifa.addr.ip?
            {
              interface: ifa.name,
              flags:     ifa.flags,
              address:   ifa.addr.ip_address,
              netmask:   ifa.netmask   ? ifa.netmask.ip_address   : nil,  # point-to-point - no netmask
              broadcast: ifa.broadaddr ? ifa.broadaddr.ip_address : nil,  # ipv6 - no broadcast
              type:      ifa.addr.ipv4? ? :ipv4 : :ipv6 
            }
          end
        end.compact
      end
    end

    def routes
      @routes ||= File.open( '/proc/net/route' ).collect do |line|
        next if line.start_with? 'Iface' # skip header
        values = line.split("\s")
        next if values[2] == '00000000'  # skip locally connected network
        {
          interface:   values[0],
          type:        :ipv4,
          destination: hex_to_ip(values[1]),
          netmask:     hex_to_ip(values[7]),
          gateway:     hex_to_ip(values[2])
        }
      end.compact
    end

    def arp
      @arp ||= File.open( '/proc/net/arp' ).collect do |line|
        next if line.start_with? 'IP' # skip header
        values = line.split("\s")
        {
          interface: values[5],
          type:      :ipv4,
          address:   values[0], 
          hwaddr:    values[3]
        }
      end.compact
    end

    def nmcli
      @nmcli ||= interfaces.collect do |intf|
        unless intf[:name] == 'lo'
          cmd = "nmcli dev list iface #{intf[:name]}"
          {
            interface: intf[:name],
            data:      `#{cmd}`.lines.collect(&:chomp) 
          }
        end
      end.compact
    end

    def dns
      @dns ||= nmcli.collect do |nmcli_intf|
        dns_lines = nmcli_intf[:data].select do |line|
          line.start_with? 'IP4.DNS['
        end
        unless dns_lines.empty?
          {
            interface: nmcli_intf[:interface], 
            type:      :ipv4,
            servers:   dns_lines.collect { |line| { address: line.split(":").last.strip } }
          }
        end
      end.compact
    end

    def dhcp
      @dhcp ||= nmcli.collect do |nmcli_intf|
        dhcp_lines = nmcli_intf[:data].select do |line|
          line.start_with? 'DHCP4.OPTION['
        end
        unless dhcp_lines.empty?
          {
            interface: nmcli_intf[:interface],
            type:      :ipv4,
            options:   Hash[ dhcp_lines.collect { |line| line.split(":").last.split("=").collect(&:strip) } ] 
          }
        end
      end.compact
    end

    private 

    def hex_to_ip hex
      [hex].pack("H*").unpack("C*").reverse.join(".")
    end

  end

end
end
