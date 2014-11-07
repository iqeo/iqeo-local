#require "iqeo/local/version"

require 'socket'
require 'ostruct'

module Iqeo
module Local

  class IPinfo

    def initialize
      hostname
      interfaces
      addresses
      routes
      arp
      nmcli
      dns
      # dhcp
    end

    def hostname
      @hostname ||= Socket.gethostname
    end

    def interfaces
      @interfaces ||= Socket.getifaddrs.select do |intf|
        if intf.addr.ipv4? && ! intf.addr.ipv4_loopback?
          begin
            # jruby-head returns bogus addrinfo objects sometimes, test it really has an ip address
            intf.addr.ip_address
            true
          rescue SocketError
            false
          end
        end
      end
    end
   
    def addresses
      @addresses ||= interfaces.collect do |intf|
        OpenStruct.new(
          {
            name:      intf.name,
            address:   intf.addr.ip_address,
            netmask:   intf.netmask.ip_address,
            broadcast: intf.broadaddr.ip_address,
            hwaddr:    interface_hwaddr(intf.name)
          }
        )
      end
    end

    def routes
      @routes ||= File.open( '/proc/net/route' ).collect do |line|
        next if line.start_with? 'Iface' # skip header
        values = line.split("\s")
        next if values[2] == '00000000'  # skip local network
        OpenStruct.new(
          {
            interface:   values[0],
            destination: hex_to_ip(values[1]),
            netmask:     hex_to_ip(values[7]),
            gateway:     hex_to_ip(values[2])
          }
        )
      end.compact
    end

    def arp
      @arp ||= File.open( '/proc/net/arp' ).collect do |line|
        next if line.start_with? 'IP' # skip header
        values = line.split("\s")
        OpenStruct.new(
          {
            interface: values[5],
            address:   values[0], 
            hwaddr:    values[3]
          }
        )
      end.compact
    end

    def nmcli
      @nmcli ||= interfaces.collect do |intf|
        cmd = "nmcli dev list iface #{intf.name}"
        begin
          `#{cmd}`.lines.collect(&:chomp) 
        rescue
          raise
        end
      end
    end

    def dns
      @dns ||= nmcli.collect do |nmcli_intf|
        nmcli_intf.select do |line|
          line.start_with? 'IP4.DNS['
        end.collect do |line|
          line.split(":").last.strip
        end
      end.flatten
    end

    def dhcp
      @dhcp ||= nmcli.collect do |nmcli_intf|
        [
          nmcli_intf.name,
          Hash[
            nmcli_intf.select do |line|
              line.start_with? 'DHCP4.OPTION['
            end.collect do |line|
              line.split(":").last.split("=").collect(&:strip)
            end
          ]
        ]
      end
    end

    private 

    def interface_hwaddr intf_name
      Socket.getifaddrs.each do |intf|
        if intf.name == intf_name
          if match = intf.addr.inspect_sockaddr.match(/hwaddr=(?<hwaddr>(\h\h:){5}\h\h)/)
            return match[:hwaddr]
          end
        end
      end
    end

    def hex_to_ip hex
      [hex].pack("H*").unpack("C*").reverse.join(".")
    end

  end

end
end
