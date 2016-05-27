#! /bin/bash

LDAPDIR='/etc/openldap/'
LDAPDATADIR='/var/lib/ldap/'
LDAPCA="$LDAPDIR/certs/"
RUNUSER='ldap'
DC='dc=cigmall,dc=com'
ROOTDN='cn=Manager,dc=cigmall,dc=com'
ROOTPW=
#CA dir don't change!!! unless you know your do what
CA='/etc/pki/tls/misc/CA'
CADIR='/etc/pki/CA/'

#安装ldap, ssl rpm

function createssl(){
	rm -rf CADIR
        $CA -newca
	cd $LDAPDIR/certs && openssl req -newkey rsa:1024 -nodes -keyout newreq.pem -out newreq.pem
	$CA -sign 
	cp ${CADIR}/cacert.pem	$LDAPCA/ldap.ca
	cp newcert.pem	$LDAPCA/ldap.crt
	cp newreq.pem	$LDAPCA/ldap.key
	chmod 400 $LDAPCA
	chown ${RUNUSER}.${RUNUSER} $LDAPCA
}

function defschema(){
	sudorpm=`rpm -qa | grep sudo`
	sudoldap=`rpm -ql $sudorpm | grep -i schema | grep -i ldap`
	if [ ! -f "$sudoldap" ]
	then
	        echo 'sudo rpm not include sudo schema'
		exit 1
	fi
	/bin/cp -rf $sudoldap $LDAPDIR/schema/sudo.schema
	cat > $LDAPDIR/schema/publickey.schema << EOF
attributetype ( 1.3.6.1.4.1.24552.500.1.1.1.13 NAME 'sshPublicKey' 
        DESC 'MANDATORY: OpenSSH Public key' 
        EQUALITY octetStringMatch
        SYNTAX 1.3.6.1.4.1.1466.115.121.1.40 )
objectclass ( 1.3.6.1.4.1.24552.500.1.1.2.0 NAME 'ldapPublicKey' SUP top AUXILIARY
        DESC 'MANDATORY: OpenSSH LPK objectclass'
        MAY ( sshPublicKey $ uid ) 
        )
EOF
}
function main(){
slappasswd > /tmp/pass
ROOTPW=`cat /tmp/pass`
rm -rf /tmp/pass
dbconfig=`rpm -ql openldap-servers | grep DB_CONFIG`
cp $dbconfig $LDAPDATADIR/DB_CONFIG
chown ldap.ldap $LDAPDATADIR 
cp $LDAPDIR/slapd.conf $LDAPDIR/slapd.conf.ini
cat > $LDAPDIR/slapd.conf << EOF
include		$LDAPDIR/schema/corba.schema
include		$LDAPDIR/schema/core.schema
include		$LDAPDIR/schema/cosine.schema
include		$LDAPDIR/schema/duaconf.schema
include		$LDAPDIR/schema/dyngroup.schema
include		$LDAPDIR/schema/inetorgperson.schema
include		$LDAPDIR/schema/java.schema
include		$LDAPDIR/schema/misc.schema
include		$LDAPDIR/schema/nis.schema
include		$LDAPDIR/schema/openldap.schema
include		$LDAPDIR/schema/ppolicy.schema
include		$LDAPDIR/schema/collective.schema
include 	$LDAPDIR/schema/sudo.schema
include 	$LDAPDIR/schema/publickey.schema
allow bind_v2
loglevel        4
pidfile		/var/run/openldap/slapd.pid
argsfile	/var/run/openldap/slapd.args
TLSCACertificateFile $LDAPDIR/certs/ldap.ca
TLSCertificateFile $LDAPDIR/certs/ldap.crt
TLSCertificateKeyFile $LDAPDIR/certs/ldap.key
TLSVerifyClient never
database config
access to *
	by dn.exact="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage
        by dn.exact="${ROOTDN}" manage
	by * none
database monitor
access to *
	by dn.exact="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" read
	by anonymous search
	by * none
database	bdb
#suffix		"dc=cigmall,dc=com"
suffix		"$DC"
checkpoint	1024 15
#rootdn		"cn=Manager,dc=cigmall,dc=com"
rootdn		"$ROOTDN"
#rootpw	{MD5}Y6nw6nu5gFB5a2SehUgYRQ==
rootpw          $ROOTPW
#directory	/var/lib/ldap
directory	$LDAPDATADIR
index objectClass                       eq,pres
index ou,cn,mail,surname,givenname      eq,pres,sub
index uidNumber,gidNumber,loginShell    eq,pres
index uid,memberUid                     eq,pres,sub
index nisMapName,nisMapEntry            eq,pres,sub
index sudoUser				eq	
EOF
/bin/rm -rf $LDAPDIR/slapd.d/*
slaptest -f $LDAPDIR/slapd.conf -F $LDAPDIR/slapd.d/
slapd -d127 -h "ldap:/// ldaps:///"
}

yum -y install openldap-servers openldap-clients openldap openssl && createssl && defschema && main



