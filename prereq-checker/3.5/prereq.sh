#!/bin/bash


## Resource size for 3.3 **No change for 3.5**

#These defaults are given in section 'Hardware requirement totals for AI Manager only' of the
#link https://www.ibm.com/docs/en/cloud-paks/cloud-pak-watson-aiops/3.3.1?topic=requirements-ai-manager
#Minimum resource values for small profile install
NODE_COUNT_SMALL_3_3=3
VCPU_SMALL_3_3=56
MEMORY_SMALL_3_3=142
#These defaults are given in section 'Hardware requirement totals for AI Manager only' of the
#link https://www.ibm.com/docs/en/cloud-paks/cloud-pak-watson-aiops/3.3.1?topic=requirements-ai-manager
#Minimum resource values for large profile install
NODE_COUNT_LARGE_3_3=6
VCPU_LARGE_3_3=144
MEMORY_LARGE_3_3=324


## Resource size for 3.2
#These defaults are given in section 'Hardware requirement totals for AI Manager only' of the 
#link https://www.ibm.com/docs/en/cloud-paks/cloud-pak-watson-aiops/3.2.1?topic=requirements-ai-manager
#Minimum resource values for small profile install
NODE_COUNT_SMALL_3_2=3
VCPU_SMALL_3_2=48
MEMORY_SMALL_3_2=132
#These defaults are given in section 'Hardware requirement totals for AI Manager only' of the 
#link https://www.ibm.com/docs/en/cloud-paks/cloud-pak-watson-aiops/3.2.1?topic=requirements-ai-manager
#Minimum resource values for large profile install
NODE_COUNT_LARGE_3_2=6
VCPU_LARGE_3_2=144
MEMORY_LARGE_3_2=324
 
log () {
   local log_tracing_prefix=$1
   local log_message=$2
   local log_options=$3

   if [[ ! -z $log_options ]]; then
      echo $log_options "$log_tracing_prefix $log_message"
   else
      echo "$log_tracing_prefix $log_message"
   fi
}

initialize() {

command="oc"
notop=""
adm="adm"
unitNotSupported="false"

# Tracing prefixes
INFO="[INFO]"
WARNING="[WARNING]"
ERROR="[ERROR]"

# For Summary method
OCP_VER_RES=""
STORAGE_PROVIDER_RES=""
NP_RES=""
INT_REG_RES=""
PROFILE_RES=""
PS_RES=""

warn_color="\x1b[33m"
fail_color="\x1b[31m"
pass_color="\e[32m"
color_end="\x1b[0m"

fail_msg=`printf "$fail_color FAIL $color_end"`
pass_msg=`printf "$pass_color PASS $color_end\n"`
warning_msg=`printf "$warn_color WARNING $color_end"`
skip_msg=`printf "$warn_color SKIP $color_end"`
}

display_help() {
   echo "**************************************** Usage ********************************************"
   echo
   echo " This script ensures that you have met the technical prerequisites for IBM Cloud Pak for AIOps version 3.5 ."
   echo
   echo " Before you run this script, you will need: "
   echo " 1. OpenShift (oc) command line interface (CLI)"
   echo " 2. Must be logged in to your cluster with oc login"
   echo " 3. Must be in the project (namespace) you have installed or will install the product in"
   echo
   echo " Usage:"
   echo " ./prereq.sh -h"
   echo "  -h Prints out the help message"
   echo " ./prereq.sh -u"
   echo "  -u Runs the upgrade check"
   echo " ./prereq.sh -s"
   echo "  -s Skips confirmation and installs upgrade requirements when available"
   echo " ./prereq.sh -o"
   echo "  -o Skips storageclass checks when using alternate storage providers"
   echo "*******************************************************************************************"
}

# Upgrade: Check if the user is doing an upgrade
checkUpgrade () {
  echo
    log $INFO "Starting IBM Cloud Pak for Watson AIOps AI Manager upgrade checker..."
  echo
  ORCHESTRATOR_UPGRADE="true"

  OPS_NAMESPACE="openshift-operators"
  INSTALL_NAMESPACE=`oc project -q`

  ORCHESTRATOR_CHECK1=`oc get subscription.operator --ignore-not-found -n $INSTALL_NAMESPACE -o=jsonpath="{range .items[*]}{.spec.name}{'\n'}{end}" | grep ibm-aiops-orchestrator`

  ORCHESTRATOR_CHECK2=`oc get subscription.operator --ignore-not-found -n $OPS_NAMESPACE -o=jsonpath="{range .items[*]}{.spec.name}{'\n'}{end}" | grep ibm-aiops-orchestrator`

  if [[ $ORCHESTRATOR_CHECK1 || $ORCHESTRATOR_CHECK2 ]] ; then
    checkIAFSubs
  fi
}

# Upgrade: Check IAF subscription
checkIAFSubs () {
NUM_SUBS=`oc get subscription.operator --ignore-not-found -n $OPS_NAMESPACE -o=jsonpath="{range .items[*]}{.spec.name}{'\n'}{end}" | grep ibm-automation | wc -l || true`
  if [ $NUM_SUBS -eq 5 ] ; then
    checkIAFSubVersion
  fi

  if [ $NUM_SUBS -eq 0 ] ; then
  OPS_NAMESPACE=$INSTALL_NAMESPACE
  NUM_SUBS=`oc get subscription.operator --ignore-not-found -n $OPS_NAMESPACE  -o=jsonpath="{range .items[*]}{.spec.name}{'\n'}{end}" | grep ibm-automation |wc -l || true`
    if [ $NUM_SUBS -eq 0 ] ; then
      log $ERROR "Unable to check IAF version. Please ensure that you are in the installation namespace."
      return 1
    fi
    if [ $NUM_SUBS -eq 5 ] ; then
      checkIAFSubVersion
    fi
  fi
}

