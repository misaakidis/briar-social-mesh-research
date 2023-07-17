#!/usr/bin/env bash

# Save simulations root directory
CWD=`pwd`

# How many simulations to run in parallel
cpuCores=31

# Select which simulations to execute
traceanalysis=false
scenarios_public_mesh=false
scenarios_private_mesh=false
scenarios_stations=false
scenarios_briar=false
scenarios_hybrid=false
scenarios_mailboxes=false
scenarios_social=false

if [ -f "scenarios/scenarios.txt" ]; then
    echo "Found previous deployment. This script does not track active simulation processes across subsequent runs."
    echo "Make sure previous simulations have completed execution and you have archived their results."
    echo "Exiting..."
    exit 1
fi

# Compile ONE simulator with latest updates on routers, report generators and dataset-specific packages
./compile.sh

mkdir -p reports

send_notification() {
  local message="$1"
  echo ${message}
  echo ${message} >> reports/progress.txt

  # Implement custom logic for sending notifications
}


###############################################################################
# Declare datasets

# Initialize array with all datasets
allDatasets=("haggleoriginal" "haggleoriginalwithoutstations" "haggleoriginalhybridstations" "haggle" "hyccupsoriginal" "hyccups" "hyccupsonlycontacts" "malawi" "office")

declare -A datasetPath datasetHosts datasetEnd datasetCooldown

# crawdad / "uoi/haggle/one/cambridge-city-complete"
# https://ieee-dataport.org/open-access/crawdad-uoihaggle
# Based on Experiment 4 (cambridge/haggle/imote/content) of https://ieee-dataport.org/open-access/crawdad-cambridgehaggle-v-2009-05-29
datasetPath[haggleoriginal]="haggle-original"
datasetHosts[haggleoriginal]=54
datasetEnd[haggleoriginal]=987529
datasetCooldown[haggleoriginal]=$((datasetEnd[haggleoriginal] - 86400)) # 1 day

datasetPath[haggleoriginalwithoutstations]="haggle-original-without-stations"
datasetHosts[haggleoriginalwithoutstations]=36
datasetEnd[haggleoriginalwithoutstations]=987529
datasetCooldown[haggleoriginalwithoutstations]=$((datasetEnd[haggleoriginalwithoutstations] - 86400)) # 1 day

