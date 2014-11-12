#!/bin/bash

# The version of TorqueBox to install. Should be either LATEST, an
# official release (e.g. 2.1.3) or an incremental build number (e.g. 1594)
VERSION=3.1.1

# The application environment - usually one of development, test, or production
export RACK_ENV=production
export RAILS_ENV=$RACK_ENV

# Reduce the messaging threads to conserve memory
# This also gets used for jgroups and jgroups-oob threads
export MESSAGING_THREAD_RATIO=0.10 # AS7 cart defaults to 0.2

# Ensure we can create plenty of threads
if [ $(ulimit -u) -lt 500 ]; then
  ulimit -u 500
fi

# Required TorqueBox environment variables
export TORQUEBOX_HOME=$OPENSHIFT_DATA_DIR/torquebox
export JRUBY_HOME=$TORQUEBOX_HOME/jruby
export PATH=$JRUBY_HOME/bin:$PATH
# Insert the TorqueBox modules before the jbossas-7 ones
export OPENSHIFT_JBOSSAS_MODULE_PATH=$TORQUEBOX_HOME/jboss/modules/system/layers/base:$TORQUEBOX_HOME/jboss/modules/system/layers/polyglot:$TORQUEBOX_HOME/jboss/modules/system/layers/torquebox

function torquebox_install() {
    local VERSION=${1:-LATEST}
    # Determine whether we're getting a release or an incremental 
    if [[ ${VERSION} =~ \. ]]; then
        URL=http://torquebox.org/release/org/torquebox/torquebox-dist/${VERSION}/torquebox-dist-${VERSION}-bin.zip
    else
        URL=http://repository-projectodd.forge.cloudbees.com/incremental/torquebox/${VERSION}/torquebox-dist-bin.zip
    fi
    pushd ${OPENSHIFT_DATA_DIR} >/dev/null
    rm -rf torquebox*
    wget -nv ${URL}
    unzip -q torquebox-dist-*.zip
    rm torquebox-dist-*.zip
    ln -s torquebox-* torquebox
    echo "Installed" torquebox-*
    popd >/dev/null
}

function bundle_install() {
    if [ ! -d "${OPENSHIFT_REPO_DIR}/.bundle" ] && [ -f "${OPENSHIFT_REPO_DIR}/Gemfile" ]; then
        pushd ${OPENSHIFT_REPO_DIR} > /dev/null
        jruby -J-Xmx256m -J-Dhttps.protocols=SSLv3 -S bundle install --without development test --deployment
        popd > /dev/null
    fi
}

function db_migrate() {
    pushd ${OPENSHIFT_REPO_DIR} > /dev/null
    bundle exec rake db:migrate
    popd > /dev/null
}