# Upgrde: Check IAF version
checkIAFSubVersion () {
    oc get subscription.operator -n $OPS_NAMESPACE -o=jsonpath="{range .items[*]}{.spec.name}{' '}{.spec.channel}{' '}{.metadata.name}{'\n'}{end}" | while read LINE
    do
        OP_NAME=`echo $LINE | awk '{print $1}'`
        OP_CHANNEL=`echo $LINE | awk '{print $2}'`
        OP_METANAME=`echo $LINE | awk '{print $3}'`
        case $OP_NAME in
          ibm-automation|ibm-automation-core|ibm-automation-elastic|ibm-automation-eventprocessing|ibm-automation-flink)
            if [ "$OP_CHANNEL" = "v1.3" ]; then
              log $INFO "IAF Version is up to date with the latest 1.3 version. Install is ready for upgrade."
              return 0
            fi
            if [[ "$OP_CHANNEL" = "v1.2"  && "$SKIP_CONFIRM" == "true" ]]; then
              oc patch subscription.operator $OP_METANAME -n $OPS_NAMESPACE --type='json' -p='[{"op": "replace", "path": "/spec/channel", "value": "v1.3"}]'
            fi
            if [[ "$OP_CHANNEL" = "v1.2" ]]; then
              log $INFO "IAF Version needs to be upgraded to the latest 1.3 version. Please update the IAF subscription to v1.3 and try running the script again."
              return 1
            fi
        esac
    done
  exit 0
}

# Add options as needed
while getopts 'hsuo' opt; do
  case "$opt" in
    h)
      display_help
      exit 0
      ;;
    u)
      checkUpgrade
      ;;
    s)
      SKIP_CONFIRM="true" && checkUpgrade
      ;;
    o)
      SKIP_STORAGE_CHECK="true"
      ;;
  esac
done
shift "$(($OPTIND -1))"

# Verify oc is installed & we are logged into the cluster
if ! [ -x "$(command -v oc)" ]; then
  log $ERROR "oc CLI is not installed.  Please install the oc CLI and try running the script again."
  exit 1
fi

oc project
if [ $? -gt 0 ]; then
  log $ERROR "oc login required.  Please login to the cluster and try running the script again."
  exit 1
fi

echo
log $INFO "Starting IBM Cloud Pak for Watson AIOps AI Manager prerequisite checker v3.5..."
echo

# This function checks to see if user's OCP version meets our requirements by checking if 
# substring "4.6", "4.8", and "4.10" is in variable OCP_VER.
function checkOCPVersion {
  
  OCP_VER=$(oc get clusterversion version -o=jsonpath='{.status.desired.version}')

  ODF_STORAGE=$(oc get storageclass ocs-storagecluster-cephfs)

  OCP_MINOR_VER=`echo $OCP_VER | awk '{split($0,a,"."); print a[3]}'`
  
  echo
  startEndSection "Openshift Container Platform Version Check"
  log $INFO "Checking OCP Version. Compatible Versions of OCP are v4.6, v4.8, and v4.10."
  
  if [[ $OCP_VER == *"4.6"* || $OCP_VER == *"4.8"* || $OCP_VER == *"4.10"* ]]; then
    if [[ $OCP_VER == "4.8"* ]]; then
      if [[ $OCP_MINOR_VER -ge 43 && -n $ODF_STORAGE ]]; then
        log $INFO "OCP Version $OCP_VER is compatible with IBM Cloud Pak for Watson AIOps AI Manager"
        OCP_VER_RES=$pass_msg
        return 0
      elif [[ $OCP_MINOR_VER -le 43 && -n $ODF_STORAGE ]]; then
        log $INFO "OCP Version $OCP_VER is not compatible with IBM Cloud Pak for Watson AIOps AI Manager. If you are using ODF storage, 4.10.43 is the miniumum supported level"
        OCP_VER_RES=$fail_msg
        return 1
      else
        log $INFO "OCP Version $OCP_VER is compatible with IBM Cloud Pak for Watson AIOps AI Manager."
        OCP_VER_RES=$pass_msg
        return 0
      fi
    fi
    if [[ $OCP_VER == "4.10"* ]]; then
      if [[ $OCP_MINOR_VER -ge 17 && -n $ODF_STORAGE ]];then
        log $INFO "OCP Version $OCP_VER is compatible with IBM Cloud Pak for Watson AIOps AI Manager"
        OCP_VER_RES=$pass_msg
        return 0
      elif [[ $OCP_MINOR_VER -lt 17 && -n $ODF_STORAGE ]] ;then
        log $INFO "OCP Version $OCP_VER is not compatible with IBM Cloud Pak for Watson AIOps AI Manager. If you are using ODF storage, 4.10.17 is the miniumum supported level"
        OCP_VER_RES=$fail_msg
        return 1
      else
        log $INFO "OCP Version $OCP_VER is compatible with IBM Cloud Pak for Watson AIOps AI Manager."
        OCP_VER_RES=$pass_msg
        return 0
      fi
    fi
    log $INFO "OCP Version $OCP_VER is compatible with IBM Cloud Pak for Watson AIOps AI Manager"
    OCP_VER_RES=$pass_msg
    startEndSection "Openshift Container Platform Version Check"
    return 0
  else
    log $ERROR "OCP Version is incompatible. Required Version: v4.6.*, v4.8.*, or v4.10.*"
    log $ERROR "Your Version: v$OCP_VER"
    echo
    OCP_VER_RES=$fail_msg
    startEndSection "Openshift Container Platform Version Check"
    return 1
  fi
}

