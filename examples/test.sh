#!/bin/bash
set -ev

cd examples/ecto_example
mix local.rebar --force
mix local.hex --force
mix deps.get
mix test
