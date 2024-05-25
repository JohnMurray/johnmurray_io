#!/usr/bin/env bash

set -exuo pipefail

export PATH="/root/.asdf/shims:${PATH}"
export PATH="/root/.asdf/bin:${PATH}"
gem update --system
gem install bundler
