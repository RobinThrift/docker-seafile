#!/bin/bash
set -e

if [ -z "$MYSQL_NAME" ]; then
  echo "MYSQL_NAME not set. Please make sure you linked a database container with the alias mysql!"
  exit 1
fi

if [ -z "$SEAFILE_MYSQL_PASSWORD" ]; then
  echo "SEAFILE_MYSQL_PASSWORD not set!"
  exit 1
fi

# Exports necessary for different scripts
export CCNET_CONF_DIR="$SEAFILE_CONFDIR"
export SEAFILE_CONF_DIR="$SEAFILE_CONFDIR"
export SEAFILE_CENTRAL_CONF_DIR="$SEAFILE_CONFDIR"
export LD_LIBRARY_PATH=$SEAFILE_INSTALLDIR/seafile/seafile/lib:$SEAFILE_APPDIR/seafile/seafile/lib64
export PYTHONPATH=$SEAFILE_INSTALLDIR/seafile/seafile/lib/python2.7/site-packages:$SEAFILE_INSTALLDIR/seafile/seafile/lib64/python2.7/site-packages:$SEAFILE_INSTALLDIR/seafile/seafile/lib/python2.6/site-packages:$SEAFILE_INSTALLDIR/seafile/seafile/lib64/python2.6/site-packages:$SEAFILE_INSTALLDIR/seafile/seahub:$SEAFILE_INSTALLDIR/seafile/seahub/thirdpart

SEAFILE_MYSQL_DB_NAMES=(ccnet-db seafile-db seahub-db)
: ${SEAFILE_MYSQL_USER:=seafile}
: ${SEAFILE_MYSQL_SETUP_USER:=root}
: ${SEAFILE_MYSQL_SETUP_PASSWORD:=$MYSQL_ENV_MYSQL_ROOT_PASSWORD}
: ${SEAFILE_INSTANCE_NAME:=Seafile}
: ${SEAFILE_FILESERVER_PORT:=8082}
: ${SEAFILE_DOMAIN:=127.0.0.1}

mysql=(mysql -hmysql -u$SEAFILE_MYSQL_SETUP_USER -p$SEAFILE_MYSQL_SETUP_PASSWORD)

for db in ${SEAFILE_MYSQL_DB_NAMES[@]}; do
    RESULT=$(${mysql[@]} --skip-column-names -B -e "SHOW DATABASES LIKE '${db}';")

    if [ "$RESULT" != $db ]; then
        ${mysql[@]} -e "CREATE DATABASE \`${db}\`;"
        ${mysql[@]} -e "GRANT ALL ON \`${db}\`.* TO '$SEAFILE_MYSQL_USER'@'%' IDENTIFIED BY '$SEAFILE_MYSQL_PASSWORD' WITH GRANT OPTION;"
    fi
done

