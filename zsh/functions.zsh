#!/usr/bin/env zsh

# Create a new directory and enter it
function mkd() {
	mkdir -p "$@" && cd "$_";
}

# Change working directory to the top-most Finder window location
function cdf() { # short for `cdfinder`
	cd "$(osascript -e 'tell app "Finder" to POSIX path of (insertion location as alias)')";
}

# Create a .tar.gz archive, using `zopfli`, `pigz` or `gzip` for compression
function targz() {
	local tmpFile="${@%/}.tar";
	tar -cvf "${tmpFile}" --exclude=".DS_Store" "${@}" || return 1;

	size=$(
		stat -f"%z" "${tmpFile}" 2> /dev/null; # macOS `stat`
		stat -c"%s" "${tmpFile}" 2> /dev/null;  # GNU `stat`
	);

	local cmd="";
	if (( size < 52428800 )) && hash zopfli 2> /dev/null; then
		# the .tar file is smaller than 50 MB and Zopfli is available; use it
		cmd="zopfli";
	else
		if hash pigz 2> /dev/null; then
			cmd="pigz";
		else
			cmd="gzip";
		fi;
	fi;

	echo "Compressing .tar ($((size / 1000)) kB) using \`${cmd}\`…";
	"${cmd}" -v "${tmpFile}" || return 1;
	[ -f "${tmpFile}" ] && rm "${tmpFile}";

	zippedSize=$(
		stat -f"%z" "${tmpFile}.gz" 2> /dev/null; # macOS `stat`
		stat -c"%s" "${tmpFile}.gz" 2> /dev/null; # GNU `stat`
	);

	echo "${tmpFile}.gz ($((zippedSize / 1000)) kB) created successfully.";
}

# Determine size of a file or total size of a directory
function fs() {
	if du -b /dev/null > /dev/null 2>&1; then
		local arg=-sbh;
	else
		local arg=-sh;
	fi
	if [[ -n "$@" ]]; then
		du $arg -- "$@";
	else
		du $arg .[^.]* ./*;
	fi;
}

# Create a data URL from a file
function dataurl() {
	local mimeType=$(file -b --mime-type "$1");
	if [[ $mimeType == text/* ]]; then
		mimeType="${mimeType};charset=utf-8";
	fi
	echo "data:${mimeType};base64,$(openssl base64 -in "$1" | tr -d '\n')";
}

# Create a git.io short URL
function gitio() {
	if [ -z "${1}" -o -z "${2}" ]; then
		echo "Usage: \`gitio slug url\`";
		return 1;
	fi;
	curl -i https://git.io/ -F "url=${2}" -F "code=${1}";
}

# Start an HTTP server from a directory, optionally specifying the port
function server() {
	local port="${1:-8000}";
	sleep 1 && open "http://localhost:${port}/" &
  ruby -run -ehttpd . -p"$port"
}

# Start a PHP server from a directory, optionally specifying the port
# (Requires PHP 5.4.0+.)
function phpserver() {
	local port="${1:-4000}";
	local ip=$(ipconfig getifaddr en1);
	sleep 1 && open "http://${ip}:${port}/" &
	php -S "${ip}:${port}";
}

# Compare original and gzipped file size
function gz() {
	local origsize=$(wc -c < "$1");
	local gzipsize=$(gzip -c "$1" | wc -c);
	local ratio=$(echo "$gzipsize * 100 / $origsize" | bc -l);
	printf "orig: %d bytes\n" "$origsize";
	printf "gzip: %d bytes (%2.2f%%)\n" "$gzipsize" "$ratio";
}

# Syntax-highlight JSON strings or files
# Usage: `json '{"foo":42}'` or `echo '{"foo":42}' | json`
function json() {
	if [ -t 0 ]; then # argument
		python -mjson.tool <<< "$*" | pygmentize -l javascript;
	else # pipe
		python -mjson.tool | pygmentize -l javascript;
	fi;
}

# Run `dig` and display the most useful info
function digga() {
	dig +nocmd "$1" any +multiline +noall +answer;
}

# UTF-8-encode a string of Unicode symbols
function escape() {
	printf "\\\x%s" $(printf "$@" | xxd -p -c1 -u);
	# print a newline unless we’re piping the output to another program
	if [ -t 1 ]; then
		echo ""; # newline
	fi;
}

# Decode \x{ABCD}-style Unicode escape sequences
function unidecode() {
	perl -e "binmode(STDOUT, ':utf8'); print \"$@\"";
	# print a newline unless we’re piping the output to another program
	if [ -t 1 ]; then
		echo ""; # newline
	fi;
}

# Get a character’s Unicode code point
function codepoint() {
	perl -e "use utf8; print sprintf('U+%04X', ord(\"$@\"))";
	# print a newline unless we’re piping the output to another program
	if [ -t 1 ]; then
		echo ""; # newline
	fi;
}

# Show all the names (CNs and SANs) listed in the SSL certificate
# for a given domain
function getcertnames() {
	if [ -z "${1}" ]; then
		echo "ERROR: No domain specified.";
		return 1;
	fi;

	local domain="${1}";
	echo "Testing ${domain}…";
	echo ""; # newline

	local tmp=$(echo -e "GET / HTTP/1.0\nEOT" \
		| openssl s_client -connect "${domain}:443" -servername "${domain}" 2>&1);

	if [[ "${tmp}" = *"-----BEGIN CERTIFICATE-----"* ]]; then
		local certText=$(echo "${tmp}" \
			| openssl x509 -text -certopt "no_aux, no_header, no_issuer, no_pubkey, \
			no_serial, no_sigdump, no_signame, no_validity, no_version");
		echo "Common Name:";
		echo ""; # newline
		echo "${certText}" | grep "Subject:" | sed -e "s/^.*CN=//" | sed -e "s/\/emailAddress=.*//";
		echo ""; # newline
		echo "Subject Alternative Name(s):";
		echo ""; # newline
		echo "${certText}" | grep -A 1 "Subject Alternative Name:" \
			| sed -e "2s/DNS://g" -e "s/ //g" | tr "," "\n" | tail -n +2;
		return 0;
	else
		echo "ERROR: Certificate not found.";
		return 1;
	fi;
}

