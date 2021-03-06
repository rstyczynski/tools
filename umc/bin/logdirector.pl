#!/usr/bin/perl

use Getopt::Long;
use Pod::Usage;
use File::Copy qw(move);
use FileHandle;
use strict;

my $dstDir=".";			 #log destination directory
my $dstEffectiveDir="";  #date asubdirectory
my $dstDateSubDirFlag=0; #maintain date sub directory?  
my $dstDateSubDir="";    #date subdirectory name
my $logName="";			 #log name w/o extension. Script automatically adds .log or provided extension
my $logIdentifier ="";	 #identifier to be able to locate background splitter process
my $logExt="log";   	 #log file extension
my $useTimestampedLog=0; #always write to log file with timestamp
my $datePrefix=0;        #put timestamp at begging of the filename or at the end
my $logDateSeparator="_";#separator between file name and timestamp
my $logNameExt;			 #log name with extension. build by the script

my $fileHeader;          #header to be added at top of each file
my $autoDetectHeader=0;      #take file header from first line after start in the log stream
my $headerAlreadyDetected=0; #take header just once

my $rotateBy="bytes";	 #type of rotation. by bytes or lines. default it bytes
my $sizePerLogParam;	 #to capture cmd line parameter
my $sizePerLog;			 #maximum size of log file. meaning depends on rotate by. may be lines or bytes. used internally to initiate rotation
my $rotateOnStart=0;	 #rotate on start. option specified by cmd line. Default yes - do on start rotation.
my $logFlush=0;			 #auto flush the log - disable perl side buffering
my $verbose=0;			 #verbose mode - print verbose information about processing
my $man=0;		  	     #man flag
my $help=0;			     #help flag

#rotation
my $rotate=0;			#flag informing if rotation is needed. Rotation may be triggered by size or time

#size rotation
my $logSize;			#internal. current size of log
my $rotatedLogName; 	        #rotated log name. Rotation adds current timestamp plus unique suffix if necessary
my $rotatedLogNameExt;		#rotated log file name with .log extension

#time rotation
my $rotateByTime="";
my $timeLimir=0;
my $startTimeAdjustment = 0;
my $timePerLog=0;
my $logRotationTimeLimit=0;
my $currentTime=0;
my $currentTimeSlot=0;
my $lastTimeSlot=time+1;	#value bigger than time block rotation duriong first loop
my $lastTime=0;

#other
my $exit = 0;			#flag to exit main loop, set by INT signal handler

#read cmd line options
my $optError=0;
GetOptions ('dir=s'   	    => \$dstDir,      	# string
            'addDateSubDir' => \$dstDateSubDirFlag, # flag
            'name=s'	    => \$logName,     	# string
            'alwaysRotate'  => \$useTimestampedLog, #flag
            'prefixDate',   	  => \$datePrefix,      	# flag
            'separatorDate=s', => \$logDateSeparator,      	# string
		    'identifier=s'	=> \$logIdentifier, # string
	       	'extension=s'	=> \$logExt,    	# string
            'header=s'      => \$fileHeader,     #string
            'detectHeader'  => \$autoDetectHeader, #flag
	       	'rotateBySize=s'=> \$rotateBy, 		# string
        	'limit=i' 	    => \$sizePerLogParam, # integer
		    'rotateByTime=s'=> \$rotateByTime,	# string
		    'timeLimit=i'   => \$timePerLog,	# integer
            'flush'		    => \$logFlush,      # flag
 	       	'start'		    => \$rotateOnStart, # flag
            'verbose'	    => \$verbose,      	# flag
		    'help|?'	    => \$help, 		    # flag
		    'man'		    => \$man)		    # flag
or $optError=1;

if($optError){
	print ("logdirector.pl: Error in command line arguments\n");
	pod2usage(2);
	exit;
}

pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

if ($logName eq ""){
	pod2usage(2);
	exit;
} else {
	$logNameExt = "$logName.$logExt";
}

