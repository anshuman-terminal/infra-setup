#!/bin/bash
curl -fsSL https://awscli.amazonaws.com/v2/install.sh | bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
aws --version