# `v` with no arguments opens the current directory in Vim, otherwise opens the
# given location
function v() {
    if [ $# -eq 0 ]; then
        vim .;
    else
        vim "$@";
    fi;
}

# `o` with no arguments opens the current directory, otherwise opens the given
# location
function o() {
    if [ $# -eq 0 ]; then
        open .;
    else
        open "$@";
    fi;
}

# `s` with no arguments opens the current directory in Sublime Text, otherwise
# opens the given location
function s() {
    if [ $# -eq 0 ]; then
        subl .;
    else
        subl "$@";
    fi;
}

# `tre` is a shorthand for `tree` with hidden files and color enabled, ignoring
# the `.git` directory, listing directories first. The output gets piped into
# `less` with options to preserve color and line numbers, unless the output is
# small enough for one screen.
function tre() {
	tree -aC -I '.git|node_modules|bower_components|.sass-cache' --dirsfirst "$@" | less -FRNX;
}


################
# zsh
################

# http://qiita.com/catfist/items/0ebd4350cc2976a95105
cd() {
  if [ -p /dev/stdin ]; then
    builtin cd "$(cat <&0)"
    return $?
  fi

  builtin cd "$@"
}

# http://blog.kenjiskywalker.org/blog/2014/06/12/peco/
# ctrl + r でhistoryをインクリメンタルサーチ
function peco-select-history() {
  BUFFER=$(history -n -10000 | tail -r | peco --query "$LBUFFER")
  CURSOR=$#BUFFER
  zle clear-screen
}
zle -N peco-select-history
bindkey '^r' peco-select-history

# http://fromatom.hatenablog.com/entry/2014/11/12/195155
function peco-cdr () {
    local selected_dir=$(cdr -l | awk '{ print $2 }' | peco)
    if [ -n "$selected_dir" ]; then
        BUFFER="cd ${selected_dir}"
        zle accept-line
    fi
    zle clear-screen
}
zle -N peco-cdr
bindkey '^u' peco-cdr

# Usage: sumcpu chrome
sumcpu() {
  sum=0; for n in $(ps -ev | grep -i "$1" | awk '{print $11}'); do (( sum+=n )); done; echo $sum
}

# Usage: summem chrome
summem() {
  sum=0; for n in $(ps -ev | grep -i "$1" | awk '{print $12}'); do (( sum+=n )); done; echo $sum
}

echop() {
  echo -n $@ | pbcopy
}

################
# docker
################

dinit() {
  if [ "`docker-machine status default`" = "Running" ]; then
    eval "$(docker-machine env default)"
    docker-machine ssh default 'echo nameserver 8.8.8.8 > /etc/resolv.conf'
  fi
  docker version
}

dstart() {
  docker-machine start default
  dinit
}


# aws

ccls() {

  if [ $# -lt 2 ]; then
    echo "create aurora cluster with specific version"
    echo "usage: ccls <instance name> <version>"
    echo "example: ccls ins-1 1.15.1"
    return
  fi

  dbid="$1"
  clsid="${dbid}-cluster"

  aws rds create-db-cluster \
    --db-cluster-identifier "$clsid" \
    --engine aurora \
    --engine-version 5.6.10a \
    --master-username root \
    --master-user-password password

  aws rds create-db-instance \
    --db-instance-identifier "$dbid" \
    --db-cluster-identifier "$clsid" \
    --engine aurora \
    --engine-version 5.6.10a."$2" \
    --no-auto-minor-version-upgrade \
    --publicly-accessible \
    --db-instance-class db.t2.small

}

cdb() {

  cat > /tmp/engines << EOF
mariadb
mysql
oracle-ee
postgres
sqlserver-ee
sqlserver-ex
sqlserver-se
sqlserver-web
EOF

  local engine version mazchar maz saz cmd okchar

  peco < /tmp/engines | read engine

  if [ -z "$engine" ]; then
    return
  fi

  echo "saved engine: $engine"

  aws rds describe-db-engine-versions --filters "Name=engine,Values=$engine" --query "DBEngineVersions[].EngineVersion" | jq -r '.[]' | peco | read version

  if [ -z "$version" ]; then
    return
  fi
  
  echo "saved version: $version"

  echo -n 'DB instance name: '; read dbid

  if [ -z "$dbid" ]; then
    echo "DB instance name is empty. abort"
    return
  fi

  echo -n 'Multi-AZ [y/N]: '; read mazchar

  if [ "$mazchar" = "y" ]; then
    maz=1
  else
    saz=1
  fi


  echo aws rds create-db-instance \
  --db-instance-identifier "$dbid" \
  --engine "$engine" \
  --engine-version "$version" \
  --db-instance-class db.t2.small \
  --allocated-storage 20 \
  --db-name db1 \
  --master-username root \
  --master-user-password password \
  ${maz:+ --multi-az} \
  ${saz:+ --no-multi-az} \
  --no-auto-minor-version-upgrade \
  --publicly-accessible | read cmd

  echo
  echo "the following command will be executed:"
  echo
  echo "$cmd"
  echo
  echo -n 'Is it ok? [Y/n]: '; read okchar

  if [ "$okchar" = "n" ]; then
    return
  fi

  eval "$cmd"

}

dpg() {
  local okchar tempfile

  if [ ! -z "$pg" ]; then
    echo -n "describe ${pg} [Y/n]: "; read okchar
    if [ "$okchar" = "n" ]; then
      unset pg
    fi
  fi

  if [ -z "$pg" ]; then
    aws rds describe-db-parameter-groups --query "DBParameterGroups[].DBParameterGroupName" | jq -r '.[]' | peco | read pg
  fi

  tempfile=$(mktemp)
  aws rds describe-db-parameters --db-parameter-group-name "$pg" > "$tempfile"

  less "$tempfile"
  echo "saved to : $tempfile"
}

dclspg() {
  local okchar tempfile

  if [ ! -z "$clspg" ]; then
    echo -n "describe ${clspg} [Y/n]: "; read okchar
    if [ "$okchar" = "n" ]; then
      unset clspg
    fi
  fi

  if [ -z "$clspg" ]; then
    aws rds describe-db-cluster-parameter-groups --query "DBClusterParameterGroups[].DBClusterParameterGroupName" | jq -r '.[]' | peco | read clspg
  fi

  tempfile=$(mktemp)
  aws rds describe-db-cluster-parameters --db-cluster-parameter-group-name "$clspg" > "$tempfile"

  less "$tempfile"
  echo "saved to : $tempfile"
}
