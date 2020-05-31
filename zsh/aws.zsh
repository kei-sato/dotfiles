#!/usr/bin/env zsh

# rds command utility functions

hey() {
	ismac=false
	[ $(uname -s) = "Darwin" ] && ismac=true
	if $ismac; then
		which osascript &>/dev/null && osascript -e 'display alert "'"$*"'"'
	else
		echo "$*"
	fi
}

pickdbid() {
  local okchar stfilter dbstatus

  if [ ! -z "$dbid" ]; then
    1>&2 echo -n "use ${dbid} [Y/n]: "; read okchar
    if [ "$okchar" = "n" ]; then
      unset dbid
    fi
  fi

  if [ -z "$dbid" ]; then
    stfilter="$1"
    aws rds describe-db-instances --query "DBInstances[${stfilter:+?DBInstanceStatus==\`$dbst\`}].[DBInstanceStatus,DBInstanceIdentifier]" --output text | sort | peco | read -r dbstatus dbid
  fi
}

pickclsid() {
  local okchar stfilter clsstatus

  if [ ! -z "$clsid" ]; then
    1>&2 echo -n "use ${clsid} [Y/n]: "; read okchar
    if [ "$okchar" = "n" ]; then
      unset clsid
    fi
  fi

  if [ -z "$clsid" ]; then
    stfilter="$1"
    aws rds describe-db-clusters --query "DBClusters[${stfilter:+?Status==\`$stfilter\`}].[Status,DBClusterIdentifier]" --output text | sort | peco | read -r clsstatus clsid
  fi
}

pickpgname() {
  local okchar

  if [ ! -z "$pgname" ]; then
    1>&2 echo -n "use ${pgname} [Y/n]: "; read okchar
    if [ "$okchar" = "n" ]; then
      unset pgname
    fi
  fi

  if [ -z "$pgname" ]; then
    pgname=$(aws rds describe-db-parameter-groups --query "DBParameterGroups[].[DBParameterGroupName]" --output text | peco)
  fi
}