if ($logIdentifier eq ""){
	$logIdentifier = $logNameExt;
}

if ($rotateBy eq "lines"){
	if ($sizePerLogParam eq ""){
		#default 100k lines for line based rotation
		$sizePerLog=100000;
	} else {
		$sizePerLog=$sizePerLogParam;
	}
} elsif ($rotateBy eq "bytes"){ 
        if ($sizePerLogParam eq ""){
		#default 50MB for byte based rotation
                $sizePerLog=50*1024*1024;
        } else {
                $sizePerLog=$sizePerLogParam;
        }
} elsif ( $rotateBy ne "" ) {
	die "logdirector.pl: Error: rotateBy must be lines or bytes";
}

if ($rotateByTime eq "clock" ){
	$startTimeAdjustment = 0;	
} elsif ($rotateByTime eq "run" ){
	$startTimeAdjustment = time;
} elsif ($rotateByTime ne "" ) {
        die "logdirector.pl: Error: rotateByTime must be clock or run";
}

if ( "$rotateByTime . $rotateBy" eq "" ){ 
	die "logdirector.pl: Error: no rotation method provided. Provide by content or time. Both may be used together."
}

if ( $timePerLog > 0 ){
	$logRotationTimeLimit = $timePerLog;
} else {
	#24 hours log rotation
	$logRotationTimeLimit = 3600 * 24;	
}	

if ($verbose) {
	print "Params: $dstDir, $logName, $rotateBy, $sizePerLog, $rotateOnStart, $verbose\n";
}

#register signal handlers
$SIG{HUP}  = \&signal_handler_ROTATE;
$SIG{INT}  = \&signal_handler_EXIT;

#REMOVE
#rotate on start
if ($rotateOnStart){
	moveLogFile();
}

#$exit may be set only by INT signal
my $exit = 0;

while ( ! $exit ) {

	#open log file handler
	openLogFile();
    
	#read and process stdin
	if ($verbose) {print "Entering stdin read loop\n";}
	while (<>) {
		$rotate = 0;

		#print line taken from stdin
		print outfile $_;

        if ( $autoDetectHeader && not($headerAlreadyDetected)) {
            $fileHeader = $_;
            $headerAlreadyDetected=1;
        }

		#increment log size
		if ($rotateBy eq "lines"){
			$logSize++;
		} elsif ($rotateBy eq "bytes"){
			$logSize += length $_;
		}
		
		#decide if rotation is required	
		if ($logSize >= $sizePerLog) {
			if ( $rotateBy ne "" ) {
				$rotate = 1;
			}
		}

		#decide if time based rotation is required
		$currentTime = time - $startTimeAdjustment;

		#detect current time slot
		$currentTimeSlot = $currentTime - $currentTime % $logRotationTimeLimit;	

		if ($verbose) { print "Rotate by: $logRotationTimeLimit, current time: $currentTime, current time slot: $currentTimeSlot\n";}	
		if ( $currentTimeSlot > $lastTimeSlot ){
			if ( $rotateByTime ne "") {
				$rotate = 1;
			}
		}

		$lastTime = $currentTime;
		$lastTimeSlot = $currentTimeSlot;

		if ($rotate ){
			rotateLogFile();
		}
	}

	#check if exit was due to signal
	my $errno = $! + 0;
	if ( $errno == 0 ) {
		$exit = 1;
	} 
	
	#close log file after close of input stream
	close(outfile);

	#exiting due to $exit=1
}


###
### END of main logic here.
###

##### functions
sub signal_handler_ROTATE {
        if ($verbose) {print "Caught a HUP signal. Reopening stdin and out file\n";}
  	rotateLogFile();
}

sub signal_handler_EXIT {
	$exit = 1;
}

sub rotateLogFile {
	close(outfile);
    
	if ( $useTimestampedLog ) {
        openLogFile();
	} else {
        moveLogFile();
        openLogFile();
    }

}

