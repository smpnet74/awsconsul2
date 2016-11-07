#!/bin/bash
sudo cat <<HEREDOC1 > /etc/init/consul.conf
description "Consul agent"

start on started networking
stop on runlevel [!2345]

respawn
# This is to avoid Upstart re-spawning the process upon `consul leave`
normal exit 0 INT

script
  if [ -f "/etc/service/consul" ]; then
    . /etc/service/consul
  fi

  # Make sure to use all our CPUs, because Consul can block a scheduler thread
  export GOMAXPROCS=`nproc`

  # Get the local IP
  BIND=`ifconfig eth0 | grep "inet addr" | awk '{ print substr($2,6) }'`
  ADVERTISE=`curl http://169.254.169.254/latest/meta-data/public-ipv4`

  exec /usr/local/bin/consul agent \
    -config-dir="/etc/consul.d" \
    -bind=$$BIND \
    -advertise-wan=$$ADVERTISE \
    -server -bootstrap-expect=${SERVERCOUNT} -join=${LEADER} -data-dir=/opt/consul/data -client 0.0.0.0 -ui \
    >>/var/log/consul.log 2>&1
end script
HEREDOC1

sudo cat <<HEREDOC2 > /etc/service/consul 
CONSUL_FLAGS="-server -bootstrap-expect=${SERVERCOUNT} -join=${LEADER} -data-dir=/opt/consul/data -client 0.0.0.0 -ui"
HEREDOC2

sudo cat <<HEREDOC3 > /tmp/firststart 
#!/bin/bash
for run in {1..3}
do
  start consul
  sleep 30
done
HEREDOC3