datasetPath[haggleoriginalhybridstations]="haggle-original-hybrid-stations"
datasetHosts[haggleoriginalhybridstations]=54
datasetEnd[haggleoriginalhybridstations]=987529
datasetCooldown[haggleoriginalhybridstations]=$((datasetEnd[[haggleoriginalhybridstations] - 86400)) # 1 day

datasetPath[haggle]="haggle-loop-67129-604800-5"
datasetHosts[haggle]=54
datasetEnd[haggle]=3005275
datasetCooldown[haggle]=$((datasetEnd[haggle] - 1209600)) # 2 weeks


# crawdad / "upb/hyccups"
# https://ieee-dataport.org/open-access/crawdad-upbhyccups
datasetPath[hyccupsoriginal]="hyccups-original"
datasetHosts[hyccupsoriginal]=73
datasetEnd[hyccupsoriginal]=5427862
datasetCooldown[hyccupsoriginal]=$((datasetEnd[hyccupsoriginal] - 432000)) # 5 days
# ./toolkit/hyccupsTraceConverter.pl -out ./datasets/"${datasetPath[hyccupsoriginal]}".txt ./datasets/hyccups/upb-hyccups-full_output.txt

datasetPath[hyccups]="hyccups-loop-0-4838400-3"
# Converted using ./toolkit/hyccupsTraceConverter.pl (options: -loops 3 -loopEnd 1335540236000)
# Parsing example: https://github.com/raduciobanu/mobemu/blob/master/src/mobemu/parsers/UPB.java#L211
datasetHosts[hyccups]=73
datasetEnd[hyccups]=14106341
datasetCooldown[hyccups]=$((datasetEnd[hyccups] - 4838400)) # 8 weeks
# Loop End = first trace timestamp + loop period = 1330701836 + 4838400 = 1335540236 * 1000 milliseconds
# ./toolkit/hyccupsTraceConverter.pl -out ./datasets/"${datasetPath[hyccups]}".txt -loops 3 -loopEnd 1335540236000 ./datasets/hyccups/upb-hyccups-full_output.txt

datasetPath[hyccupsonlycontacts]="hyccups-loop-0-4838400-3-only-contacts"
datasetHosts[hyccupsonlycontacts]=73
datasetEnd[hyccupsonlycontacts]=14106341
datasetCooldown[hyccupsonlycontacts]=$((datasetEnd[hyccupsonlycontacts] - 4838400)) # 8 weeks


# sociopatterns / "tnet_malawi_pilot"
# http://www.sociopatterns.org/datasets/contact-patterns-in-a-village-in-rural-malawi/
datasetPath[malawi]="malawi-loop-124461-604800-5"
datasetHosts[malawi]=86
datasetEnd[malawi]=3023999
datasetCooldown[malawi]=$((datasetEnd[malawi] - 1209600)) # 2 weeks


# sociopatterns / office 2nd deployment
# http://www.sociopatterns.org/datasets/contacts-in-a-workplace/
datasetPath[office]="office-loop-36241-604800-5"
datasetHosts[office]=92
datasetEnd[office]=3023599
datasetCooldown[office]=$((datasetEnd[office] - 1209600)) # 2 weeks


###############################################################################
# Declare settings

declare -A settingTTL settingBuffer settingTransmitSpeed settingNumOfDailyMsgsPerHost settingMsgSize settingWarmup

# Ideal setting (without TTL, small message size)
settingTTL[ideal]=35791394
settingBuffer[ideal]="150M"
settingTransmitSpeed[ideal]="600M" # Nodes can replicate their storage during a 1sec connection
settingNumOfDailyMsgsPerHost[ideal]=3
settingMsgInterval[ideal]="300,1500" # 5-25 mins
settingMsgSize[ideal]="1,2"
settingWarmup[ideal]=432000 # 5 days

# Realistic setting with long TTL
settingTTL[realistic]=4838000 # 8 weeks
settingBuffer[realistic]="150M"
settingTransmitSpeed[realistic]="250k" # 2Mbps
settingNumOfDailyMsgsPerHost[realistic]=3
settingMsgSize[realistic]="1k,5k"
settingWarmup[realistic]=432000 # 5 days

# Realistic setting with short TTL
settingTTL[realisticttl]=432000 # 5 days
settingBuffer[realisticttl]="150M"
settingTransmitSpeed[realisticttl]="250k" # 2Mbps
settingNumOfDailyMsgsPerHost[realisticttl]=3
settingMsgSize[realisticttl]="1k,5k"
settingWarmup[realisticttl]=432000 # 5 days

# Flood setting without TTL
settingTTL[flood]=35791394
settingBuffer[flood]="150M"
settingTransmitSpeed[flood]="250k"
settingNumOfDailyMsgsPerHost[flood]=15
settingMsgSize[flood]="1k,5k"
settingWarmup[flood]=432000 # 5 days

# Flood setting with short TTL
settingTTL[floodttl]=432000 # 5 days
settingBuffer[floodttl]="150M"
settingTransmitSpeed[floodttl]="250k"
settingNumOfDailyMsgsPerHost[floodttl]=15
settingMsgSize[floodttl]="1k,5k"
settingWarmup[floodttl]=432000 # 5 days


###############################################################################
# Declare hyccups message generator settings

declare -A hyccupsMsgSize hyccupsNumOfDailyMsgsPerHost

hyccupsMsgSize[ideal]="1,2"
hyccupsNumOfDailyMsgsPerHost[ideal]=3

hyccupsMsgSize[realistic]="1000,5000"
hyccupsNumOfDailyMsgsPerHost[realistic]=3

hyccupsMsgSize[realisticttl]="1000,5000"
hyccupsNumOfDailyMsgsPerHost[realisticttl]=3

hyccupsMsgSize[flood]="1000,5000"
hyccupsNumOfDailyMsgsPerHost[flood]=15

hyccupsMsgSize[floodttl]="1000,5000"
hyccupsNumOfDailyMsgsPerHost[floodttl]=15


###############################################################################
# Traceanalysis of datasets

# traceanalysis is imported as a git submodule
# To pull the source code, run `git submodule update --init --recursive`

# Running traceanalysis as a background process does not generate the expected output files

if $traceanalysis ; then
  
  for DATASET in "${allDatasets[@]}"; do
    mkdir -p reports/traceanalysis/$DATASET
    export DATASET_PATH="${datasetPath[$DATASET]}"
    export DATASET_HOSTS="${datasetHosts[$DATASET]}"
    export DATASET_END="${datasetEnd[$DATASET]}"

    cd reports/traceanalysis/$DATASET
    echo "Running traceanalysis on " $DATASET
    python3 -W ignore ../../../toolkit/traceanalysis/traceanalysis.py -n $DATASET_HOSTS -e $DATASET_END -s 60 -f ../../../datasets/${DATASET_PATH}.txt | tee report.txt
    echo
    cd ../../../
  done

fi


###############################################################################
# Public mesh scenarios for all datasets
# Using ONE's message generator

if $scenarios_public_mesh ; then

  datasets=("haggle" "hyccupsoriginal" "hyccups" "malawi" "office")
  settings=("ideal" "realistic" "realisticttl" "floodttl")
  routers=("EpidemicRouter") # Random send queue mode
  iterations=1

  export SCENARIO="public"

  for DATASET in "${datasets[@]}"; do
    mkdir -p scenarios/$SCENARIO/$DATASET

    export DATASET_NAME=$DATASET
    export DATASET_PATH="${datasetPath[$DATASET]}"
    export DATASET_HOSTS="${datasetHosts[$DATASET]}"
    export DATASET_HOSTS_GEN_MSGS="${datasetHosts[$DATASET]}"
    export DATASET_END="${datasetEnd[$DATASET]}"
    export DATASET_COOLDOWN="${datasetCooldown[$DATASET]}"

    for SETTING in "${settings[@]}"; do
      export SETTING
      export SETTING_TTL="${settingTTL[$SETTING]}"
      export SETTING_BUFFER="${settingBuffer[$SETTING]}"
      export SETTING_TRANSMIT_SPEED="${settingTransmitSpeed[$SETTING]}"
      export SETTING_MSG_SIZE="${settingMsgSize[$SETTING]}"
      export SETTING_WARMUP="${settingWarmup[$SETTING]}"

      # Compute message generation interval
      totalDailyMessages=$((DATASET_HOSTS * ${settingNumOfDailyMsgsPerHost[$SETTING]}))
      interval=$((24 * 60 * 60 / totalDailyMessages))
      threshold=$((interval / 5))
      minInterval=$((interval - threshold))
      maxInterval=$((interval + threshold))
      export SETTING_MSG_INTERVAL="$minInterval,$maxInterval"

      for ROUTER in "${routers[@]}"; do
          export SETTING_ROUTER=$ROUTER

          for ((i=1; i<=$iterations; i++)); do
            export ITERATION="0_0_${i}"
            scenarioFile=scenarios/$SCENARIO/$DATASET/${SETTING}_${ROUTER}_${ITERATION}.txt
            envsubst < scenario_template_with_msg_generator.txt > $scenarioFile
            echo "./one.sh -b 1 $scenarioFile" >> scenarios/scenarios.txt
          done
      done

    done
  done

fi


###############################################################################
# Stationary nodes scenarios (haggleoriginal)
# Using ONE's message generator

if $scenarios_stations ; then

  datasets=("haggleoriginal" "haggleoriginalwithoutstations" "haggleoriginalhybridstations")
  settings=("ideal" "realistic" "realisticttl" "floodttl")
  routers=("EpidemicRouter") # Random send queue mode
  iterations=1

  export SCENARIO="stations"

  for DATASET in "${datasets[@]}"; do
    mkdir -p scenarios/$SCENARIO/$DATASET

    export DATASET_NAME=$DATASET
    export DATASET_PATH="${datasetPath[$DATASET]}"
    export DATASET_HOSTS="${datasetHosts[$DATASET]}"
    export DATASET_HOSTS_GEN_MSGS=36
    export DATASET_END="${datasetEnd[$DATASET]}"
    export DATASET_COOLDOWN="${datasetCooldown[$DATASET]}"

    for SETTING in "${settings[@]}"; do
      export SETTING
      export SETTING_TTL="${settingTTL[$SETTING]}"
      export SETTING_BUFFER="${settingBuffer[$SETTING]}"
      export SETTING_TRANSMIT_SPEED="${settingTransmitSpeed[$SETTING]}"
      export SETTING_MSG_SIZE="${settingMsgSize[$SETTING]}"
      export SETTING_WARMUP=86400

      # Compute message generation interval
      totalDailyMessages=$((DATASET_HOSTS * ${settingNumOfDailyMsgsPerHost[$SETTING]}))
      interval=$((24 * 60 * 60 / totalDailyMessages))
      threshold=$((interval / 5))
      minInterval=$((interval - threshold))
      maxInterval=$((interval + threshold))
      export SETTING_MSG_INTERVAL="$minInterval,$maxInterval"

      for ROUTER in "${routers[@]}"; do
          export SETTING_ROUTER=$ROUTER

          for ((i=1; i<=$iterations; i++)); do
            export ITERATION="0_0_${i}"
            scenarioFile=scenarios/$SCENARIO/$DATASET/${SETTING}_${ROUTER}_${ITERATION}.txt
            envsubst < scenario_template_with_msg_generator.txt > $scenarioFile
            echo "./one.sh -b 1 $scenarioFile" >> scenarios/scenarios.txt
          done
      done

    done
  done

fi


###############################################################################
# Public mesh Hybrid nodes scenarios (hyccups)

if $scenarios_hybrid ; then
  export SCENARIO="hybrid"

  datasets=("hyccups")
  settings=("realistic")
  routers=("EpidemicRouter") # Random send queue mode
  iterations=2
  numOfHybridNodes=("5" "10" "20")

  for DATASET in "${datasets[@]}"; do
    mkdir -p scenarios/$SCENARIO/$DATASET

    export DATASET_NAME=$DATASET
    export DATASET_PATH="${datasetPath[$DATASET]}"
    export DATASET_HOSTS="${datasetHosts[$DATASET]}"
    export DATASET_END="${datasetEnd[$DATASET]}"
    export DATASET_COOLDOWN="${datasetCooldown[$DATASET]}"

    for SETTING in "${settings[@]}"; do
      export SETTING
      export SETTING_TTL="${settingTTL[$SETTING]}"
      export SETTING_BUFFER="${settingBuffer[$SETTING]}"
      export SETTING_TRANSMIT_SPEED="${settingTransmitSpeed[$SETTING]}"
      export SETTING_WARMUP="${settingWarmup[$SETTING]}"

      for ROUTER in "${routers[@]}"; do
        export SETTING_ROUTER=$ROUTER

        for ((i=1; i<=$iterations; i++)); do

          for numOfHybrids in "${numOfHybridNodes[@]}"; do
            export ITERATION="${numOfHybrids}_0_${i}"

            # Generate messages and hybrid node connections
            java -cp target social.HyccupsMsgCreator $numOfHybrids 0 ${i} "${hyccupsMsgSize[$SETTING]}" "${hyccupsNumOfDailyMsgsPerHost[$SETTING]}" false | sort -t$'\t' -k1 -n > scenarios/$SCENARIO/$DATASET/${SETTING}_${ROUTER}_${ITERATION}_messages.txt

            scenarioFile=scenarios/$SCENARIO/$DATASET/${SETTING}_${ROUTER}_${ITERATION}.txt
            envsubst < scenario_template.txt > $scenarioFile
            echo "./one.sh -b 1 $scenarioFile" >> scenarios/scenarios.txt
          done

        done
      
      done
    done
  done
fi


###############################################################################
# Public mesh Mailboxes scenarios (hyccups)

if $scenarios_mailboxes ; then
  export SCENARIO="mailbox"

  datasets=("hyccups")
  settings=("realistic")
  routers=("EpidemicRouter") # Random send queue mode
  iterations=2
  numOfMailboxNodes=("5" "10" "20")

  for DATASET in "${datasets[@]}"; do
    mkdir -p scenarios/$SCENARIO/$DATASET

    export DATASET_NAME=$DATASET
    export DATASET_PATH="${datasetPath[$DATASET]}"
    export DATASET_END="${datasetEnd[$DATASET]}"
    export DATASET_COOLDOWN="${datasetCooldown[$DATASET]}"

    for SETTING in "${settings[@]}"; do
      export SETTING
      export SETTING_TTL="${settingTTL[$SETTING]}"
      export SETTING_BUFFER="${settingBuffer[$SETTING]}"
      export SETTING_TRANSMIT_SPEED="${settingTransmitSpeed[$SETTING]}"
      export SETTING_WARMUP="${settingWarmup[$SETTING]}"

      for ROUTER in "${routers[@]}"; do
        export SETTING_ROUTER=$ROUTER

        for ((i=1; i<=$iterations; i++)); do

          for numOfMailboxes in "${numOfMailboxNodes[@]}"; do
            export ITERATION="0_${numOfMailboxes}_${i}"
            export DATASET_HOSTS=$((datasetHosts[$DATASET] + numOfMailboxes))

            # Generate messages and mailbox connections
            java -cp target social.HyccupsMsgCreator 0 $numOfMailboxes ${i} "${hyccupsMsgSize[$SETTING]}" "${hyccupsNumOfDailyMsgsPerHost[$SETTING]}" false | sort -t$'\t' -k1 -n > scenarios/$SCENARIO/$DATASET/${SETTING}_${ROUTER}_${ITERATION}_messages.txt

            scenarioFile=scenarios/$SCENARIO/$DATASET/${SETTING}_${ROUTER}_${ITERATION}.txt
            envsubst < scenario_template.txt > $scenarioFile
            echo "./one.sh -b 1 $scenarioFile" >> scenarios/scenarios.txt
          done

        done
      
      done
    done
  done
fi


###############################################################################
# Current Briar: Single-hop between contacts with hybrid nodes and mailboxes (hyccupsonlycontacts)

if $scenarios_briar ; then

  export SCENARIO="briar"

  datasets=("hyccupsonlycontacts")
  settings=("realistic")
  routers=("EpidemicRouterBriar") # Random send queue mode
  iterations=1
  numOfHybridNodes=("0" "10" "20")
  numOfMailboxNodes=("0" "10" "20")

  for DATASET in "${datasets[@]}"; do
    mkdir -p scenarios/$SCENARIO/$DATASET

    export DATASET_NAME=$DATASET
    export DATASET_PATH="${datasetPath[$DATASET]}"
    export DATASET_HOSTS="${datasetHosts[$DATASET]}"
    export DATASET_END="${datasetEnd[$DATASET]}"
    export DATASET_COOLDOWN="${datasetCooldown[$DATASET]}"

    for SETTING in "${settings[@]}"; do
      export SETTING
      export SETTING_TTL="${settingTTL[$SETTING]}"
      export SETTING_BUFFER="${settingBuffer[$SETTING]}"
      export SETTING_TRANSMIT_SPEED="${settingTransmitSpeed[$SETTING]}"
      export SETTING_WARMUP="${settingWarmup[$SETTING]}"

      for ROUTER in "${routers[@]}"; do
        export SETTING_ROUTER=$ROUTER

        for ((i=1; i<=$iterations; i++)); do
          for numOfHybrids in "${numOfHybridNodes[@]}"; do
            for numOfMailboxes in "${numOfMailboxNodes[@]}"; do
              export ITERATION="${numOfHybrids}_${numOfMailboxes}_${i}"
              export DATASET_HOSTS=$((datasetHosts[$DATASET] + numOfMailboxes))
          
              # Generate messages and highly available nodes connections
              java -cp target social.HyccupsMsgCreator ${numOfHybrids} ${numOfMailboxes} ${i} "${hyccupsMsgSize[$SETTING]}" "${hyccupsNumOfDailyMsgsPerHost[$SETTING]}" true | sort -t$'\t' -k1 -n > scenarios/$SCENARIO/$DATASET/${SETTING}_${ROUTER}_${ITERATION}_messages.txt

              scenarioFile=scenarios/$SCENARIO/$DATASET/${SETTING}_${ROUTER}_${ITERATION}.txt
              envsubst < scenario_template.txt > $scenarioFile
              echo "./one.sh -b 1 $scenarioFile" >> scenarios/scenarios.txt
            done
          done
        done
      
      done
    done
  done
fi


###############################################################################
# Private mesh with hybrid nodes and mailboxes (hyccupsonlycontacts)

if $scenarios_private_mesh ; then

  export SCENARIO="private"

  datasets=("hyccupsonlycontacts")
  settings=("ideal" "realistic" "realisticttl" "floodttl")
  routers=("EpidemicRouter") # Random send queue mode
  iterations=1
  numOfHybridNodes=("0" "10" "20")
  numOfMailboxNodes=("0" "10" "20")

  for DATASET in "${datasets[@]}"; do
    mkdir -p scenarios/$SCENARIO/$DATASET

    export DATASET_NAME=$DATASET
    export DATASET_PATH="${datasetPath[$DATASET]}"
    export DATASET_HOSTS="${datasetHosts[$DATASET]}"
    export DATASET_END="${datasetEnd[$DATASET]}"
    export DATASET_COOLDOWN="${datasetCooldown[$DATASET]}"

    for SETTING in "${settings[@]}"; do
      export SETTING
      export SETTING_TTL="${settingTTL[$SETTING]}"
      export SETTING_BUFFER="${settingBuffer[$SETTING]}"
      export SETTING_TRANSMIT_SPEED="${settingTransmitSpeed[$SETTING]}"
      export SETTING_WARMUP="${settingWarmup[$SETTING]}"

      for ROUTER in "${routers[@]}"; do
        export SETTING_ROUTER=$ROUTER

        for ((i=1; i<=$iterations; i++)); do
          for numOfHybrids in "${numOfHybridNodes[@]}"; do
            for numOfMailboxes in "${numOfMailboxNodes[@]}"; do
              export ITERATION="${numOfHybrids}_${numOfMailboxes}_${i}"
              export DATASET_HOSTS=$((datasetHosts[$DATASET] + numOfMailboxes))
          
              # Generate messages and highly available nodes connections
              java -cp target social.HyccupsMsgCreator ${numOfHybrids} ${numOfMailboxes} ${i} "${hyccupsMsgSize[$SETTING]}" "${hyccupsNumOfDailyMsgsPerHost[$SETTING]}" false | sort -t$'\t' -k1 -n > scenarios/$SCENARIO/$DATASET/${SETTING}_${ROUTER}_${ITERATION}_messages.txt

              scenarioFile=scenarios/$SCENARIO/$DATASET/${SETTING}_${ROUTER}_${ITERATION}.txt
              envsubst < scenario_template.txt > $scenarioFile
              echo "./one.sh -b 1 $scenarioFile" >> scenarios/scenarios.txt
            done
          done
        done
      
      done
    done
  done
fi

###############################################################################
# Social mesh scenarios, with hybrid nodes and mailboxes (hyccups)
# Simulations with the hyccupsonlycontacts dataset correspond to Private Social Mesh,
# while simulations with the hyccups dataset correspond to Public Social Mesh.

if $scenarios_social ; then
  export SCENARIO="social"

  datasets=("hyccupsonlycontacts" "hyccups")
  settings=("ideal" "realistic" "realisticttl" "floodttl")
  routers=("SocialRouterHyccups")
  iterations=1
  numOfHybridNodes=("0" "10" "20")
  numOfMailboxNodes=("0" "10" "20")


  for DATASET in "${datasets[@]}"; do
    mkdir -p scenarios/$SCENARIO/$DATASET

    export DATASET_NAME=$DATASET
    export DATASET_PATH="${datasetPath[$DATASET]}"
    export DATASET_END="${datasetEnd[$DATASET]}"
    export DATASET_COOLDOWN="${datasetCooldown[$DATASET]}"

    for SETTING in "${settings[@]}"; do
      export SETTING
      export SETTING_TTL="${settingTTL[$SETTING]}"
      export SETTING_BUFFER="${settingBuffer[$SETTING]}"
      export SETTING_TRANSMIT_SPEED="${settingTransmitSpeed[$SETTING]}"
      export SETTING_WARMUP="${settingWarmup[$SETTING]}"

      for ROUTER in "${routers[@]}"; do
        export SETTING_ROUTER=$ROUTER

        for ((i=1; i<=$iterations; i++)); do
          for numOfHybrids in "${numOfHybridNodes[@]}"; do
            for numOfMailboxes in "${numOfMailboxNodes[@]}"; do
              export ITERATION="${numOfHybrids}_${numOfMailboxes}_${i}"
              export DATASET_HOSTS=$((datasetHosts[$DATASET] + numOfMailboxes))

              # Generate messages and highly available nodes connections
              java -cp target social.HyccupsMsgCreator ${numOfHybrids} ${numOfMailboxes} ${i} "${hyccupsMsgSize[$SETTING]}" "${hyccupsNumOfDailyMsgsPerHost[$SETTING]}" false | sort -t$'\t' -k1 -n > scenarios/$SCENARIO/$DATASET/${SETTING}_${ROUTER}_${ITERATION}_messages.txt

              scenarioFile=scenarios/$SCENARIO/$DATASET/${SETTING}_${ROUTER}_${ITERATION}.txt
              envsubst < scenario_template.txt > $scenarioFile
              echo "./one.sh -b 1 $scenarioFile" >> scenarios/scenarios.txt
            done
          done
        done
      
      done
    done
  done
fi


###############################################################################
# Execute scenarios

# Track the number of active processes
activeProcesses=0

scenariosRemaining=$(wc -l < scenarios/scenarios.txt)
send_notification "Starting simulation of $scenariosRemaining scenarios"

while IFS= read -r command; do

  # Check if there are available CPUs
  if ((activeProcesses >= cpuCores)); then
    # Wait for any active process to finish before starting a new one
    wait -n
    ((activeProcesses--))
  fi

  # Execute the command in the background
  send_notification "$(date) Starting scenario: $command"
  {
    $command  # Execute the command
    exit_status=$?  # Capture the exit status

    if [ $exit_status -ne 0 ]; then
      error_message="$(date) Failed scenario: '$command' with exit status $exit_status"
      send_notification "$error_message"
    else
      send_notification "$(date) Completed scenario: $command"
    fi
  } &
  # Renice to increase priority (needs superuser rights)
  renice -n -15 $!

  ((scenariosRemaining--))
  send_notification "Remaining scenarios $scenariosRemaining"

  # Increment the active process count
  ((activeProcesses++))

done < scenarios/scenarios.txt

# Wait for all the remaining background processes to finish
wait

send_notification "$(date) All simulations have been completed"