#!/bin/bash
set -e

export SEAFILE_DOMAIN=127.0.0.1
export SEAFILE_INSTANCE_NAME=Seafile
export CCNET_CONF_DIR="$SEAFILE_CONFDIR"
export SEAFILE_CONF_DIR="$SEAFILE_CONFDIR"
export LD_LIBRARY_PATH=$SEAFILE_SERVERINSTALLDIR/seafile/lib:$SEAFILE_APPDIR/seafile/seafile/lib64
export PYTHONPATH=$SEAFILE_SERVERINSTALLDIR/seafile/lib/python2.7/site-packages:$SEAFILE_SERVERINSTALLDIR/seafile/lib64/python2.7/site-packages:$SEAFILE_SERVERINSTALLDIR/seafile/lib/python2.6/site-packages:$SEAFILE_SERVERINSTALLDIR/seafile/lib64/python2.6/site-packages:$SEAFILE_SERVERINSTALLDIR/seahub:$SEAFILE_SERVERINSTALLDIR/seahub/thirdpart


if [[ ! -f $SEAFILE_CONFDIR/ccnet.conf || ! -f $SEAFILE_CONFDIR/mykey.peer ]]; then
    $SEAFILE_SERVERINSTALLDIR/seafile/bin/ccnet-init -F $SEAFILE_CONFDIR --config-dir $SEAFILE_CONFDIR/tmp --name $SEAFILE_INSTANCE_NAME --host $SEAFILE_DOMAIN

    mv $SEAFILE_CONFDIR/tmp/* $SEAFILE_CONFDIR
    rm -r $SEAFILE_CONFDIR/tmp/
fi

# Create seafile.ini file if it doesn't exist yet
if [ ! -f $SEAFILE_CONFDIR/seafile.ini ]; then
    cat <<- EOF > $SEAFILE_CONFDIR/seafile.ini
${SEAFILE_DATADIR}
EOF
fi


# Create seahub_settings.py file if it doesn't exist yet
if [ ! -f $SEAFILE_CONFDIR/seahub_settings.py ]; then
    cat <<- EOF > $SEAFILE_CONFDIR/seahub_settings.py
SECRET_KEY = "$(python -c "import uuid; print((str(uuid.uuid4()) + str(uuid.uuid4()))[:40])")"
EOF
fi

# Move /opt/seafile/seafile/seahub/media/avatars to /opt/seafile/seahub-data/ and symlink it back
if [ ! -d $SEAFILE_INSTALLDIR/seahub-data/avatars ]; then
    cp -r $SEAFILE_SERVERINSTALLDIR/seahub/media/avatars $SEAFILE_INSTALLDIR/seahub-data/
fi
if [ ! -L $SEAFILE_SERVERINSTALLDIR/seahub/media/avatars ]; then
    rm -r $SEAFILE_SERVERINSTALLDIR/seahub/media/avatars
    ln -sfn $SEAFILE_INSTALLDIR/seahub-data/avatars $SEAFILE_SERVERINSTALLDIR/seahub/media/avatars
fi

# Create symlink /opt/seafile/seafile-server-latest to /opt/seafile/seafile
if [ ! -L $SEAFILE_INSTALLDIR/seafile-server-latest ]; then
    ln -sfn $SEAFILE_SERVERINSTALLDIR $SEAFILE_INSTALLDIR/seafile-server-latest
fi

# Ownership adjustments for everything to work correctly
chown -R seafile:seafile /opt/seafile

supervisord -c $SUPERVISORD_CONFDIR/supervisord.conf