RESULT=$(${mysql[@]} --skip-column-names -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '${SEAFILE_MYSQL_DB_NAMES[2]}';")
if [ "$RESULT" == "0" ]; then
    cat $SEAFILE_INSTALLDIR/seafile/seahub/sql/mysql.sql | ${mysql[@]} ${SEAFILE_MYSQL_DB_NAMES[2]}
fi

# Create ccnet.conf file if it doesn't exist yet
if [[ ! -f $SEAFILE_CONFDIR/ccnet.conf || ! -f $SEAFILE_CONFDIR/mykey.peer ]]; then
    $SEAFILE_INSTALLDIR/seafile/seafile/bin/ccnet-init -F $SEAFILE_CONFDIR --config-dir $SEAFILE_CONFDIR/tmp --name $SEAFILE_INSTANCE_NAME --host $SEAFILE_DOMAIN

    cat <<- EOF >> $SEAFILE_CONFDIR/ccnet.conf

[Database]
ENGINE = mysql
HOST = mysql
PORT = 3306
USER = ${SEAFILE_MYSQL_USER}
PASSWD = ${SEAFILE_MYSQL_PASSWORD}
DB = ${SEAFILE_MYSQL_DB_NAMES[0]}
CONNECTION_CHARSET = utf8
EOF

    mv $SEAFILE_CONFDIR/tmp/* $SEAFILE_CONFDIR
    rm -r $SEAFILE_CONFDIR/tmp/
fi

# Create seafile.ini file if it doesn't exist yet
if [ ! -f $SEAFILE_CONFDIR/seafile.ini ]; then
    cat <<- EOF > $SEAFILE_CONFDIR/seafile.ini
${SEAFILE_DATADIR}
EOF
fi

# Create seafile.conf file if it doesn't exist yet
if [ ! -f $SEAFILE_CONFDIR/seafile.conf ]; then
    $SEAFILE_INSTALLDIR/seafile/seafile/bin/seaf-server-init -F $SEAFILE_CONFDIR --seafile-dir $SEAFILE_DATADIR --fileserver-port $SEAFILE_FILESERVER_PORT

    cat <<- EOF >> $SEAFILE_CONFDIR/seafile.conf

[database]
type = mysql
host = mysql
port = 3306
user = ${SEAFILE_MYSQL_USER}
password = ${SEAFILE_MYSQL_PASSWORD}
db_name = ${SEAFILE_MYSQL_DB_NAMES[1]}
connection_charset = utf8
EOF
fi

# Create seafdav.conf file if it doesn't exist yet
if [ ! -f $SEAFILE_CONFDIR/seafdav.conf ]; then
    cat <<- EOF > $SEAFILE_CONFDIR/seafdav.conf
[WEBDAV]
enabled = false
port = 8080
fastcgi = false
share_name = /
EOF
fi

# Create seahub_settings.py file if it doesn't exist yet
if [ ! -f $SEAFILE_CONFDIR/seahub_settings.py ]; then
    cat <<- EOF > $SEAFILE_CONFDIR/seahub_settings.py
SECRET_KEY = "$(python -c "import uuid; print((str(uuid.uuid4()) + str(uuid.uuid4()))[:40])")"

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': '${SEAFILE_MYSQL_DB_NAMES[2]}',
        'USER': '${SEAFILE_MYSQL_USER}',
        'PASSWORD': '${SEAFILE_MYSQL_PASSWORD}',
        'HOST': 'mysql',
        'PORT': '3306',
        'OPTIONS': {
            'init_command': 'SET storage_engine=INNODB',
        }
    }
}
EOF
fi

# Move /opt/seafile/seafile/seahub/media/avatars to /opt/seafile/seahub-data/ and symlink it back
if [ ! -d $SEAFILE_INSTALLDIR/seahub-data/avatars ]; then
    cp -r $SEAFILE_INSTALLDIR/seafile/seahub/media/avatars $SEAFILE_INSTALLDIR/seahub-data/
fi
rm -r $SEAFILE_INSTALLDIR/seafile/seahub/media/avatars
ln -sf $SEAFILE_INSTALLDIR/seahub-data/avatars $SEAFILE_INSTALLDIR/seafile/seahub/media/avatars

# Create symlink /opt/seafile/seafile-server-latest to /opt/seafile/seafile
ln -sf $SEAFILE_INSTALLDIR/seafile $SEAFILE_INSTALLDIR/seafile-server-latest

# Create admin user if the respective environment variable is set
if [[ -n "$SEAFILE_ADMIN_EMAIL" && -n "$SEAFILE_ADMIN_PASSWORD" ]]; then
    {
        while true; do
            sleep 5
            python -c "import ccnet; ccnet.CcnetThreadedRpcClient(ccnet.ClientPool('$SEAFILE_CONFDIR')).add_emailuser('$SEAFILE_ADMIN_EMAIL', '$SEAFILE_ADMIN_PASSWORD', 1, 1)" && break
            ((c++)) && ((c==3)) && break
        done
    } &
fi

# Ownership adjustments for everything to work correctly
chown -R seafile:seafile /opt/seafile

supervisord -c $SUPERVISORD_CONFDIR/supervisord.conf
