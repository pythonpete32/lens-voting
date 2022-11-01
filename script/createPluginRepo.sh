#!/bin/bash
. .env

cast call $PluginRepoFactory "createPluginRepo(string,address)" $1 $2 --rpc-url ${MUMBAI_RPC_URL} --private-key ${PRIVATE_KEY}