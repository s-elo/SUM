#!/bin/bash

set -e

# Default to development environment.
export NODE_ENVIRONMENT=${NODE_ENVIRONMENT:-development}

# compile the smart contract to json files
truffle compile
# deploy the smart contract
truffle migrate
# run the web UI
react-scripts start
