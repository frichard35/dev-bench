#!/usr/bin/env bash
# Context official repos (github, maven and node) on internet without proxy

GITHUB_URL="https://github.com"
DOCKER_REGISTRY="https://registry-1.docker.io"
DOCKER_REGISTRY_LOGIN=""
DOCKER_REGISTRY_PASSWORD=""
# Force docker basic authentication
# DOCKER_REGISTRY_AUTH=basic
#
# Proxy config (optional)
# DB_PROXY_HOST='localhost'
# DB_PROXY_PORT='8888'

context_metrics(){
    add_metric context internet
    add_metric repo officials
}

init_context(){
    if [ -z "$DB_PROXY_HOST" ] || [ -z "$DB_PROXY_PORT" ]; then
        DB_PROXY_ENABLE="false"
        GITHUB_CURL_PROXY=""
    else
        DB_PROXY_ENABLE="true"
        GITHUB_CURL_PROXY="--proxy http://$DB_PROXY_HOST:$DB_PROXY_PORT --noproxy ''"
    fi
}

maven_settings() {
    echo "[DEV BENCH] maven_settings"
    echo -e "-s\n.mvn/settings.xml" > .mvn/maven.config
    if [ "$DB_PROXY_ENABLE" = "true" ]; then
        local proxy_conf="<proxies>
                <proxy>
                    <id>httpsproxy</id>
                    <active>$DB_PROXY_ENABLE</active>
                    <protocol>https</protocol>
                    <host>$DB_PROXY_HOST</host>
                    <port>$DB_PROXY_PORT</port>
                    <nonProxyHosts>localhost|127.0.0.1</nonProxyHosts>
                </proxy>
            </proxies>"
    fi
    cat << EOF > .mvn/settings.xml
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 http://maven.apache.org/xsd/settings-1.0.0.xsd">
    $proxy_conf
</settings>
EOF
}