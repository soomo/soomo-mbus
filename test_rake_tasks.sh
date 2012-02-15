#!/bin/bash

# This shell script is used to run and test the rake tasks.

MBUS_CONFIG_DEFAULT='test_exch,test_queue,produce,test.*'
MBUS_CONFIG_TEST_CONSUMER='test_exch,test_queue,consume,test.*'
MBUS_CONFIG_TEST_PRODUCER='test_exch,test_queue,produce,test.*'

export MBUS_CONFIG_DEFAULT
export MBUS_CONFIG_TEST_CONSUMER
export MBUS_CONFIG_TEST_PRODUCER 

echo '---'
echo '*** create_mbus_config'
rake mbus:create_mbus_config --trace

echo '---'
echo '*** display_mbus_config - default'
rake mbus:display_mbus_config --trace

echo '---'
echo '*** display_mbus_config - consumer'
rake mbus:display_mbus_config MBUS_ENV=MBUS_CONFIG_TEST_CONSUMER --trace 

echo '---'
echo '*** display_mbus_config - producer'
rake mbus:display_mbus_config MBUS_ENV=MBUS_CONFIG_TEST_PRODUCER --trace 

echo '---'
echo '*** display_mbus_status'
rake mbus:display_mbus_status --trace

echo '---'
echo '*** delete_exchange'
rake mbus:delete_exchange e=obsolete --trace 

echo '---'
echo '*** create_vote'
rake db:create_vote cname=ron vname=paul --trace

echo '---'
echo '*** send_messages'
rake mbus:send_messages e=test_exch k='test.key' n=10 --trace 

echo '---'
echo '*** read_messages'
rake mbus:read_messages e=test_exch q=test_queue n=10 MBUS_ENV=MBUS_CONFIG_TEST_CONSUMER --trace

echo '---'
echo '*** sample_process'
rake mbus:sample_process MBUS_DB=none MBUS_QE_TIME=stop MBUS_ENV=MBUS_CONFIG_TEST_CONSUMER --trace 

echo '---'
echo '*** send_messages_to_all'
rake mbus:send_messages_to_all n=5 --trace

echo '---'
echo '*** read_messages_from_all'
rake mbus:read_messages_from_all n=999 MBUS_ENV=MBUS_CONFIG_TEST_CONSUMER --trace 

echo 'done'
 