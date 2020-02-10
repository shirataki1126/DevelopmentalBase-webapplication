$SwitchName = "VagrantSwitch"

# Create new virtual switch
New-VMSwitch -SwitchName "${SwitchName}" -SwitchType Internal
# Configure IPv4 address at local computer
New-NetIPAddress -InterfaceAlias "vEthernet (${SwitchName})" -IPAddress 172.18.200.254 -PrefixLength 24
# Create NAT for translating to an external network address
New-NetNat -Name "${SwitchName}WinNAT" -InternalIPInterfaceAddressPrefix 172.18.200.0/24