pickclspgname() {
  local okchar

  if [ ! -z "$clspgname" ]; then
    1>&2 echo -n "use ${clspgname} [Y/n]: "; read okchar
    if [ "$okchar" = "n" ]; then
      unset clspgname
    fi
  fi

  if [ -z "$clspgname" ]; then
    clspgname=$(aws rds describe-db-cluster-parameter-groups --query "DBClusterParameterGroups[].[DBClusterParameterGroupName]" --output text | peco)
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

eval_confirm() {
	local okchar cmd

  cmd="$@"
  [ -z "$cmd" ] && return

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

rds-dbids() {
	pickdbid
	echo dbid=$dbid
}
alias dbids=rds-dbids

rds-clsids() {
	pickclsid
	echo clsid=$clsid
}
alias clsids=rds-clsids

rds-lsdb() {
	aws rds describe-db-instances --query 'DBInstances[].[InstanceCreateTime, DBInstanceStatus, Engine, DBInstanceIdentifier, Endpoint.Address]' --output text | tr '\t' ',' | sort -t, -k3,3
}
alias lsdb=rds-lsdb

rds-lscls() {
	aws rds describe-db-clusters --query 'DBClusters[].[ClusterCreateTime, Status, Engine, EngineVersion, DBClusterIdentifier]' --output text | tr '\t' ',' | sort -t, -k3,3
}
alias lscls=rds-lscls

rds-lspgs() {
	aws rds describe-db-parameter-groups --query 'DBParameterGroups[].[DBParameterGroupFamily, DBParameterGroupName]' --output text | sort
}
alias lspgs=rds-lspgs

rds-lsclspgs() {
	aws rds describe-db-cluster-parameter-groups --query 'DBClusterParameterGroups[].[DBParameterGroupFamily, DBClusterParameterGroupName]' --output text | sort
}
alias lsclspgs=rds-lsclspgs

rds-ddb() {
  dbst="$1"

  pickdbid "${dbst:+$dbst}"

  [ -z "$dbid" ] && return

  eval_echo -l aws rds describe-db-instances --db-instance-identifier "$dbid"
}
alias ddb=rds-ddb

rds-dcls() {
  clsst="$1"

  pickclsid "${clsst:+$clsst}"

  [ -z "$clsid" ] && return

  eval_echo -l aws rds describe-db-clusters --db-cluster-identifier "$clsid"
}
alias dcls=rds-dcls

rds-rbdb() {
  dbst="$1"

  pickdbid "${dbst:+$dbst}"

  [ -z "$dbid" ] && return

  eval_echo aws rds reboot-db-instance --db-instance-identifier "$dbid"
}
alias rbdb=rds-rbdb

rds-dpg() {
	pickpgname
	[ -z "$pgname" ] && return
  eval_echo -l aws rds describe-db-parameters --db-parameter-group-name "$pgname"
}
alias dpg=rds-dpg

rds-dclspg() {
	pickclspgname
  [ -z "$clspgname" ] && return
  eval_echo -l aws rds describe-db-cluster-parameters --db-cluster-parameter-group-name "$clspgname"
}
alias dclspg=rds-dclspg

rds-starti() {
  local iid
  aws ec2 describe-instances | jq -r '.Reservations[] | .Instances[] | select(.State.Name=="stopped") | [.LaunchTime, .InstanceId, (.Tags[]? | select(.Key=="Name").Value)] | @csv' | sort | peco | cut -d, -f2 | tr -d '"' | read iid
  [ -z "$iid" ] && return
  eval_echo aws ec2 start-instances --instance-ids "$iid"
}
alias starti=rds-starti

rds-stopi() {
  local iid
  aws ec2 describe-instances | jq -r '.Reservations[] | .Instances[] | select(.State.Name=="running") | [.LaunchTime, .InstanceId, (.Tags[]? | select(.Key=="Name").Value)] | @csv' | sort | peco | cut -d, -f2 | tr -d '"' | read iid
  [ -z "$iid" ] && return
  eval_echo aws ec2 stop-instances --instance-ids "$iid"
}
alias stopi=rds-stopi

rds-startdb() {
  pickdbid stopped
  [ -z "$dbid" ] && return
  eval_echo aws rds start-db-instance --db-instance-identifier "$dbid"
}
alias startdb=rds-startdb

rds-stopdb() {
  pickdbid available
  [ -z "$dbid" ] && return
  eval_echo aws rds stop-db-instance --db-instance-identifier "$dbid"
}
alias stopdb=rds-stopdb

rds-rmdb() {
	local cmd
  pickdbid
  [ -z "$dbid" ] && return
	cmd=$(echo aws rds delete-db-instance --db-instance-identifier "$dbid" --skip-final-snapshot)
	pgname=$(aws rds describe-db-parameter-groups --db-parameter-group-name "$dbid" --query 'DBParameterGroups[].[DBParameterGroupName]' --output text 2>/dev/null)
	[ -n "$pgname" ] && cmd=$(echo $cmd '&&' aws rds 'wait' db-instance-deleted --db-instance-identifier "$dbid" '&&' aws rds delete-db-parameter-group --db-parameter-group-name "$pgname")
	eval_confirm "$cmd"
}
alias rmdb=rds-rmdb

rds-rmcls() {
	local dbids clspgname pgname cmd

	pickclsid
  [ -z "$clsid" ] && return

	dbid=${clsid%%-cluster}
	dbids=$(aws rds describe-db-clusters --db-cluster-identifier "$clsid" --query "DBClusters[].DBClusterMembers[].[DBInstanceIdentifier]" --output text)
  [ -n "$dbids" ] && while read x; do cmd=$(echo ${cmd:+$cmd &&} aws rds delete-db-instance --db-instance-identifier "$x" --skip-final-snapshot); done <<< $dbids

	pgname=$(aws rds describe-db-parameter-groups --db-parameter-group-name "$dbid" --query 'DBParameterGroups[].[DBParameterGroupName]' --output text 2>/dev/null)
	[ -n "$pgname" ] && cmd=$(echo $cmd '&&' aws rds 'wait' db-instance-deleted --db-instance-identifier "$dbid" '&&' aws rds delete-db-parameter-group --db-parameter-group-name "$pgname")

	cmd=$(echo ${cmd:+$cmd &&} aws rds delete-db-cluster --db-cluster-identifier "$clsid" --skip-final-snapshot)

	clspgname=$(aws rds describe-db-cluster-parameter-groups --db-cluster-parameter-group-name "$dbid" --query 'DBClusterParameterGroups[].[DBClusterParameterGroupName]' --output text 2>/dev/null)
	# "aws rds wait db-cluster-deleted" doesn't exist at the moment. So, it does sleep a while.
	[ -n "$clspgname" ] && cmd=$(echo $cmd '&&' sleep 60 '&&' aws rds delete-db-cluster-parameter-group --db-cluster-parameter-group-name "$clspgname")

	eval_confirm "$cmd"
}
alias rmcls=rds-rmcls

rds-mkpg() {
  local okchar pgfml

  if [ ! -z "$dbid" ]; then
    1>&2 echo -n "use ${dbid} [Y/n]: "; read okchar
    if [ "$okchar" != "n" ]; then
      pgname="$dbid"
    fi
  fi

  pgfml=$(aws rds describe-db-parameter-groups --query "DBParameterGroups[].[DBParameterGroupFamily]" --output text | sort | uniq | peco)

  [ -z "$pgfml" ] && return

	if [ -z "$pgname" ]; then
		echo -n 'parameter group name: '; read pgname
	fi

  [ -z "$pgname" ] && return

  eval_confirm aws rds create-db-parameter-group --db-parameter-group-name "$pgname" --db-parameter-group-family "$pgfml" --description "$pgname"
}
alias mkpg=rds-mkpg

rds-mkclspg() {
  local okchar pgfml

  if [ ! -z "$dbid" ]; then
    1>&2 echo -n "use ${dbid} [Y/n]: "; read okchar
    if [ "$okchar" != "n" ]; then
      clspgname="$dbid"
    fi
  fi

  pgfml=$(aws rds describe-db-cluster-parameter-groups --query "DBClusterParameterGroups[].[DBParameterGroupFamily]" --output text | sort | uniq | peco)

  [ -z "$pgfml" ] && return

	if [ -z "$clspgname" ]; then
		echo -n 'parameter group name: '; read clspgname
	fi

  [ -z "$clspgname" ] && return

	eval_confirm aws rds create-db-cluster-parameter-group --db-cluster-parameter-group-name "$clspgname" --db-parameter-group-family "$pgfml" --description "$clspgname"
}
alias mkclspg=rds-mkclspg

rds-modpg() {
	local prm oldval newval cmd

	pickpgname
  [ -z "$pgname" ] && return
	prm=$(aws rds describe-db-parameters --db-parameter-group-name "$pgname" --query "Parameters[?IsModifiable==\`true\`].[ParameterName]" --output text | peco)
  [ -z "$prm" ] && return
	oldval=$(aws rds describe-db-parameters --db-parameter-group-name "$pgname" --query "Parameters[?ParameterName==\`${prm}\`].[ParameterValue]" --output text)
	echo "parameter : ${prm}"
	echo "current value : ${oldval}"
	echo -n 'new value : '; read newval
  [ -z "$newval" ] && return
	cmd=$(echo aws rds modify-db-parameter-group --db-parameter-group-name "$pgname" --parameters ParameterName="$prm",ParameterValue=\'\"${newval}\"\',ApplyMethod=immediate)
	eval_confirm "$cmd"
}
alias modpg=rds-modpg

rds-modclspg() {
	local prm oldval newval cmd

	pickclspgname
  [ -z "$clspgname" ] && return
	prm=$(aws rds describe-db-cluster-parameters --db-cluster-parameter-group-name "$clspgname" --query "Parameters[?IsModifiable==\`true\`].[ParameterName]" --output text | peco)
  [ -z "$prm" ] && return
	oldval=$(aws rds describe-db-cluster-parameters --db-cluster-parameter-group-name "$clspgname" --query "Parameters[?ParameterName==\`${prm}\`].[ParameterValue]" --output text)
	echo "parameter : ${prm}"
	echo "current value : ${oldval}"
	echo -n 'new value : '; read newval
  [ -z "$newval" ] && return
	cmd=$(echo aws rds modify-db-cluster-parameter-group --db-cluster-parameter-group-name "$clspgname" --parameters ParameterName="$prm",ParameterValue=\'\"${newval}\"\',ApplyMethod=immediate)
	eval_confirm "$cmd"
}
alias modclspg=rds-modclspg

rds-rmpg() {
	pickpgname
  [ -z "$pgname" ] && return
  eval_confirm aws rds delete-db-parameter-group --db-parameter-group-name "$pgname"
}
alias rmpg=rds-rmpg

rds-rmclspg() {
	pickclspgname
  [ -z "$clspgname" ] && return
	eval_confirm aws rds delete-db-cluster-parameter-group --db-cluster-parameter-group-name "$clspgname"
}
alias rmclspg=rds-rmclspg

rds-waitavailable() {
  pickdbid
  [ -z "$dbid" ] && return

  echo started: $(date "+%Y-%m-%d %H:%M:%S")
  sleep 10
  aws rds wait db-instance-available --db-instance-identifier "$dbid" && hey available $_ || hey failed $_
  echo finished: $(date "+%Y-%m-%d %H:%M:%S")
}
alias waitavailable=rds-waitavailable

rds-waitstopped() {
  pickdbid
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
alias waitstopped=rds-waitstopped

rds-lessdblog() {
  local fname fsize ftmp1 ftmp2

  pickdbid
  [ -z "$dbid" ] && return

  fname=$(aws rds describe-db-log-files --db-instance-identifier "$dbid" | jq -r '.DescribeDBLogFiles | sort_by(.LastWritten) | reverse | .[].LogFileName' | peco)

  [ -z "$fname" ] && return

  ftmp1=$(mktemp)
  ftmp2=$(mktemp)

  fsize=$(aws rds describe-db-log-files --db-instance-identifier "$dbid" --filename-contains "$fname" --query "DescribeDBLogFiles[0].Size")
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
alias lessdblog=rds-lessdblog


rds-mkcls() {

  local engine enver minorv inscls cstpgchar pgfml cmd1 cmd2 okchar

  engine=$(for x in aurora aurora-mysql aurora-postgresql; do echo "$x"; done | peco)

  [ -z "$engine" ] && return

  # engine-version examples:
  # 5.6.10a
  # 5.6.mysql_aurora.1.19.0
  # 5.7.12
  # 5.7.mysql_aurora.2.03.2
  # 9.6.9
  # 10.6

  enver=$(aws rds describe-db-engine-versions --filters "Name=engine,Values=$engine" --query "DBEngineVersions[].EngineVersion" | jq -r '.[]' | sort | uniq | peco)

  [ -z "$enver" ] && return

  if [ "$enver" = "5.6.10a" ]; then
    echo -n 'engine-version [Default]: '; read minorv
  fi

  echo -n 'DB instance name: '; read dbid

  if [ -z "$dbid" ]; then
    echo "DB instance name is empty. abort"
    return
  fi

  if [ "$engine" = "aurora-postgresql" ]; then
    inscls="db.r5.large"
  else
    inscls="db.t3.small"
  fi

  echo -n 'new custom parameter group? [Y/n]: '; read cstpgchar

  if [ "$cstpgchar" != "n" ]; then
    pgfml=$(aws rds describe-db-engine-versions --engine $engine --engine-version $enver --query "DBEngineVersions[].[DBParameterGroupFamily]" --output text | head -n1)
  fi

  if [ -n "$pgfml" ]; then
    cmd1=$(echo aws rds create-db-cluster-parameter-group --db-cluster-parameter-group-name "$dbid" --db-parameter-group-family "$pgfml" --description "$dbid")
  fi

  clsid="${dbid}-cluster"

  cmd1=$(echo ${cmd1:+$cmd1 &&} aws rds create-db-cluster \
    --db-cluster-identifier "$clsid" \
    --engine "$engine" \
    --engine-version "$enver" \
    --database-name ${RDSCLI_DB_NAME} \
    ${cmd1:+--db-cluster-parameter-group-name "$dbid"} \
    --master-username "$RDSCLI_DB_USER" \
    --master-user-password "$RDSCLI_DB_PASSWORD")

  if [ -n "$pgfml" ]; then
    cmd2=$(echo aws rds create-db-parameter-group --db-parameter-group-name "$dbid" --db-parameter-group-family "$pgfml" --description "$dbid")
  fi

  cmd2=$(echo ${cmd2:+$cmd2 &&} aws rds create-db-instance \
    --db-instance-identifier "$dbid" \
    --db-cluster-identifier "$clsid" \
    --engine "$engine" \
    ${minorv:+--engine-version "${enver}.${minorv}"} \
    ${cmd2:+--db-parameter-group-name "$dbid"} \
    --no-auto-minor-version-upgrade \
    --publicly-accessible \
    --db-instance-class "$inscls")

  echo
  echo "the following command will be executed:"
  echo
  echo "$cmd1"
  echo
  echo "$cmd2"
  echo
  echo -n 'Is it ok? [Y/n]: '; read okchar

  if [ "$okchar" = "n" ]; then
    return
  fi

  eval "$cmd1"
  eval "$cmd2"
}
alias mkcls=rds-mkcls


rds-mkdb() {

# could be fetched with :
# aws rds describe-db-parameter-groups --query "DBParameterGroups[?contains(DBParameterGroupName,\`default.\`)].DBParameterGroupFamily" | jq -r '.[]' | perl -ne 'if (/((sqlserver|oracle)-.*)-[\d\.]+/) { print "$1\n" } else { print "$1\n" if /(\D+)\d/ }' | grep -v aurora | sort | uniq
  cat > /tmp/engines << EOF
mariadb
mysql
oracle-ee
oracle-se
oracle-se1
oracle-se2
postgres
sqlserver-ee
sqlserver-ex
sqlserver-se
sqlserver-web
EOF

  local engine version cstpgchar pgfml mazchar maz saz cmd okchar defdb iclass

  engine=$(peco < /tmp/engines)

  [ -z "$engine" ] && return

  version=$(aws rds describe-db-engine-versions --filters "Name=engine,Values=$engine" --query "DBEngineVersions[].EngineVersion" | jq -r '.[]' | peco)

  [ -z "$version" ] && return

  echo -n 'DB instance name: '; read dbid

  if [ -z "$dbid" ]; then
    echo "DB instance name is empty. abort"
    return
  fi

  echo -n 'new custom parameter group? [Y/n]: '; read cstpgchar

  if [ "$cstpgchar" != "n" ]; then
    pgfml=$(aws rds describe-db-engine-versions --engine $engine --engine-version $version --query "DBEngineVersions[].DBParameterGroupFamily" --output text | head -n1)
  fi

  echo -n 'Multi-AZ [y/N]: '; read mazchar

  if [ "$mazchar" = "y" ]; then
    maz=1
  else
    saz=1
  fi

  [ "$engine" = "oracle-ee" ] && defdb=ORCL || defdb=${RDSCLI_DB_NAME}
  [ "$engine" = "oracle-ee" ] && iclass=db.t3.medium || iclass=db.t3.small

  if [ -n "$pgfml" ]; then
    cmd=$(echo aws rds create-db-parameter-group --db-parameter-group-name "$dbid" --db-parameter-group-family "$pgfml" --description "$dbid")
  fi

  cmd=$(echo ${cmd:+$cmd &&} aws rds create-db-instance \
    --db-instance-identifier "$dbid" \
    --engine "$engine" \
    --engine-version "$version" \
    --db-instance-class "$iclass" \
    --allocated-storage 20 \
    --db-name "$defdb" \
    --master-username "$RDSCLI_DB_USER" \
    --master-user-password "$RDSCLI_DB_PASSWORD" \
    ${maz:+ --multi-az} \
    ${saz:+ --no-multi-az} \
    ${cmd:+--db-parameter-group-name "$dbid"} \
    --no-auto-minor-version-upgrade \
    --publicly-accessible)

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
alias mkdb=rds-mkdb

rds-moddb() {
	local cmd cmdopt fprops foldvals oldval newval morechar tempchar noimmediate optimmediate

	pickdbid

  [ -z "$dbid" ] && return

	# https://docs.aws.amazon.com/cli/latest/reference/rds/modify-db-instance.html
	# $ aws rds modify-db-instance --db-instance-identifier foo --generate-cli-skeleton input
	# $ aws rds modify-db-instance --db-instance-identifier foo --generate-cli-skeleton input | jq -r 'keys | .[]'
	# to insert a property into json with jq https://gist.github.com/joar/776b7d176196592ed5d8
	# echo -n -ApplyImmediately | perl -pne 's/([A-Z])/"-".lc($1)/ge'

	fprops=$(mktemp)
	aws rds modify-db-instance --db-instance-identifier foo --generate-cli-skeleton input | jq -r 'keys | .[]' > "$fprops"

	foldvals=$(mktemp)
  aws rds describe-db-instances --db-instance-identifier "$dbid" --query 'DBInstances[0]' > "$foldvals"

	cmd="aws rds modify-db-instance --db-instance-identifier ${dbid}"

	while [ "$morechar" != "n" ]; do
		prop=$(peco < "$fprops")

		[ -z "$prop" ] && break

	  case "$prop" in
	    ApplyImmediately)
				echo -n 'immediately? [Y/n]: '; read tempchar
				[ "$tempchar" = "n" ] && noimmediate=true
				;;
	    *)
				oldval=$(jq -r ".${prop}" "$foldvals")
				echo "setting : ${prop}"
				echo "current value : ${oldval}"
				echo -n 'new value : '; read newval
				cmdopt=$(echo -n "-${prop}" | perl -pne 's/([A-Z])/"-".lc($1)/ge')
				[ -n "$newval" ] && cmd="$cmd \\"$'\n'"${cmdopt} ${newval}"
				;;
	  esac

		echo -n 'more? [Y/n]: '; read morechar
	done

	optimmediate=$($noimmediate && echo "--no-apply-immediately" || echo "--apply-immediately")
	cmd="$cmd \\"$'\n'"$optimmediate"

	eval_confirm "$cmd"
}
alias moddb=rds-moddb


# user/password must be defined as environment variables
# export RDSCLI_DB_USER=username
# export RDSCLI_DB_PASSWORD=password
# export RDSCLI_DB_NAME=dbname
#
# make sure clients are available
# which mysql psql sqlplus mssql-cli
rds-condb() {
  local engine endpoint dbname cmd

  pickdbid

  [ -z "$dbid" ] && return

  aws rds describe-db-instances --db-instance-identifier "$dbid" --query 'DBInstances[].[Engine,Endpoint.Address]' --output text 2>/dev/null | read -r engine endpoint

  [ "$engine" = "None" -o "$endpoint" = "None" ] && return

  case "$engine" in
    "mariadb"|"mysql"|"aurora"|"aurora-mysql" )
      # user/password are defined in ~/.my.cnf
      cmd="mysql -h ${endpoint} ${RDSCLI_DB_NAME}"
      ;;
    "oracle-ee"|"oracle-se"|"oracle-se1"|"oracle-se2" )
      cmd="sqlplus ${RDSCLI_DB_USER}/${RDSCLI_DB_PASSWORD}@${endpoint}/ORCL"
      ;;
    "postgres"|"aurora-postgresql" )
      # user/password are defined in ~/.pgpass
      cmd="psql -h ${endpoint} -U ${RDSCLI_DB_USER} ${RDSCLI_DB_NAME}"
      ;;
    "sqlserver-ee"|"sqlserver-ex"|"sqlserver-se"|"sqlserver-web" )
      # password is defined as environment variable MSSQL_CLI_PASSWORD
      cmd="mssql-cli -d ${RDSCLI_DB_NAME} -U ${RDSCLI_DB_USER} -S ${endpoint}"
      ;;
    * )
      echo "unknown engine: $engine"
      ;;
  esac

  [ -z "$cmd" ] && return
  echo "$cmd"
  echo
  eval "$cmd"
}
alias condb=rds-condb

# list available functions
rds() {
	local cmds
	cmds="$(declare -f | grep -- '()' | cut -d' ' -f1 | grep -vE '^_' | grep -- 'rds-' | perl -pne 's/rds-//')"
	if [ -z "$1" -o $(echo "$cmds" | grep -E "^$1\$" | wc -l) -eq 0 ]; then
		echo "Commnd '$1' was not found. Here are the available commands."
		echo "------------------------"
		echo "$cmds"
		return
	fi
	eval "$@"
}
