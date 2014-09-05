require "iqeo/local/version"

require 'socket'
require 'ostruct'

module Iqeo
module Local

  class IPinfo

    def initialize
      hostname
      interfaces
      addresses
      nmcli
    end

    def hostname
      @hostname ||= Socket.gethostname
    end

    def interfaces
      @interfaces ||= Socket.getifaddrs.select do |intf|
        intf.addr.ipv4? && ! intf.addr.ipv4_loopback?
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
      # Iface	Destination	Gateway 	Flags	RefCnt	Use	Metric	Mask		MTU	Window	IRTT                                                       
      # eth0	00000000	0100010A	0003	0	0	0	00000000	0	0	0                                                                               
      # eth0	0000010A	00000000	0001	0	0	1	0000FFFF	0	0	0                                                                               
      File.read '/proc/net/route'
    end

    def arp
      # IP address       HW type     Flags       HW address            Mask     Device
      # 10.1.12.9        0x1         0x2         00:50:56:a4:62:84     *        eth0
      # 10.1.2.30        0x1         0x2         00:0f:20:d0:1c:32     *        eth0
      # 10.1.2.154       0x1         0x2         00:0b:cd:37:55:87     *        eth0
      # 10.1.0.1         0x1         0x2         64:00:f1:b4:39:00     *        eth0
      # 10.1.1.21        0x1         0x2         00:11:5d:5a:94:00     *        eth0
      # 10.1.12.8        0x1         0x0         00:50:56:a4:62:83     *        eth0
      # 10.1.0.9         0x1         0x2         00:25:84:57:e4:7e     *        eth0
      File.read '/proc/net/arp'
    end

    def nmcli
      # GENERAL.DEVICE:                         eth0
      # GENERAL.TYPE:                           802-3-ethernet
      # GENERAL.VENDOR:                         Realtek Semiconductor Co., Ltd.
      # GENERAL.PRODUCT:                        RTL8111/8168 PCI Express Gigabit Ethernet controller
      # GENERAL.DRIVER:                         r8169
      # GENERAL.DRIVER-VERSION:                 2.3LK-NAPI
      # GENERAL.FIRMWARE-VERSION:               
      # GENERAL.HWADDR:                         78:24:AF:18:87:93
      # GENERAL.STATE:                          100 (connected)
      # GENERAL.REASON:                         0 (No reason given)
      # GENERAL.UDI:                            /sys/devices/pci0000:00/0000:00:1c.3/0000:05:00.0/net/eth0
      # GENERAL.IP-IFACE:                       eth0
      # GENERAL.NM-MANAGED:                     yes
      # GENERAL.AUTOCONNECT:                    yes
      # GENERAL.FIRMWARE-MISSING:               no
      # GENERAL.CONNECTION:                     /org/freedesktop/NetworkManager/ActiveConnection/1
      # CAPABILITIES.CARRIER-DETECT:            yes
      # CAPABILITIES.SPEED:                     100 Mb/s
      # CONNECTIONS.AVAILABLE-CONNECTION-PATHS: /org/freedesktop/NetworkManager/Settings/{2,8}
      # CONNECTIONS.AVAILABLE-CONNECTIONS[1]:   c3f70065-7d32-457d-9314-3e54ff0a59e5 | Cabot external
      # CONNECTIONS.AVAILABLE-CONNECTIONS[2]:   e80c29a3-a1d8-48e4-b9f0-78712e46988b | Wired DHCP
      # WIRED-PROPERTIES.CARRIER:               on
      # IP4.ADDRESS[1]:                         ip = 10.1.6.222/16, gw = 10.1.0.1
      # IP4.DNS[1]:                             10.1.2.30
      # IP4.DNS[2]:                             10.1.2.154
      # IP4.DOMAIN[1]:                          jjill.com
      # IP4.WINS[1]:                            10.1.2.30
      # IP4.WINS[2]:                            10.3.2.4
      # DHCP4.OPTION[1]:                        domain_name = jjill.com
      # DHCP4.OPTION[2]:                        expiry = 1410452394
      # DHCP4.OPTION[3]:                        broadcast_address = 10.1.255.255
      # DHCP4.OPTION[4]:                        dhcp_message_type = 5
      # DHCP4.OPTION[5]:                        dhcp_lease_time = 604800
      # DHCP4.OPTION[6]:                        ip_address = 10.1.6.222
      # DHCP4.OPTION[7]:                        subnet_mask = 255.255.0.0
      # DHCP4.OPTION[8]:                        dhcp_renewal_time = 302400
      # DHCP4.OPTION[9]:                        routers = 10.1.0.1
      # DHCP4.OPTION[10]:                       dhcp_rebinding_time = 529200
      # DHCP4.OPTION[11]:                       domain_name_servers = 10.1.2.30 10.1.2.154
      # DHCP4.OPTION[12]:                       netbios_name_servers = 10.1.2.30 10.3.2.4
      # DHCP4.OPTION[13]:                       ntp_servers = 10.1.2.30 10.3.2.4 10.1.2.30 10.3.2.4
      # DHCP4.OPTION[14]:                       network_number = 10.1.0.0
      # DHCP4.OPTION[15]:                       dhcp_server_identifier = 10.1.2.30
      @nmcli = interfaces.collect do |intf|
        cmd = "nmcli dev list iface #{intf.name}"
        begin
          { intf.name => `#{cmd}`.lines.collect(&:chomp) }
        rescue
          raise
        end
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

  end

end
end
