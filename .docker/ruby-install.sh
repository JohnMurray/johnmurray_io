#!/usr/bin/env bash

set -exuo pipefail

# Install and setup asdf
git clone https://github.com/excid3/asdf.git /root/.asdf
if [ -e "/root/.asdf/asdf.sh" ]; then
    source "/root/.asdf/asdf.sh"
fi
export PATH="/root/.asdf/bin:${PATH}"
asdf plugin-add ruby
asdf install ruby 3.3.1
asdf global ruby 3.3.1