sub moveLogFile {
        $rotatedLogNameExt=generateRotatedLogName();
        if ($verbose) {print "Rotated log name:$rotatedLogNameExt\n";}
        
        if ($dstDateSubDirFlag) {
            my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
            $year += 1900;
            $mon++;
            if($mon < 10) {$mon = "0$mon"};
	        if($mday < 10) {$mday = "0$mday"};
            $dstDateSubDir = "$year-$mon-$mday";
            $dstEffectiveDir = "$dstDir/$dstDateSubDir";

            unless(-e $dstEffectiveDir or mkdir $dstEffectiveDir) { die "logdirector.pl: Unable to create $dstEffectiveDir\n"; }
        } else {
            $dstEffectiveDir = "$dstDir";
        }
        
        if ( -e "$dstEffectiveDir/$logNameExt" ) {
                move("$dstEffectiveDir/$logNameExt", "$dstEffectiveDir/$rotatedLogNameExt");
        }
}

sub openLogFile {
	$logSize=0;
    
    if ($dstDateSubDirFlag) {
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
		$year += 1900;
		$mon++;
        if($mon < 10) {$mon = "0$mon"};
	    if($mday < 10) {$mday = "0$mday"};
		$dstDateSubDir = "$year-$mon-$mday";
		$dstEffectiveDir = "$dstDir/$dstDateSubDir";
        
        unless(-e $dstEffectiveDir or mkdir $dstEffectiveDir) { die "logdirector.pl: Unable to create $dstEffectiveDir\n"; }
	} else {
		$dstEffectiveDir = "$dstDir";
	}
    
    if ( $useTimestampedLog ) {
        $logNameExt=generateRotatedLogName();
    }
	open(outfile, ">>", "$dstEffectiveDir/$logNameExt") || die "logdirector.pl: Cannot open output file: $!";
	if ($verbose) {print "Opened log file $dstEffectiveDir/$logNameExt\n";}
    
    if ( $fileHeader ) {
        if ( $autoDetectHeader ) {
            #autodetected header is already with new line character
            print outfile $fileHeader;
        } else {
            print outfile $fileHeader . "\n";
        }
    }
    
	#make out_file hot - flush buffers immediately
	if ($logFlush) {
		outfile->autoflush(1);
	}
}

sub generateRotatedLogName {
	#prepare rotated file name
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon++;
	if($sec < 10) {$sec = "0$sec"};
	if($min < 10) {$min = "0$min"};
	if($hour < 10) {$hour = "0$hour"};
	if($year < 10) {$year = "0$year"};
	if($mon < 10) {$mon = "0$mon"};
	if($mday < 10) {$mday = "0$mday"};

	if ($verbose) { print "Time:$sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst\n";}
	if ($verbose) { print "Log name: $logName\n";}
	
    if ($datePrefix) {
        $rotatedLogName = "$year-$mon-$mday-$hour$min$sec"  . $logDateSeparator . "$logName";
    } else {
        $rotatedLogName = "$logName" . $logDateSeparator . "$year-$mon-$mday-$hour$min$sec";
    }
    
	$rotatedLogNameExt = "$rotatedLogName.$logExt";
	if ($verbose) { print "Rotated log name: $rotatedLogName, $rotatedLogNameExt\n";}
    
    if ($dstDateSubDirFlag) {
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
		$year += 1900;
		$mon++;
        if($mon < 10) {$mon = "0$mon"};
	    if($mday < 10) {$mday = "0$mday"};
		$dstDateSubDir = "$year-$mon-$mday";
		$dstEffectiveDir = "$dstDir/$dstDateSubDir";
        
        unless(-e $dstEffectiveDir or mkdir $dstEffectiveDir) { die "logdirector.pl: Unable to create $dstEffectiveDir\n"; }
	} else {
		$dstEffectiveDir = "$dstDir";
	}
    
    my $rotatedUniqueSuffix=0;
	while (-e "$dstEffectiveDir/$rotatedLogNameExt"){
        	if ($verbose) { print "Rotated log name exists. Generating unique suffix.\n";};
       	 	$rotatedUniqueSuffix++;
        	$rotatedLogNameExt = "$rotatedLogName-$rotatedUniqueSuffix.$logExt";
	}
	if ($verbose) { print "Rotated log name: $rotatedLogName, $rotatedLogNameExt\n";}
	return $rotatedLogNameExt;
}

