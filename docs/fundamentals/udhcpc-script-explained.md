# udhcpc DHCP Script Notes

## Events

### bound
Triggered when a DHCP lease is obtained.

### renew
Triggered when an existing lease is renewed.

### deconfig
Triggered when the lease is lost or interface is reset.

## Variables

- $interface
- $ip
- $subnet
- $router

## Route Configuration

if [ -n "$router" ]; then
    route add default gw $router dev $interface
fi