# Check for entitlement or global pull secret
checkEntitlementSecret () {
  
  SECRET_NAME="ibm-entitlement-key"
  ENTITLEMENT_SECRET=$(oc get secret | grep $SECRET_NAME)
  GLOBAL_PULL_SECRET=$(oc get secret pull-secret -n openshift-config)

  echo
  startEndSection "Entitlement Pull Secret"
  log $INFO "Checking whether the Entitlement secret or Global pull secret is configured correctly."
  

  if [[ -z $ENTITLEMENT_SECRET && -z $GLOBAL_PULL_SECRET ]] ; then
    log $ERROR "Ensure that you have either a '$SECRET_NAME' secret or a global pull secret 'pull-secret' configured in the namespace 'openshift-config'."
    PS_RES=$fail_msg
    startEndSection "Entitlement Pull Secret"
    return 1
  else
    createTestJob
  fi
}

createTestJob () {
  JOB_NAME="cp4waiops-entitlement-key-test-job"

  log $INFO "Checking if the job '$JOB_NAME' already exists."
  if [ `oc get job $JOB_NAME| wc -l` -gt 0  ]; then
    oc delete job $JOB_NAME
    sleep 10
  else
    log $INFO "The job with name '$JOB_NAME' was not found, so moving ahead and creating it."
  fi

  if [[ $ENTITLEMENT_SECRET ]] ; then
    log $INFO "Creating the job '$JOB_NAME' "
    cat <<EOF | oc apply -f -
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: cp4waiops-entitlement-key-test-job
    spec:
      parallelism: 1
      completions: 1
      template:
        metadata:
          name: pi
        spec:
          affinity:
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                  - matchExpressions:
                    - key: kubernetes.io/arch
                      operator: In
                      values:
                        - amd64
          imagePullSecrets:
          - name: ibm-entitlement-key
          containers:
          - name: testimage
            image: cp.icr.io/cp/cp4waiops/ai-platform-api-server@sha256:90ba27a8b8a0dbbab31f34040e71aebc0738539e57831097fd787d9909a14740

            imagePullPolicy: Always
            command: [ "echo", "SUCCESS" ]
          restartPolicy: OnFailure
EOF
  else
    log $INFO "Creating the job '$JOB_NAME' "
    cat <<EOF | oc apply -f -
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: cp4waiops-entitlement-key-test-job
    spec:
      parallelism: 1
      completions: 1
      template:
        metadata:
          name: pi
        spec:
          affinity:
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                  - matchExpressions:
                    - key: kubernetes.io/arch
                      operator: In
                      values:
                        - amd64
          containers:
          - name: testimage
            image: cp.icr.io/cp/cp4waiops/ai-platform-api-server@sha256:90ba27a8b8a0dbbab31f34040e71aebc0738539e57831097fd787d9909a14740

            imagePullPolicy: Always
            command: [ "echo", "SUCCESS" ]
          restartPolicy: OnFailure
EOF
  fi
  sleep 3
  checkEntitlementCred
}

checkEntitlementCred () {
  
  SLEEP_LOOP=5s
  IMAGE_PULL_STATUS_FLAG="false"
  log $INFO "Verifying if the job '$JOB_NAME' completed successfully.."
  POD_NAME=$(oc get pod -o name | grep $JOB_NAME)

  if [[ ! -z $POD_NAME ]];then
    LOOP_COUNT=0
    while [ $LOOP_COUNT -lt 25 ]
    do
        phase_status=$(oc get $POD_NAME -o jsonpath='{.status.phase}')
        if [[ $phase_status == "Succeeded" ]];then
          container_status=$(oc get $POD_NAME -o jsonpath='{.status.containerStatuses[0].state.terminated.reason}')
          if [[ "$container_status" != "ErrImagePull" && "$container_status" != "ImagePullBackOff" ]]; then
            if [[ "$container_status" == "Completed" ]]; then
                image_pull_status_flag="true"
                break
            fi
          fi
        elif [[ $phase_status == "Pending" ]];then
          container_status=$(oc get $POD_NAME -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}')
          if [[ "$container_status" == "ErrImagePull" || "$container_status" == "ImagePullBackOff" ]]; then
            image_pull_status_flag="false" 
          fi
        fi
        # log $INFO "Waiting for $SLEEP_LOOP, and checking the job '$JOB_NAME' status again"
        sleep $SLEEP_LOOP
        LOOP_COUNT=`expr $LOOP_COUNT + 1`
    done
  else
    log $ERROR "Some error occured while '$JOB_NAME' job creation for testing entitlement secret configuration."
    startEndSection "Entitlement Pull Secret"
    exit 1
  fi
  
  #Checking the job pod logs, where we chose to just print 'SUCCESS' message.
  if [[ "$image_pull_status_flag" == "true" ]]; then
     logs_status=$(oc logs $POD_NAME)
     if [[ $logs_status == "SUCCESS"  ]];then
        log $INFO "SUCCESS! Entitlement secret is configured correctly."
        PS_RES=$pass_msg
     else
        log $ERROR "Some error occured in validating job '$JOB_NAME' logs, error validating the entitlement secret"
        PS_RES=$fail_msg
     fi
  else
     PS_RES=$fail_msg
     log $ERROR "The pod '$POD_NAME' failed with container_status='$container_status'"
     log $ERROR "Entitlement secret is not configured correctly."
  fi
  
  #cleaning the job in case if script reaches here.
  oc delete job $JOB_NAME
  startEndSection "Entitlement Pull Secret"
}

