#! /bin/bash
BASEDN='dc=cigmall,dc=com'
SERVER='ops.cigmall.com'
CADIR= '/etc/openldap/cacerts'

# 安装openldap， sssd
yum -y install openldap-clients openldap sssd sssd-common sssd-ldap sssd-proxy python-sssdconfig authconfig

# authconfig 自动生成配置文件
authconfig \
--enablesssd \
--enablesssdauth \
--enablelocauthorize \
--enableldap \
--enableldapauth \
--ldapserver=ldaps://$SERVER:636 \
--disableldaptls \
--ldapbasedn=$BASEDN \
--enablerfc2307bis \
--enablemkhomedir \
--enablecachecreds \
--update

#wget 下载证书
wget -O $CADIR/ldap.ca http://$SERVER/CA 

# 修改sssd配置文件
cat > /etc/sssd/sssd.conf << EOF
[domain/default]
enumerate=True
autofs_provider = ldap
ldap_schema = rfc2307bis
ldap_search_base = $BASEDN
id_provider = ldap
auth_provider = ldap
chpass_provider = ldap
ldap_uri = ldaps://$SERVER:636
ldap_id_use_start_tls = True
cache_credentials = True
ldap_tls_cacertdir = $CADIR
ldap_tls_cacert = $CADIR/ldap.ca
[sssd]
services = nss, pam, autofs
config_file_version = 2
domains = default
[nss]
homedir_substring = /home
[pam]
[sudo]
[autofs]
[ssh]
EOF

/etc/init.d/sssd restart