__END__
=head1 NAME

logdirector.pl - stdout log director and rotation script. 
 
=head1 SYNOPSIS

 some_program | perl logdirector.pl -name logName [options]
 where:
 -name 		log name, but without extension (provided value or default 'log' will be added). This parameter is mandatory,
 -extension 	log extension. Default is 'log',
 
 -dir		destination directory for log file. Default is current directory,
 -addDateSubDir create subdirectory with date to keep logs,

 -alwaysRotate  always write to log file with timestamp,
 -prefixDate    put timestamp at front of the file name, default is at the end,
 -separatorDate character to separate timestamp and file name. default is underscore,
 
 -header        add this header on top of each file. Useful for CSV files with hreader,
 -detectHeader  auto detect header from first line of log stream after start. Useful for CSV files with hreader,
 
 -rotateBySize 	rotation done by line or byte count. Default is bytes,
 -limit 	number of lines or bytes in single log file. Default values are 100 k lines and 50 mega bytes. Value provided as integer,
 -rotateByTime	rotation done by clock of process run time. Default is clock,
 -timeLimit	time limit in seconds. Default is 86400 (1 day),
 -startup 	rotate on startup. By default doesn't rotate on startup,
 
 -identifier 	log process identifier to be used by administrator/scripts to locate log director running in background,
 -flush 	do not buffer output. flush each line. Default is to use buffering,
 
 -verbose	debug mode,
 -help 		this help,
 -man		shows longer manual.

 You can use first letters of option names to make command line shorter.

=head1 DESCRIPTION

Forwards stdin data stream to a log file and maintain log naming and rotation rules. Rotated files get date/time signature at the end or at begining of the file name, and may be written to daily directory. In case of name conflict (too fast log generation), date/time is extended by unique sequence. Supports flexible rotation rules. Rewrties file headers on request, what is useful for CVS files rotation.  

=head1 EXAMPLES

=over 1

=item B<Rotate by bytes>

 seq 1 100  | perl logdirector.pl -n rotate-seq -l 30
 ls -lh rotate-s*
 -rw-r--r--  1 user  staff    30B Jan 21 16:52 rotate-seq-2015-01-21-165222-1.log
 -rw-r--r--  1 user  staff    30B Jan 21 16:52 rotate-seq-2015-01-21-165222-2.log
 -rw-r--r--  1 user  staff    30B Jan 21 16:52 rotate-seq-2015-01-21-165222-3.log
 -rw-r--r--  1 user  staff    30B Jan 21 16:52 rotate-seq-2015-01-21-165222-4.log
 -rw-r--r--  1 user  staff    30B Jan 21 16:52 rotate-seq-2015-01-21-165222-5.log
 -rw-r--r--  1 user  staff    30B Jan 21 16:52 rotate-seq-2015-01-21-165222-6.log
 -rw-r--r--  1 user  staff    30B Jan 21 16:52 rotate-seq-2015-01-21-165222-7.log
 -rw-r--r--  1 user  staff    30B Jan 21 16:52 rotate-seq-2015-01-21-165222-8.log
 -rw-r--r--  1 user  staff    30B Jan 21 16:52 rotate-seq-2015-01-21-165222.log
 -rw-r--r--  1 user  staff    22B Jan 21 16:52 rotate-seq.log

=item B<Rotate by lines>