function checkODF {
  ODF_PODS=$1
  printf "\nChecking Openshift Data Foundation Configuration...\n"
  printf "Verifying if Red Hat Openshift Data Foundation pods are in \"Running\" or \"Completed\" status\n"

  for p in "${ODF_PODS[@]}"; do
    podStatus=$(oc get pod $p -n openshift-storage -o jsonpath='{.status.phase}')
    if [[ "$podStatus" == "Running" || "$podStatus" == "Succeeded" ]]; then
      continue
    else
      log $ERROR "Pod in openshift-storage project namespace found not \"Running\" or \"Completed\": $p"
      STORAGE_PROVIDER_RES=$fail_msg
      return 1
    fi
  done

  log $INFO "Pods in openshift-storage project are \"Running\" or \"Completed\""

  ODF_STORAGECLASSES=("ocs-storagecluster-ceph-rbd" "ocs-storagecluster-cephfs" "openshift-storage.noobaa.io")
  for s in "${ODF_STORAGECLASSES[@]}"; do
    oc get storageclass $s > /dev/null 2>&1
    if [[ "$?" == "0" ]]; then
      log $INFO "$s exists."
    else
      log $ERROR "$s does not exist."
      STORAGE_PROVIDER_RES=$fail_msg
      return 1
    fi
  done

  STORAGE_PROVIDER_RES=$pass_msg
  return 0
}

function checkPortworx {
  PORTWORX_WARNING="false"
  printf "\nChecking Portworx Configuration...\n"
  printf "Checking for storageclass \"portworx-fs\"...\n"
  
  oc get storageclass portworx-fs > /dev/null 2>&1
  if [[ "$?" == "0" ]]; then
    log $INFO "StorageClass \"portworx-fs\" exists."
  else
    PORTWORX_WARNING="true"
    echo
    log $WARNING "StorageClass \"portworx-fs\" does not exist. See \"Portworx Storage\" section in https://ibm.biz/storage_consideration_350 for details.\n"
  fi

  printf "Checking for storageclass \"portworx-aiops\"...\n"
  oc get storageclass portworx-aiops > /dev/null 2>&1
  if [[ "$?" == "0" ]]; then
    log $INFO "StorageClass \"portworx-aiops\" exists."
  else
    PORTWORX_WARNING="true"
    echo
    log $WARNING "StorageClass \"portworx-aiops\" does not exist. See \"Portworx Storage\" section in https://ibm.biz/storage_consideration_350 for details.\n"
  fi
  
  if [[ "$PORTWORX_WARNING" == "false" ]]; then
    STORAGE_PROVIDER_RES=$pass_msg
  else
    STORAGE_PROVIDER_RES=$warning_msg
  fi
  
  return 0
}

function checkIBMCFileGoldGidStorage {
  printf "Checking for storageclass \"ibmc-file-gold-gid\"...\n"

  oc get storageclass ibmc-file-gold-gid > /dev/null 2>&1
  if [[ "$?" == "0" ]]; then
    log $INFO "StorageClass \"ibmc-file-gold-gid\" exists."
    IBMC_FILE_GOLD_GID="true"
    STORAGE_PROVIDER_RES=$pass_msg
  else
    log $WARNING "StorageClass \"ibmc-file-gold-gid\" does not exist. See \"Storage\" section in https://ibm.biz/storage_consideration_350 for details.\n"
  fi

  return 0
}

