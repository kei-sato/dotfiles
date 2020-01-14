# matches case insensitive for lowercase
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# pasting with tabs doesn't perform completion
zstyle ':completion:*' insert-tab pending

# path completion
zstyle ':completion:*' menu select

# stop delete at slash
WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'

# jump to recent used directories
typeset -ga chpwd_functions

autoload -U chpwd_recent_dirs cdr
chpwd_functions+=chpwd_recent_dirs
zstyle ":chpwd:*" recent-dirs-max 10000
zstyle ":chpwd:*" recent-dirs-default true
zstyle ":completion:*" recent-dirs-insert always

# aws cli
# http://docs.aws.amazon.com/ja_jp/cli/latest/userguide/cli-command-completion.html
source /usr/local/share/zsh/site-functions/aws_zsh_completer.sh