seq 1 100  | perl logdirector.pl -n rotate-seq -rotateBySize lines -l 10
 wc -l rotate-seq*
      10 rotate-seq-2015-01-21-170025-1.log
      10 rotate-seq-2015-01-21-170025-2.log
      10 rotate-seq-2015-01-21-170025-3.log
      10 rotate-seq-2015-01-21-170025-4.log
      10 rotate-seq-2015-01-21-170025-5.log
      10 rotate-seq-2015-01-21-170025-6.log
      10 rotate-seq-2015-01-21-170025-7.log
      10 rotate-seq-2015-01-21-170025-8.log
      10 rotate-seq-2015-01-21-170025-9.log
      10 rotate-seq-2015-01-21-170025.log
       0 rotate-seq.log
     100 total

=item B<Rotate by process run time>

 # waiting for proper time x 1s
 while [ $(date +%S | cut -b2) -ne 1 ]; do sleep 1; echo -n .; done; echo
 for cnt in $(seq 1 100); do echo $cnt; sleep 0.1; done  | perl logdirector.pl -n rotate-seq -rotateByTime run -timeLimit 5 -flush
 ls -lhTU *.log
 -rw-r--r--  1 user  staff   123B Feb 17 16:34:11 2015 rotate-seq-2015-02-17-163416.log	<- lapsed 5 seconds 
 -rw-r--r--  1 user  staff   147B Feb 17 16:34:16 2015 rotate-seq-2015-02-17-163421.log <- lapsed 5 seconds
 -rw-r--r--  1 user  staff    22B Feb 17 16:34:21 2015 rotate-seq.log

=item B<Rotate by clock time>

 for cnt in $(seq 1 100); do echo $cnt; sleep 0.1; done  | perl logdirector.pl -n rotate-seq -rotateByTime clock -timeLimit 5 
 wc -l rotate-seq*
      32 rotate-seq-2015-02-17-161715.log	 <- wall clock passed 5 seconds window
      48 rotate-seq-2015-02-17-161720.log	 <- wall clock passed 5 seconds window
      20 rotate-seq.log
     100 total

=item B<Rotate by lines and process run time>

 for cnt in $(seq 1 100); do echo $cnt; sleep 0.1; done  | perl logdirector.pl -n rotate-seq -rotateByTime run -timeLimit 5 -rotateBy lines -limit 40
 wc -l *.log
      40 rotate-seq-2015-02-17-160626.log	<- 40 lines limit
       1 rotate-seq-2015-02-17-160627.log	<- lapsed 5 seconds
      40 rotate-seq-2015-02-17-160631.log	<- 40 lines limit
       8 rotate-seq-2015-02-17-160632.log	<- lapsed 5 seconds
      11 rotate-seq.log
     100 total
     
=item B<Rotate by clock time, save files to directory keeping timestamp prefix, add header to each file.>

  for cnt in $(seq 1 100); do echo $cnt; sleep 1; done \
  | perl logdirector.pl -n rotate-seq -rotateByTime clock -timeLimit 15 -addDateSubDir -alwaysRotate -prefixDate -header Counter
  
  ls -l
  total 96
  drwxr-xr-x  9 rstyczynski  staff    306 Nov  8 11:42 2017-11-08   <- created directory with logs

  ls -l $(date +%Y-%m-%d)/
  total 56
  -rw-r--r--  1 rstyczynski  staff  35 Nov  8 11:41 2017-11-08-114049_rotate-seq.log  <- log files are perfixed with timestamp
  -rw-r--r--  1 rstyczynski  staff  53 Nov  8 11:41 2017-11-08-114100_rotate-seq.log
  -rw-r--r--  1 rstyczynski  staff  53 Nov  8 11:41 2017-11-08-114115_rotate-seq.log
  -rw-r--r--  1 rstyczynski  staff  53 Nov  8 11:41 2017-11-08-114130_rotate-seq.log
  -rw-r--r--  1 rstyczynski  staff  53 Nov  8 11:42 2017-11-08-114145_rotate-seq.log
  -rw-r--r--  1 rstyczynski  staff  53 Nov  8 11:42 2017-11-08-114200_rotate-seq.log
  -rw-r--r--  1 rstyczynski  staff  48 Nov  8 11:42 2017-11-08-114215_rotate-seq.log
  
  head -3 $(date +%Y-%m-%d)/$(ls $(date +%Y-%m-%d) | head -1)
  Counter   <- added header
  1
  2
  
  head -3 $(date +%Y-%m-%d)/$(ls $(date +%Y-%m-%d) | head -2 | tail -1)
  Counter   <- added header
  13
  14