function checkStorage {
  ODF_FOUND="false"
  PORTWORX_FOUND="false"
  IBMC_FILE_GOLD_GID_FOUND="false"


  if [[ $SKIP_STORAGE_CHECK == "true" ]]; then
    echo
    startEndSection "Storage Provider"
    log $INFO "Skipping storage provider check"
    startEndSection "Storage Provider"
    STORAGE_PROVIDER_RES=$skip_msg
    return 0
  fi

  echo
  startEndSection "Storage Provider"
  log $INFO "Checking storage providers"

  # Check if Portworx, ODF, or IBMC-file-gold-gid exist
  STORAGE_CLUSTER_NAMES=$(oc get storagecluster -n kube-system --ignore-not-found=true --no-headers=true | awk '{print $1}')
  for sc in "${STORAGE_CLUSTER_NAMES[@]}"; do
    scPhase=$(oc get storagecluster $sc -n kube-system -o jsonpath='{.status.phase}')
    if [[ "$scPhase" == "Online"  ]]; then
      log $INFO "Portworx Found. StorageCluster instance \"$sc\" is Online."
      PORTWORX_FOUND="true"
    else
      echo
      log $WARNING "StorageCluster instance is not Online. In order for Portworx to work, an instance of StorageCluster must have a status of \"Online\"."
      PORTWORX_FOUND="false"
    fi
    break
  done

  ODF_PODS=($(oc get pods -n openshift-storage --no-headers=true | awk '{print $1}'))
  if [[ "$ODF_PODS" == "" ]]; then
    echo
    log $WARNING "Openshift Data Foundation not running."
    ODF_FOUND="false"
  else
    log $INFO "Openshift Data Foundation found."
    ODF_FOUND="true"
  fi

  IBMC_FILE_GOLD_GID=$(oc get storageclass ibmc-file-gold-gid)
  if [[ "$IBMC_FILE_GOLD_GID" == "" ]]; then
    echo
    log $WARNING "ibmc-file-gold-gid is not running."
    IBMC_FILE_GOLD_GID="false"
  else
    IBMC_FILE_GOLD_GID="true"
  fi


  if [[ "$PORTWORX_FOUND" == "false" && "$ODF_FOUND" == "false" && "$IBMC_FILE_GOLD_GID" == "false" ]]; then
    log $ERROR "At least one of the three Storage Providers are required"
    log $ERROR "The supported Storage Providers are Portworx, Openshift Data Foundation, or IBMC File Gold Gid. See https://ibm.biz/storage_consideration_350 for details."
    STORAGE_PROVIDER_RES=$fail_msg
    startEndSection "Storage Provider"
    return 1
  elif [[ "$PORTWORX_FOUND" == "true" && "$ODF_FOUND" == "false" && "$IBMC_FILE_GOLD_GID" == "false" ]]; then
    checkPortworx
  elif [[ "$PORTWORX_FOUND" == "false" && "$ODF_FOUND" == "true" && "$IBMC_FILE_GOLD_GID" == "false" ]]; then
    checkODF $ODF_PODS
  elif [[ "$PORTWORX_FOUND" == "false" && "$ODF_FOUND" == "false" && "$IBMC_FILE_GOLD_GID" == "true" ]]; then
    checkIBMCFileGoldGidStorage
  elif [[ "$PORTWORX_FOUND" == "true" && "$ODF_FOUND" == "true" && "$IBMC_FILE_GOLD_GID" == "true"  ]]; then
    checkPortworx
    checkODF $ODF_PODS
    checkIBMCFileGoldGidStorage
  fi
  startEndSection "Storage Provider"
  return 0
}

function checkNetworkPolicy {
  endpointPubStrat=$(oc get ingresscontroller default -n openshift-ingress-operator -o jsonpath='{.status.endpointPublishingStrategy.type}')
  
  echo
  startEndSection "Network Policy"
  log $INFO "Checking Network Policy configuration"

  if [[ "$endpointPubStrat" == "HostNetwork" ]]; then    
    # A comparison will be run against two different expected labels. Certain versions of OC cli
    # have different outputs
    policygroupLabel=$(oc get namespace default -o jsonpath='{.metadata.labels}')
    expectedLabel="network.openshift.io/policy-group:ingress"   # Result in OC v4.4.13
    altExpectedLabel="\"network.openshift.io/policy-group\":\"ingress\"" # Result in OC v4.31+
    
    # Check if expectedLabel exists as a substring in policygroupLabel
    if [[ "$policygroupLabel" == *"$expectedLabel"* || "$policygroupLabel" == *"$altExpectedLabel"* ]]; then
      log $INFO "Namespace default has expected metadata label. Network policy configured correctly."
      NP_RES=$pass_msg
    else
      log $ERROR "Namespace default DOES NOT have the expected metadata label"
      printf "Please see https://ibm.biz/aiops_netpolicy_35 to configure a network policy\n"
      NP_RES=$fail_msg
      startEndSection "Network Policy"
      return 1
    fi
  else
    # ROKS -  Extra configuration is not required
    log $INFO "HostNetwork endpoint publishing strategy is not used."
    NP_RES=$pass_msg
  fi
  startEndSection "Network Policy"
  return 0
}

get_worker_node_list() {

  if [ -z "${all_node_list}" ] ; then
     all_node_list=`${command} get nodes | grep -v NAME | awk '{ print $1 }' | sort -V | tr "\n" ' ' | tr -s ' '`
  fi	
	
  if [ -z ${notop} ] ; then
     top=`${command} ${adm} top nodes`
  fi
  
  for node in ${all_node_list} ; do
      describe=`${command} describe node ${node} 2> /dev/null`
      NoSchedule=`echo ${describe} | grep NoSchedule`
      if [ -z "${NoSchedule}" ] ; then
         worker_node_count=$((${worker_node_count}+1))
      else
         master_node_count=$((${master_node_count}+1))
      fi
       total_nodes=$((${total_nodes}+1)) 
  done

}

convert_memory_in_MB() {

  local node_mem_raw=$1
  local node_mem_without_unit=$2

  #1 Kibibyte is equal to (2^10 / 10^6) megabytes.
  #https://www.gbmb.org/kib-to-mb
  KiToMB=$(awk "BEGIN{print 2 ^ 10 / 10 ^ 6}")
	
  #1 Mebibyte is equal to (2^20 / 10^6) megabytes.
  #https://www.gbmb.org/mib-to-mb
  MiToMB=$(awk "BEGIN{print 2 ^ 20 / 10 ^ 6}")
	
  #1 Gibibyte is equal to (2^30 / 10^6) megabytes.
  #https://www.gbmb.org/gib-to-mb
  GiToMB=$(awk "BEGIN{print 2 ^ 30 / 10 ^ 6}")

  #Requested memory unit can be Mi(Mebibyte) or Ki(Kibibyte), or Gi(Gibibytes) which is not the same everytime.
  #Hence we need to convert the given requested memory in MB for calculations.
  # To learn more about the different memory units, see https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
  mem_MB=0
  if [[ "${node_mem_raw}" =~ "Ki" ]] ; then
     mem_MB=$(awk "BEGIN{print $node_mem_without_unit * $KiToMB}")
  elif [[ "${node_mem_raw}" =~ "Mi" ]] ; then
     mem_MB=$(awk "BEGIN{print $node_mem_without_unit * $MiToMB}")
  elif [[ "${node_mem_raw}" =~ "Gi" ]] ; then
     mem_MB=$(awk "BEGIN{print $node_mem_without_unit * $GiToMB}")
  elif [[ "${node_mem_raw}" =~ "m" ]] ; then
     mem_MB=$(awk "BEGIN{print $node_mem_without_unit / 10 ^ 9 }")
  else
     unitNotSupported="true"
  fi
}

