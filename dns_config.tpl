#!/bin/bash

set -x
exec > /var/log/dns-install.log 2>&1


# loop installation as there is sometimes a race condition
while [ ! -e /lib/systemd/system/named.service ]; do
    apt -y update
    apt -y install bind9 dnsutils systemd-timesyncd
    apt -y upgrade
done

# Create DNS config bootstratp configuration file
cat > /etc/bind/named.conf.options <<EOF
options {
        querylog yes;
        directory "/var/cache/bind";
        recursion yes;
        listen-on { any; };
        allow-query {
                any;
        };
          allow-query-cache {
                any;
        };
         allow-recursion {
                any;
         };
        forwarders {
          168.63.129.16;
        };
        dnssec-validation no;
      };
logging {
        channel named           { file "/var/log/named/named.log"        versions 10 size 20M; severity info;  print-time yes; print-category yes; print-severity yes; };
        channel security        { file "/var/log/named/security.log"     versions 10 size 20M; severity info;  print-time yes; print-severity yes; };
        channel dnssec          { file "/var/log/named/dnssec.log"       versions 10 size 20M; severity info;  print-time yes; print-severity yes; };
        channel resolver        { file "/var/log/named/resolver.log"     versions 10 size 20M; severity info;  print-time yes; print-severity yes; };
        channel query_log       { file "/var/log/named/query.log"        versions 10 size 80M; severity debug; print-time yes; print-severity yes; };
        channel query-error     { file "/var/log/named/query-errors.log" versions 10 size 20M; severity info;  print-time yes; print-severity yes; };
        channel lame_servers    { file "/var/log/named/lame-servers.log" versions 10 size 20M; severity info;  print-time yes; print-severity yes; };
        channel capacity        { file "/var/log/named/capacity.log"     versions 10 size 20M; severity info;  print-time yes; print-severity yes; };
        channel rpz             { file "/var/log/named/rpz.log"          versions 10 size 20M; severity info;  print-time yes; print-severity yes; };

        category default        { default_syslog;  named; };
        category general        { default_syslog;  named; };
        category security       { security; };
        category queries        { default_syslog; query_log; };
        category lame-servers   { lame_servers;};
        category dnssec         { dnssec; };
        category edns-disabled  { default_syslog; };
        category config         { default_syslog; named; };
        category resolver       { resolver; };
        category edns-disabled  { resolver; };
        category cname          { resolver; };
        category spill          { capacity; };
        category rate-limit     { capacity; };
        category database       { capacity; };
        category client         { default_syslog; named; };
        category network        { default_syslog; named; };
        category unmatched      { named; };
        category client         { named; };
        category network        { named; };
        category delegation-only { named;};
        category dispatch       { named; };
        category rpz            { rpz;};
      };
EOF

# Creates TFE frontend settings file
cat > /etc/bind/named.conf.local <<EOF
zone "gglabs.co.uk" {
      type forward;
      forward only;
      forwarders {
        ${dns1};
        ${dns2};
        };
      };
      zone "10.in-addr.arpa" {
      type forward;
      forward only;
      forwarders {
        ${dns1};
        ${dns2};
        };
      };
      zone "${reverse_dns_cidr}.in-addr.arpa" {
      type master;
      file "/etc/bind/db.reverse";
      };
EOF

### reverse DNS
cp /etc/bind/db.0 /etc/bind/db.reverse
echo "${lb_ip}   IN      PTR     ${vm_prefix}.gglabs.co.uk." >> /etc/bind/db.reverse

#### syslog
echo "*.* @${syslog_server}:514" >> /etc/rsyslog.d/50-default.conf

#### NTP
echo "NTP=${dns1}" >> /etc/systemd/timesyncd.conf
echo "FallbackNTP=${dns2}" >> /etc/systemd/timesyncd.conf


mkdir /var/log/named
chown bind:bind /var/log/named
systemctl unmask systemd-timesyncd.service
systemctl enable systemd-timesyncd.service
systemctl restart systemd-timesyncd
systemctl restart bind9.service
systemctl restart rsyslog.service

echo "## Setup complete"
