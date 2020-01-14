#!/usr/bin/env zsh

export PATH="$HOME/bin:$PATH"

# adb (installed by Android Studio)
export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"

# CUDA
# https://github.com/pfnet/chainer
export CUDA_HOME=/usr/local/cuda
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
export CPATH=/usr/local/cuda/include${CPATH:+:$CPATH}
export LIBRARY_PATH=/usr/local/cuda/lib${LIBRARY_PATH:+:$LIBRARY_PATH}