covert_cpu_unit() {

  local cpu_before_conversion=$1
    
  converted_cpu=0
  if [[ "${cpu_before_conversion}" =~ "m" ]] ; then
     converted_cpu=`echo ${cpu_before_conversion} | sed 's/[^0-9]*//g'`
  else
     converted_cpu=$((${cpu_before_conversion}*1000))
  fi
    
}

calculate_memory_unrequested() {
	
  #https://www.gbmb.org/kib-to-mb
  #1 Kibibyte is equal to (2^10 / 10^6) megabytes.
  KiToMB=$(awk "BEGIN{print 2 ^ 10 / 10 ^ 6}")
	
  #Allocatable raw memory of a node with unit value. eg 30998112Ki
  node_mem_raw_Ki=`echo ${node_resources} | awk '{ print $4 }'`
  node_mem_allocatable_Ki=`echo ${node_mem_raw_Ki} | sed 's/[^0-9]*//g'`

  #Allocatable memory converted in MB
  convert_memory_in_MB $node_mem_raw_Ki $node_mem_allocatable_Ki
  node_mem_allocatable_MB=$mem_MB
	
  #Requested memory for current node eg: 26958Mi or 30998112Ki
  node_mem_request_raw=`echo "${node_describe}" | grep 'memory ' -a | tail -1 | awk '{ print $2 }'`
  node_mem_request_without_unit=`echo ${node_mem_request_raw} | sed 's/[^0-9]*//g'`

  #Requested memory converted to MB
  convert_memory_in_MB $node_mem_request_raw $node_mem_request_without_unit
  node_mem_request_MB=$mem_MB
	
  #Available memory for new install in MB
  node_memory_unrequested_MB=$(awk "BEGIN{print $node_mem_allocatable_MB - $node_mem_request_MB}")

  #Total memory availale for new install
  total_memory_unrequested_MB=$(awk "BEGIN{print $total_memory_unrequested_MB + $node_memory_unrequested_MB}")

}

calculate_cpu_unrequested() {

  #Allocatable raw cpu from node resource
  node_cpu_raw=`echo ${node_resources} | awk '{ print $2 }'`
	
  #Requested cpu resource from node resource
  node_cpu_request=`echo "${node_describe}" | grep 'cpu ' -a | tail -1 | awk '{ print $2 }' `

  covert_cpu_unit $node_cpu_raw
  node_cpu_allocatable=$converted_cpu
    
  covert_cpu_unit $node_cpu_request
  node_cpu_request=$converted_cpu
    
  #Current node cpu resource that is available for anything new to be installed.
  node_cpu_unrequested=$((${node_cpu_allocatable}-${node_cpu_request}))
    
  #Total cpu resource of the cluster that is available for anything new to be installed.
  total_cpu_unrequested=$((${total_cpu_unrequested}+${node_cpu_unrequested}))

}

check_available_cpu_and_memory() {
  
  #Fetch all the nodes for current cluster
  get_worker_node_list

  #For each node calculate cpu and memory resource.
  for node in ${all_node_list} ; do
    node_describe=`${command} describe node ${node}`
    node_resources=`echo "${node_describe}" | grep 'Allocatable' -A 6 -a | egrep 'cpu|memory' -a | tr "\n" ' ' | tr -s ' '`
    
    #Calculate cpu resource available for each node
    calculate_cpu_unrequested

	#Calculate memory resource available for each node
	calculate_memory_unrequested
  done
  
  #100m CPU, 100 milliCPU, and 0.1 CPU are all the same. We calculate the cpu by dropping m hence we need to convert it back to 
  #vCPU = (total_cpu_unrequested / 1000)
  total_cpu_unrequested=$(awk "BEGIN{print $total_cpu_unrequested / 1000}")
  #Converting the floating point to nearest integer.
  total_cpu_unrequested=$( printf "%.0f" $total_cpu_unrequested )
  
  #Converting the memory from MB to GB , 1GB = 1024MB
  total_memory_unrequested_GB=$(awk "BEGIN{print $total_memory_unrequested_MB / 1024}")
  #Converting the floating point to nearest integer
  total_memory_unrequested_GB=$( printf "%.0f" $total_memory_unrequested_GB )
  
}