=item B<Rotate file explicitly written by a program>
  
 mkfifo /tmp/logpipe
 tail -c +1 -f /tmp/logpipe | perl logdirector.pl -n rotate-seq -rotateBySize lines -l 10 -i test001-rotate-seq &
 seq 1 100  >/tmp/logpipe
 wc -l rotate-seq*
      10 rotate-seq-2015-01-22-110927-1.log
      10 rotate-seq-2015-01-22-110927-2.log
      10 rotate-seq-2015-01-22-110927-3.log
      10 rotate-seq-2015-01-22-110927-4.log
      10 rotate-seq-2015-01-22-110927-5.log
      10 rotate-seq-2015-01-22-110927-6.log
      10 rotate-seq-2015-01-22-110927-7.log
      10 rotate-seq-2015-01-22-110927-8.log
      10 rotate-seq-2015-01-22-110927-9.log
      10 rotate-seq-2015-01-22-110927.log
       0 rotate-seq.log
     100 total

=item B<Identify PID of background logdirector process>

 ps -f | grep "test001-rotate-seq" | grep -v grep
 501  8553   534   0 11:32AM ttys002    0:00.07 perl logdirector.pl -n rotate-seq -r lines -l 10 -i test001-rotate-seq
 Note that above example is from OSX. Parameters of ps command and its output varies on different operating systems.

=item B<Log rotation triggered by external process>

 # waiting for proper time x1s
 while [ $(date +%S | cut -b2) -ne 1 ]; do sleep 1; echo -n .; done; echo
 
 # start background 5s rotation trigger 
 bash -c '
 cnt=0
 while [ $cnt -lt 5 ]; do
 sleep 5
 logdirectorPID=$(ps | grep rotate-HUP-test | grep -v grep | cut -f1 -d" ")
 echo $logdirectorPID
 if [ "$logdirectorPID" != "" ]; then
    kill -HUP $logdirectorPID
    if [ $? -eq 1 ]; then
      cnt=5
    fi
 fi
 cnt=$(( $cnt + 1 ))
 done 
 
 exit
 ' &
 for cnt in $(seq 1 100); do echo $cnt; sleep 0.2; done | perl logdirector.pl -n rotate-seq -rotateByTime run -timeLimit  5000 -flush -identifier rotate-HUP-test
 wc -l rotate-seq*
      25 rotate-seq-2015-02-25-152946.log
      25 rotate-seq-2015-02-25-152951.log
      24 rotate-seq-2015-02-25-152956.log
      25 rotate-seq-2015-02-25-153001.log
       1 rotate-seq.log
     100 total

=back

=head1 PERFORMANCE
	
log director was verified to work on three levels of speed: (1) unbuffered write, read from stdin: 100MB/s, (2) buffered write (-f option), read from stdin: 30MB/s, (3) unbuffered write, read from fifo pipe: 10MB/s. Each level of measured speed seems enough for logging purposes.

=head1 AUTHOR

Ryszard Styczynski
<ryszard.styczynski@oracle.com>
<http://snailsinnoblesoftware.blogspot.com>

February 2015 - November 2017, version 0.3

=cut

