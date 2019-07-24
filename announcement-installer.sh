#!/bin/bash

# Copyright (C) 2016-2018  Barry de Graaff
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see http://www.gnu.org/licenses/.

set -e
# if you want to trace your script uncomment the following line
# set -x

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

echo ""
echo ""
echo "This script will install the Announcements Portal"
echo "IMPORTANT: "
echo "If you already installed the Announcements Portal before, "
echo "re-running this script will remove existing Announcements data "
echo "(any key to continue or CTRL+C to abort)"
echo ""
echo ""
read DUMMY;

mkdir -p /opt/zimbra/lib/ext/Announcements
wget --no-cache https://github.com/Zimbra-Community/announcements/raw/master/extension/Announcements/out/artifacts/Announcements_jar/Announcements.jar -O /opt/zimbra/lib/ext/Announcements/Announcements.jar

ANNOUNCEMENTS_PWD=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-10};echo;)

#here one could optionally support mysql by using jdbc:mysql://, ssl is disabled as this is a local connection
echo "db_connect_string=jdbc:mariadb://127.0.0.1:7306/announcements_db?user=ad-announcements_db&password=$ANNOUNCEMENTS_PWD" > /opt/zimbra/lib/ext/Announcements/db.properties

# creating a user, just to make sure we have one (for mysql on CentOS 6, so we can execute the next mysql queries w/o errors)
ANNOUNCEMENTS_DBCREATE="$(mktemp /tmp/announcements-dbcreate.XXXXXXXX.sql)"
cat <<EOF > "${ANNOUNCEMENTS_DBCREATE}"
CREATE DATABASE announcements_db CHARACTER SET 'UTF8'; 
CREATE USER 'ad-announcements_db'@'127.0.0.1' IDENTIFIED BY '${ANNOUNCEMENTS_PWD}'; 
GRANT ALL PRIVILEGES ON announcements_db . * TO 'ad-announcements_db'@'127.0.0.1' WITH GRANT OPTION; 
FLUSH PRIVILEGES ; 
EOF

/opt/zimbra/bin/mysql --force < "${ANNOUNCEMENTS_DBCREATE}" > /dev/null 2>&1

cat <<EOF > "${ANNOUNCEMENTS_DBCREATE}"
DROP USER 'ad-announcements_db'@'127.0.0.1';
DROP DATABASE announcements_db;
CREATE DATABASE announcements_db CHARACTER SET 'UTF8'; 
CREATE USER 'ad-announcements_db'@'127.0.0.1' IDENTIFIED BY '${ANNOUNCEMENTS_PWD}'; 
GRANT ALL PRIVILEGES ON announcements_db . * TO 'ad-announcements_db'@'127.0.0.1' WITH GRANT OPTION; 
FLUSH PRIVILEGES ; 
EOF

echo "Creating database and user"
/opt/zimbra/bin/mysql < "${ANNOUNCEMENTS_DBCREATE}"

echo "Populating announcements_db please wait..."
wget --no-cache https://raw.githubusercontent.com/Zimbra-Community/announcements/master/AnnouncementsEntry.sql -O /root/AnnouncementsEntry.sql
/opt/zimbra/bin/mysql announcements_db < /root/AnnouncementsEntry.sql

echo "Installing Zimlet"
wget --no-cache https://github.com/Zimbra-Community/announcements/releases/download/0.0.4/tk_barrydegraaff_announcements.zip -O /tmp/tk_barrydegraaff_announcements.zip
su - zimbra -c "zmzimletctl deploy /tmp/tk_barrydegraaff_announcements.zip"

echo "Install Portal Manifest"
mkdir -p /opt/zimbra/jetty/webapps/zimbra/portals/tk_barrydegraaff_announcements
wget --no-cache https://raw.githubusercontent.com/Zimbra-Community/announcements/master/manifest.xml -O /opt/zimbra/jetty/webapps/zimbra/portals/tk_barrydegraaff_announcements/manifest.xml

echo "Install 8.8.15 Proxy extension"
mkdir -p /opt/zimbra/lib/ext/proxy/
wget --no-cache https://github.com/Zimbra-Community/proxy/raw/master/extension/out/artifacts/extension_jar/extension.jar -O /opt/zimbra/lib/ext/proxy/extension.jar

echo "Install daily backup via /etc/cron.daily in /announcements-backup"
cat <<EOF > /etc/cron.daily/announcements-backup
#!/bin/bash
mkdir -p /announcements-backup
rm /announcements-backup/announcements-`date +%w`.sql
/opt/zimbra/common/bin/mysqldump -h 127.0.0.1 -P7306 -u'ad-announcements_db' -p'${ANNOUNCEMENTS_PWD}' --add-drop-table announcements_db > /announcements-backup/announcements-`date +%w`.sql
EOF
chmod +rx /etc/cron.daily/announcements-backup

echo "--------------------------------------------------------------------------------------------------------------"
echo "You still need to restart some services to load the changes:"
echo "su - zimbra -c \"zmmailboxdctl restart\""
echo "Enable the portal for a COS:"
echo "zmprov mc default zimbraFeaturePortalEnabled TRUE"
echo "zmprov mc default zimbraPortalName tk_barrydegraaff_announcements"
echo "Alternatively you can enable it per user: zmprov ma admin@myzimbra.com zimbraFeaturePortalEnabled TRUE"
echo ""
echo "Configure your feeds and allow Zimbra to fetch them:"
echo "zmprov mc default +zimbraProxyAllowedDomains zimbra.com"
echo "zmprov mc default +zimbraProxyAllowedDomains nextcloud.com"
echo "See:"
echo "zmzimletctl getConfigTemplate /opt/zimbra/zimlets-deployed/tk_barrydegraaff_announcements > /tmp/config_template.xml.tmp"
echo "nano /tmp/config_template.xml.tmp"
echo "zmzimletctl configure /tmp/config_template.xml.tmp"
echo ""
echo "WARNING: Announcements database is dropped on Zimbra upgrades!"
echo "See: /etc/cron.daily/announcements-backup"