analyze_resource_display() {

# Display for upgrade
  if [[ ORCHESTRATOR_UPGRADE == "true" ]] ; then
    if [[ $worker_node_count -ge $(($NODE_COUNT_LARGE_3_3-$NODE_COUNT_LARGE_3_2)) ]]; then
      large_worker_node_count_string=`printf "$pass_color $worker_node_count $color_end\n"`
    else
      large_worker_node_count_string=`printf "$fail_color $worker_node_count $color_end\n"`
    fi

    if [[ $total_cpu_unrequested -ge $(($VCPU_LARGE_3_3-$VCPU_LARGE_3_2)) ]]; then
      large_total_cpu_unrequested_string=`printf "$pass_color $total_cpu_unrequested $color_end\n"`
    else
      large_total_cpu_unrequested_string=`printf "$fail_color $total_cpu_unrequested $color_end\n"`
    fi

    if [[ $total_memory_unrequested_GB -ge $(($MEMORY_LARGE_3_3-$MEMORY_LARGE_3_2)) ]]; then
      large_total_memory_unrequested_GB_string=`printf "$pass_color $total_memory_unrequested_GB $color_end\n"`
    else
      large_total_memory_unrequested_GB_string=`printf "$fail_color $total_memory_unrequested_GB $color_end\n"`
    fi

    if [[ $worker_node_count -ge $(($NODE_COUNT_SMALL_3_3-$NODE_COUNT_SMALL_3_2)) ]]; then
      small_worker_node_count_string=`printf "$pass_color $worker_node_count $color_end\n"`
    else
      small_worker_node_count_string=`printf "$fail_color $worker_node_count $color_end\n"`
    fi

    if [[ $total_cpu_unrequested -ge $(($VCPU_SMALL_3_3-$VCPU_SMALL_3_2)) ]]; then
      small_total_cpu_unrequested_string=`printf "$pass_color $total_cpu_unrequested $color_end\n"`
    else
      small_total_cpu_unrequested_string=`printf "$fail_color $total_cpu_unrequested $color_end\n"`
    fi

    if [[ $total_memory_unrequested_GB -ge $(($MEMORY_SMALL_3_3-$MEMORY_SMALL_3_2)) ]]; then
      small_total_memory_unrequested_GB_string=`printf "$pass_color $total_memory_unrequested_GB $color_end\n"`
    else
      small_total_memory_unrequested_GB_string=`printf "$fail_color $total_memory_unrequested_GB $color_end\n"`
    fi
  return 1
fi
## Display for regular install
if [[ $worker_node_count -ge $NODE_COUNT_LARGE_3_3 ]]; then
   large_worker_node_count_string=`printf "$pass_color $worker_node_count $color_end\n"`
else
   large_worker_node_count_string=`printf "$fail_color $worker_node_count $color_end\n"`
fi
  
if [[ $total_cpu_unrequested -ge $VCPU_LARGE_3_3 ]]; then
   large_total_cpu_unrequested_string=`printf "$pass_color $total_cpu_unrequested $color_end\n"`
else
   large_total_cpu_unrequested_string=`printf "$fail_color $total_cpu_unrequested $color_end\n"`
fi

if [[ $total_memory_unrequested_GB -ge $MEMORY_LARGE_3_3 ]]; then
   large_total_memory_unrequested_GB_string=`printf "$pass_color $total_memory_unrequested_GB $color_end\n"`
elif [[ $total_memory_unrequested_GB -le 0 && "$unitNotSupported" -eq "true"  ]]; then
   large_total_memory_unrequested_GB_string=`printf "$fail_color DNE $color_end\n"`
else
   large_total_memory_unrequested_GB_string=`printf "$fail_color $total_memory_unrequested_GB $color_end\n"`
fi

if [[ $worker_node_count -ge $NODE_COUNT_SMALL_3_3 ]]; then
   small_worker_node_count_string=`printf "$pass_color $worker_node_count $color_end\n"`
else
   small_worker_node_count_string=`printf "$fail_color $worker_node_count $color_end\n"`
fi
  
if [[ $total_cpu_unrequested -ge $VCPU_SMALL_3_3 ]]; then
   small_total_cpu_unrequested_string=`printf "$pass_color $total_cpu_unrequested $color_end\n"`
else
   small_total_cpu_unrequested_string=`printf "$fail_color $total_cpu_unrequested $color_end\n"`
fi
  
if [[ $total_memory_unrequested_GB -ge $MEMORY_SMALL_3_3 ]]; then
   small_total_memory_unrequested_GB_string=`printf "$pass_color $total_memory_unrequested_GB $color_end\n"`
elif [[ $total_memory_unrequested_GB -le 0 && "$unitNotSupported" -eq "true"  ]]; then
   small_total_memory_unrequested_GB_string=`printf "$fail_color DNE $color_end\n"`
else
   small_total_memory_unrequested_GB_string=`printf "$fail_color $total_memory_unrequested_GB $color_end\n"`
fi

}

