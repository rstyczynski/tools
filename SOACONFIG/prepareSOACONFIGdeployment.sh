#!/bin/bash

#Changelog
#1.2 fixed: substitution result was not validated for other files than "cfg". now is moved to substitute function
#    fixed: CFG_VERSION and other internal variables were not eported.
#    improved indention of processed files.  
#    added new parameter with variables/values

#Change condidate log
#1.3 spelling: Procesing->Processing
#    spelling, anonimization: Usage section
#    fixed: fixed issue when more than one variable is defined in single file 

#Parameters
#Note that parameters must be exported to be available in child processes e.g. perl is used to variable substitution

#export CFG_VERSION=1.0      # configuration version to be added to ear name
#export CFG_AUTODEPLOY=../   # autodeploy directory dependent on environment
#export CFG_FILTER="b2b|edn|mediator|soa-infra" # filter to select cfg. files 
#export CFG_FILES=./cfg      # directory with configuration files (svn fetch) 
#export CFG_SRC=./src        # directory with EAR src files (svn fetch)
#export CFG_DEPLOY=./deploy  # place to write generated EAR file
#export LOG_FILE=~/SOACONFIG/$0.log    # log file to write output from this script
#export tmpDir=/tmp          # temp dir to build ear

function usage {
cat <<EOF
Deployable, MDS based SOA Suite 11g configuration ryszard.styczynski@oracle.com, May 2014, version 1.2
Usage:

./prepareSOACONFIGdeployment.sh CFG_VERSION CFG_FILTER CFG_FILES CFG_SRC LOG_FILE tmpDir listOfVariables 

Note that: 
1. LOG_FILE and tmpDir must be absolute paths
2. configuration files use variables that must match with or with listOfVariables e.g.:   

./prepareSOACONFIGdeployment.sh CFG_VERSION CFG_FILTER CFG_FILES CFG_SRC LOG_FILE tmpDir CFG_AUTODEPLOY=/app/app01/sca

cat cfg/soa-infra-config.xml | grep autodeployDir 
<ns3:autodeployDir>${CFG_AUTODEPLOY}</ns3:autodeployDir> 

will produce: <ns3:autodeployDir>/app/app01/sca</ns3:autodeployDir>

Script checks if all variables were replaced. If not exits with code > 0.

Exemplary use:
./prepareSOACONFIGdeployment.sh 1v0 "b2b|edn|mediator|soa-infra" ./cfg ./src ./deploy $PWD/soaconfig.log /tmp CFG_AUTODEPLOY=/app/app01/sca

generates EAR file and writes to ./deploy/soa-config-1v0.ear 
EOF
}

#utility functions
dotsDots='.............................................................................................................................................'
dotsLines='_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ '
dotsDash='----------------------------------------------------------------------------------------------------------------------------------------------'
dotsSpaces='                                                                                                                                          '
function echoTab {
 if [ -z "$3" ]; then
  dots=$dotsDots
 else
  dots="$3"
 fi
 if [ -z "$2" ]; then 
   if [ -z "$tabultor" ]; then
        tabPos=60
   else
   	tabPos=$tabulator
   fi
 else
   tabPos=$2
 fi
 filldots=$(( $tabPos - $(echo $1 | wc -c) ))
 if [ $filldots -lt 0 ]; then
        filldots=1
 fi
 echo -n "$1$(echo "$dots" | cut -b1-$filldots )" | tee -a $LOG_FILE
}

function logDate {
        dateStr=$(date)
        echo $@
        echo $dateStr, $@ >>$LOG_FILE
}

function log {
        if [ "$1" == "-n" ]; then
                shift
                echo -n "$@"
                echo "$@" >>$LOG_FILE
        else
                echo "$@" | tee -a $LOG_FILE
        fi
}

function execOrDie {
        stepMsg=$1; shift
        exitCode=$1; shift
        runCMD=$1; shift

        echoTab "$stepMsg" 50
        $runCMD $@ >>$LOG_FILE
        if [ $? -ne 0 ]; then
                log Error.
                logDate "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
                logDate "Error running: $stepMsg. Exiting."
                logDate "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
                exit $exitCode
        else
				removeTmpFiles 
                log Done.
                return 0
        fi
}

function reverseExitCode {
        $@
        if [ $? -eq 0 ]; then
                return 255
        else
                return 0
        fi
}

function removeTmpFiles {
 rm -rf CFG_BUILD
}

