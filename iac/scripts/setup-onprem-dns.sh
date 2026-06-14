#!/bin/bash
set -e

apt-get clean
apt-get update -y || apt-get update -y
apt-get install -y software-properties-common
add-apt-repository -y universe
apt-get update -y || apt-get update -y
apt-get install -y bind9 bind9utils dnsutils curl

MYIP=$(hostname -I | awk '{print $1}')

cat > /etc/bind/named.conf.options << EOF
options {
    directory "/var/cache/bind";
    listen-on { any; };
    allow-query { any; };
    forwarders { 168.63.129.16; };
    forward only;
    dnssec-validation no;
};
EOF

mkdir -p /etc/bind/zones

cat > /etc/bind/named.conf.local << EOF
zone "onprem.iac-labs" {
    type master;
    file "/etc/bind/zones/db.onprem.iac-labs";
};
EOF

cat > /etc/bind/zones/db.onprem.iac-labs << EOF
\$TTL 300
@ IN SOA ns1.onprem.iac-labs. admin.onprem.iac-labs. (
    1       ; Serial
    300     ; Refresh
    300     ; Retry
    1200    ; Expire
    300     ; Minimum TTL
)
@ IN NS ns1.onprem.iac-labs.
ns1 IN A ${MYIP}
app IN A ${MYIP}
db  IN A 10.0.0.10
EOF

systemctl enable --now named
systemctl restart named