checkSmallOrLargeProfileInstall() {
  
  echo
  startEndSection "Small or Large Profile Install Resources"
  log $INFO "Checking for cluster resources"
  echo
  check_available_cpu_and_memory
  
  analyze_resource_display

  if  [[ $ORCHESTRATOR_UPGRADE ]]; then
    log $INFO "==================================Upgrade Resource Summary====================================================="
    header=`printf "   %40s   |      %s      |     %s" "Additional Nodes" "Additional vCPU" "Additional Memory(GB)"`
    log $INFO "${header}"
    string=`printf "Upgrade Small profile(available/required)  [ %s/ %s ]   [ %s/ %s ]       [ %s/ %s ]" "$small_worker_node_count_string" "$(($NODE_COUNT_SMALL_3_3-$NODE_COUNT_SMALL_3_2))" "$small_total_cpu_unrequested_string" "$(($VCPU_SMALL_3_3-$VCPU_SMALL_3_2))" "$small_total_memory_unrequested_GB_string" "$(($MEMORY_SMALL_3_3-$MEMORY_SMALL_3_2))"`
    log $INFO "${string}"
    string=`printf "Upgrade Large profile(available/required)  [ %s/ %s ]   [ %s/ %s ]       [ %s/ %s ]" "$large_worker_node_count_string" "$(($NODE_COUNT_LARGE_3_3-$NODE_COUNT_LARGE_3_2))" "$large_total_cpu_unrequested_string" "$(($VCPU_LARGE_3_3-$VCPU_LARGE_3_2))" "$large_total_memory_unrequested_GB_string" "$(($MEMORY_LARGE_3_3-$MEMORY_LARGE_3_2))"`
    log $INFO "${string}"
    log $INFO "==================================Upgrade Resource Summary====================================================="

    if [[ ($worker_node_count -ge $(($NODE_COUNT_LARGE_3_3-$NODE_COUNT_LARGE_3_2))) && ($total_cpu_unrequested -ge $(($VCPU_LARGE_3_3-$VCPU_LARGE_3_2))) && ($total_memory_unrequested_GB -ge $(($MEMORY_LARGE_3_3-$MEMORY_LARGE_3_2)))  ]] ; then
      log $INFO "Cluster currently has resources available to upgrade Cloud Pak for Watson AIOps AI Manager"
    elif [[ $worker_node_count -ge $(($NODE_COUNT_SMALL_3_3-$NODE_COUNT_SMALL_3_2)) && ($total_cpu_unrequested -ge $(($VCPU_SMALL_3_3-$VCPU_SMALL_3_2))) && ($total_memory_unrequested_GB -ge $(($MEMORY_SMALL_3_3-$MEMORY_SMALL_3_2))) ]] ; then
      log $INFO "Cluster currently has resources available to upgrade Cloud Pak for Watson AIOps AI Manager"
      echo
    else
      log $ERROR "Cluster does not have required resources available to upgrade Cloud Pak for Watson AIOps AI Manager."
      echo
      PROFILE_RES=$fail_msg
      startEndSection "Small or Large Profile Install Resources"
      return 1
    fi
    PROFILE_RES=$pass_msg
    return 1
  fi

  
  log $INFO "==================================Resource Summary====================================================="
  header=`printf "   %40s   |      %s      |     %s" "Nodes" "vCPU" "Memory(GB)"`
  log $INFO "${header}"
  string=`printf "Small profile(available/required)  [ %s/ %s ]   [ %s/ %s ]       [ %s/ %s ]" "$small_worker_node_count_string" "$NODE_COUNT_SMALL_3_3" "$small_total_cpu_unrequested_string" "$VCPU_SMALL_3_3" "$small_total_memory_unrequested_GB_string" "$MEMORY_SMALL_3_3"`
  log $INFO "${string}"
  string=`printf "Large profile(available/required)  [ %s/ %s ]   [ %s/ %s ]       [ %s/ %s ]" "$large_worker_node_count_string" "$NODE_COUNT_LARGE_3_3" "$large_total_cpu_unrequested_string" "$VCPU_LARGE_3_3" "$large_total_memory_unrequested_GB_string" "$MEMORY_LARGE_3_3"`
  log $INFO "${string}"
  
  # Script need to output a message if memory cant be calculated. At the moment, it only supports Ki, Mi, Gi, and m.
  if [[ "$unitNotSupported" == "true" ]]; then
    log $WARNING "Cannot calculate memory because allocatable memory is using a unit that is not recognizable. This tool supports Ki, Gi, Mi, and m"
  fi

  log $INFO "==================================Resource Summary====================================================="
     
  if [[ ($worker_node_count -ge $NODE_COUNT_LARGE_3_3) && ($total_cpu_unrequested -ge $VCPU_LARGE_3_3) && ($total_memory_unrequested_GB -ge $MEMORY_LARGE_3_3)  ]] ; then
     log $INFO "Cluster currently has resources available to create a large profile of Cloud Pak for Watson AIOps AI Manager"
  elif [[ $worker_node_count -ge $NODE_COUNT_SMALL_3_3 && ($total_cpu_unrequested -ge $VCPU_SMALL_3_3) && ($total_memory_unrequested_GB -ge $MEMORY_SMALL_3_3) ]] ; then
     log $INFO "Cluster currently has resources available to create a small profile of Cloud Pak for Watson AIOps AI Manager"
     echo
  else
     log $ERROR "Cluster does not have required resources available to install Cloud Pak for Watson AIOps AI Manager."
     echo
     PROFILE_RES=$fail_msg
     startEndSection "Small or Large Profile Install Resources"
     return 1
  fi
  PROFILE_RES=$pass_msg
  startEndSection "Small or Large Profile Install Resources"
}

showSummary() {

  echo
  echo
  startEndSection "Prerequisite Checker Tool Summary"
  string=`printf "      [ %s ] Openshift Container Platform Version Check " "${OCP_VER_RES}"`
  printf "${string}\n"
  string=`printf "      [ %s ] Entitlement Pull Secret" "${PS_RES}"`
  printf "${string}\n"
  string=`printf "      [ %s ] Storage Provider\n" "${STORAGE_PROVIDER_RES}"`
  printf "${string}\n"
  string=`printf "      [ %s ] Network Policy" "${NP_RES}"`
  printf "${string}\n"
  string=`printf "      [ %s ] Small or Large Profile Install Resources" "${PROFILE_RES}"`
  printf "${string}\n"
  startEndSection "Prerequisite Checker Tool Summary"
}

startEndSection() {
  section=$1
  log $INFO "=================================${section}================================="
}

function main {
  initialize

  checkOCPVersion
  checkEntitlementSecret
  checkStorage
  checkNetworkPolicy
  checkSmallOrLargeProfileInstall

  showSummary
}

main