function substituteVariablesInFiles {
        cfgFiles=$1
        outDir=$2

	log "Processing variable substitution"
        for file in $cfgFiles; do
         log "|---Processing file: $file"
         variables=$(cat $file | perl -ne 'if (/\${(\w+)}/) { print "$1\n";}')
         if [ ! -z "$variables" ]; then
		for variable in $variables; do
                	log "|   |--- $variable"
		done
         else
            log "|   |--- (no variables)"
         fi
         cat $file | perl -p -e 's/\$\{(\w+)\}/(exists $ENV{$1}?$ENV{$1}:"\${$1}")/eg' > $outDir/$(basename $file)
        done
	execOrDie "\---Verifying that all variables were replaced" 20 reverseExitCode egrep '\$\{\w+\}' $outDir/*
}

#STEP 0. Check if required utilities are available
#zip date tee egrep perl sed
#TODO

#STEP 1. Validate parameters and expected directories

#STEP 1.1 Check number of parameters and assign provided values

if [ $# -ne 8 ]; then
	usage
	exit 10
fi

#required by variable subsitution
export CFG_VERSION=$1
export CFG_FILTER=$2
export CFG_FILES=$3
export CFG_SRC=$4
export CFG_DEPLOY=$5
export LOG_FILE=$6
export tmpDir=$7
varList=$8

#STEP 1.2 Prepare parameters and directories

#decode variables provided as scrip tparameter no.8
#Note that parameters must be exported to be available in child processes
for varSnippet in $varList; do
	eval "export $varSnippet"
done

CFG_BUILD=$tmpDir/soa-config-$CFG_VERSION
if [ -d $CFG_BUILD ]; then
        cd $tmpDir
        execOrDie "Removing not empty soa-config build directory" 11 rm -rf soa-config-$CFG_VERSION
        cd - >/dev/null
fi
execOrDie "Creating soa-config build directory" 10 mkdir -p $CFG_BUILD

MDS_BUILD=$CFG_BUILD/mds
if [ -d $MDS_BUILD ]; then
        cd $CFG_BUILD
        execOrDie "Removing not empty mds build directory" 10 rm -rf mds
        cd - >/dev/null
fi
execOrDie "Creating mds build directory" 10 mkdir -p $MDS_BUILD/soa/configuration/default

WAR_BUILD=$CFG_BUILD/war
if [ -d $WAR_BUILD ]; then
        cd $CFG_BUILD
        execOrDie "Removing not empty war build directory" 10 rm -rf war
        cd - >/dev/null
fi
execOrDie "Creating war build directory" 10 mkdir -p $WAR_BUILD

EAR_BUILD=$CFG_BUILD/ear
if [ -d $EAR_BUILD ]; then
        cd $CFG_BUILD
        execOrDie "Removing not empty war build directory" 10 rm -rf ear
        cd - >/dev/null
fi
execOrDie "Creating ear build directory" 10 mkdir -p $EAR_BUILD


#STEP 2.1. Copy cfg files updating autodeployDir in soa-infra-config.xml
execOrDie "Checking source configuration files" 20 ls $CFG_FILES/*
cfgFiles=$(ls $CFG_FILES/* | egrep $CFG_FILTER)
writeToDir=$MDS_BUILD/soa/configuration/default
substituteVariablesInFiles "$cfgFiles" $writeToDir

#STEP 2.2. 
execOrDie "Verifying that files were generated" 20 ls $MDS_BUILD/soa/configuration/default/*.xml

#STEP 2.4. Build soa-config.mar
cd  $MDS_BUILD
execOrDie "Building soa-config.mar file" 20 zip -r $CFG_BUILD/ear/soa-config.mar .
cd - >/dev/null

#STEP 3. Prepare elements of EAR

#STEP 3.1 Build adf-loc.jar
execOrDie "Create EAR/lib directory" 30 mkdir $EAR_BUILD/lib
cd $CFG_SRC/lib
execOrDie "Create adf-loc.jar file." 30 zip $EAR_BUILD/lib/adf-loc.jar META-INF/MANIFEST.MF
cd - >/dev/null

#STEP 3.2 Build adf/META-INF/adf-config.xml
execOrDie "Creating directory for adf-config.xml" 30 mkdir -p $EAR_BUILD/adf/META-INF
execOrDie "Checking source ADF configuration files" 30 ls $CFG_SRC/adf/META-INF/*
adfFiles=$(ls $CFG_SRC/adf/META-INF/*)
writeToDir=$EAR_BUILD/adf/META-INF
substituteVariablesInFiles "$adfFiles" $writeToDir

#STEP 3.3
execOrDie "Checking destination ADF configuration files" 30 ls $writeToDir

#STEP 3.4 Copy application.xml updating context-root with version number
execOrDie "Creating directory for EAR cfg. files" 30 mkdir -p $EAR_BUILD/META-INF
execOrDie "Checking EAR configuration files" 30 ls $CFG_SRC/META-INF/*
earFiles=$(ls $CFG_SRC/META-INF/*)
writeToDir=$EAR_BUILD/META-INF
substituteVariablesInFiles "$earFiles" $writeToDir
execOrDie "Checking destination EAR desriptors" 30 ls $writeToDir

#STEP 4.1. Generate index.html
cfgFiles=$(ls $MDS_BUILD/soa/configuration/default)
for file in $cfgFiles; do
        echo "<h1>$file</h1>" >>$WAR_BUILD/index.html
        cat $MDS_BUILD/soa/configuration/default/$file | sed 's/</\&lt;/g' | sed 's/>/\&gt;/g' | sed 's#$#</br>\n#g' >>$WAR_BUILD/index.html
done

#STEP 4.2. Build soa-config.war
cd  $WAR_BUILD
execOrDie "Building soa-config.war" 20 zip -r $CFG_BUILD/ear/soa-config.war .
cd - >/dev/null

#STEP 5. Build soa-config-$CFG_VERSION.ear
cd $CFG_BUILD/ear
execOrDie "Building EAR file" 50 zip -r $CFG_BUILD/soa-config-$CFG_VERSION.tmp *
cd - >/dev/null

#STEP 6. Move to deployment directory
execOrDie "Moving EAR to deployment directory" 60 mv $CFG_BUILD/soa-config-$CFG_VERSION.tmp $CFG_DEPLOY/soa-config-$CFG_VERSION.ear
removeTmpFiles 
echo Done.


