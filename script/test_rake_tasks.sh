#!/bin/bash

# This shell script is used to run and test the rake tasks.

MBUS_HOME=redis://localhost:6379/#MBUS_CONFIG

export MBUS_HOME

echo '---'
echo '*** mbus:config:create'
rake mbus:config:create --trace

echo '---'
echo '*** mbus:config:deploy'
rake mbus:config:deploy --trace

echo '---'
echo '*** mbus:config:display_deployed - default'
rake mbus:config:display_deployed --trace

echo '---'
echo '*** mbus:config:setup'
rake mbus:config:setup --trace

echo '---'
echo '*** mbus:status'
rake mbus:status --trace

echo '---'
echo '*** mbus:delete_exchange'
rake mbus:delete_exchange e=obsolete --trace

echo '---'
echo '*** send_messages'
rake mbus:send_messages n=10 --trace

echo '---'
echo '*** read_messages'
rake mbus:read_messages n=8 --trace

echo '---'
echo '*** sample_process'
rake mbus:sample_process app=logging-consumer MBUS_DB=none MBUS_QE_TIME=stop --trace

echo '---'
echo '*** mbus:read_messages_from_all'
rake mbus:read_messages_from_all n=999 --trace

echo 'done'

