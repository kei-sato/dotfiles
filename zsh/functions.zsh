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

pickdbid() {
  local okchar dbst

  if [ ! -z "$dbid" ]; then
    1>&2 echo -n "use ${dbid} [Y/n]: "; read okchar
    if [ "$okchar" = "n" ]; then
      unset dbid
    fi
  fi

  if [ -z "$dbid" ]; then
    dbst="$1"
    aws rds describe-db-instances --query "DBInstances[${dbst:+?DBInstanceStatus==\`$dbst\`}].DBInstanceIdentifier" | jq -r ".[]" | peco | read dbid
  fi
}

pickclsid() {
  local okchar clsst

  if [ ! -z "$clsid" ]; then
    1>&2 echo -n "use ${clsid} [Y/n]: "; read okchar
    if [ "$okchar" = "n" ]; then
      unset clsid
    fi
  fi

  if [ -z "$clsid" ]; then
    clsst="$1"
    aws rds describe-db-clusters --query "DBClusters[${clsst:+?Status==\`$clsst\`}].DBClusterIdentifier" | jq -r ".[]" | peco | read clsid
  fi
}

eval_echo() {
  local OPTIND option outless cmd tempfile

  while getopts l option; do
    case "${option}" in
      l) outless=1;;
      \?) :;;
    esac
  done
  [[ $OPTIND -gt 1 ]] && shift $((OPTIND-1))

  cmd="$@"

  [ -z "$cmd" ] && return

  tempfile=$(mktemp)

  if [ "$outless" -eq 1 ]; then
    eval "$cmd" | tee "$tempfile" | less
  else
    eval "$cmd" | tee "$tempfile"
  fi

  1>&2 echo
  1>&2 echo "saved to : $tempfile"
  1>&2 echo
  1>&2 echo "command:"
  1>&2 echo
  1>&2 echo "$cmd"
  1>&2 echo
}

ddb() {
  dbst="$1"

  pickdbid "${dbst:+$dbst}"

  [ -z "$dbid" ] && return

  eval_echo -l aws rds describe-db-instances --db-instance-identifier "$dbid"
}

dcls() {
  clsst="$1"

  pickclsid "${clsst:+$clsst}"

  [ -z "$clsid" ] && return

  eval_echo -l aws rds describe-db-clusters --db-cluster-identifier "$clsid"
}

rbdb() {
  dbst="$1"

  pickdbid "${dbst:+$dbst}"

  [ -z "$dbid" ] && return

  eval_echo aws rds reboot-db-instance --db-instance-identifier "$dbid"
}

dpg() {
  local okchar

  if [ ! -z "$pg" ]; then
    1>&2 echo -n "describe ${pg} [Y/n]: "; read okchar
    if [ "$okchar" = "n" ]; then
      unset pg
    fi
  fi

  if [ -z "$pg" ]; then
    aws rds describe-db-parameter-groups --query "DBParameterGroups[].DBParameterGroupName" | jq -r '.[]' | peco | read pg
  fi

  eval_echo -l aws rds describe-db-parameters --db-parameter-group-name "$pg"
}

dclspg() {
  local okchar

  if [ ! -z "$clspg" ]; then
    1>&2 echo -n "describe ${clspg} [Y/n]: "; read okchar
    if [ "$okchar" = "n" ]; then
      unset clspg
    fi
  fi

  if [ -z "$clspg" ]; then
    aws rds describe-db-cluster-parameter-groups --query "DBClusterParameterGroups[].DBClusterParameterGroupName" | jq -r '.[]' | peco | read clspg
  fi

  eval_echo -l aws rds describe-db-cluster-parameters --db-cluster-parameter-group-name "$clspg"
}

starti() {
  local iid
  aws ec2 describe-instances | jq -r '.Reservations[] | .Instances[] | select(.State.Name=="stopped") | [.LaunchTime, .InstanceId, (.Tags[]? | select(.Key=="Name").Value)] | @csv' | sort | peco | cut -d, -f2 | tr -d '"' | read iid
  [ -z "$iid" ] && return
  eval_echo aws ec2 start-instances --instance-ids "$iid"
}

stopi() {
  local iid
  aws ec2 describe-instances | jq -r '.Reservations[] | .Instances[] | select(.State.Name=="running") | [.LaunchTime, .InstanceId, (.Tags[]? | select(.Key=="Name").Value)] | @csv' | sort | peco | cut -d, -f2 | tr -d '"' | read iid
  [ -z "$iid" ] && return
  eval_echo aws ec2 stop-instances --instance-ids "$iid"
}

startdb() {
  aws rds describe-db-instances --query 'DBInstances[?DBInstanceStatus==`stopped`].DBInstanceIdentifier' | jq -r ".[]" | peco | read dbid
  [ -z "$dbid" ] && return
  eval_echo aws rds start-db-instance --db-instance-identifier "$dbid"
}

stopdb() {
  aws rds describe-db-instances --query 'DBInstances[?DBInstanceStatus==`available`].DBInstanceIdentifier' | jq -r ".[]" | peco | read dbid
  [ -z "$dbid" ] && return
  eval_echo aws rds stop-db-instance --db-instance-identifier "$dbid"
}

waitavailable() {
  pickdbid
  [ -z "$dbid" ] && return

  echo started: $(date "+%Y-%m-%d %H:%M:%S")
  sleep 10
  aws rds wait db-instance-available --db-instance-identifier "$dbid" && hey available $_ || hey failed $_
  echo finished: $(date "+%Y-%m-%d %H:%M:%S")
}

waitstopped() {
  [ -z "$dbid" ] && return
  alias date2='date "+%Y-%m-%d %H:%M:%S"'
  echo "[$(date2)] start checking $dbid"
  while :; do
    aws rds describe-db-instances --query 'DBInstances[?DBInstanceStatus==`stopped`].DBInstanceIdentifier' | egrep "\"$dbid\"" && break
    sleep 10
  done
  echo "[$(date2)] $dbid is stopped"
  hey "$dbid is stopped"
}

lessdblog() {
  local fname fsize ftmp1 ftmp2

  if [ -z "$dbid" ]; then
    aws rds describe-db-instances --query "DBInstances[].DBInstanceIdentifier" | jq -r ".[]" | peco | read dbid
  fi

  aws rds describe-db-log-files --db-instance-identifier "$dbid" | jq -r '.DescribeDBLogFiles | sort_by(.LastWritten) | reverse | .[].LogFileName' | peco | read fname

  [ -z "$fname" ] && return

  ftmp1=$(mktemp)
  ftmp2=$(mktemp)

  aws rds describe-db-log-files --db-instance-identifier "$dbid" --filename-contains "$fname" --query "DescribeDBLogFiles[0].Size" | read fsize
  echo "Size : ${fsize}"

  t=0
  while [ ! "$t" = null -o "$t" = 0 ]; do
    aws rds download-db-log-file-portion --db-instance-identifier "$dbid" --log-file-name "$fname" --starting-token "$t" --max-items 1000000 > "$ftmp2" || return
    jq -r '.LogFileData' < "$ftmp2" >> "$ftmp1"
    t="$(jq -r '.NextToken' < "$ftmp2")"
    wc -c "$ftmp1"
  done

  less "$ftmp1"
  echo "saved to $ftmp1"
}

lesscli() {
  local dir fpath
  dir="/usr/local/share/awscli/examples"
  find "$dir" -type f | cut -c 34- | peco | read fpath

  [ -z "$fpath" ] && return

  less "${dir}/${fpath}"
}

