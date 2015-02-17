#!/usr/bin/perl

use Getopt::Long;
use Pod::Usage;
use File::Copy qw(move);
use FileHandle;
use strict;

my $dstDir=".";			#log destination directory
my $logName="";			#log name w/o extension. Script automatically adds .log or provided extension
my $logIdentifier ="";		#identifier to be able to locate background splitter process
my $logExt="log";   	        #log file extension
my $logNameExt;			#log name with extension. build by the script
my $rotateBy="bytes";		#type of rotation. by bytes or lines. default it bytes
my $sizePerLogParam;		#to capture cmd line parameter
my $sizePerLog;			#maximum size of log file. meaning depends on rotate by. may be lines or bytes. used internally to initiate rotation
my $rotateOnStart=0;		#rotate on start. option specified by cmd line. Default yes - do on start rotation.
my $logFlush=0;			#auto flush the log - disable perl side buffering
my $verbose=0;			#verbose mode - print verbose information about processing
my $man=0;			#man flag
my $help=0;			#help flag

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

#read cmd line options
my $optError=0;
GetOptions (	'dir=s'   	=> \$dstDir,      	# string
            	'name=s'	=> \$logName,     	# string
		'identifier=s'	=> \$logIdentifier, 	# string
	       	'extension=s'	=> \$logExt,    	# string
	       	'rotateBySize=s'=> \$rotateBy, 		# string
             	'limit=i'	=> \$sizePerLogParam,	# integer
		'rotateByTime=s'=> \$rotateByTime,	# string
		'timeLimit=i'   => \$timePerLog,	# integer
             	'flush'		=> \$logFlush,        	# flag
 	       	'start'		=> \$rotateOnStart, 	# flag
            	'verbose'	=> \$verbose,      	# flag
		'help|?'	=> \$help, 		# flag
		'man'		=> \$man)		# flag
or $optError=1;

if($optError){
	print ("logsplitter.pl: Error in command line arguments\n");
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
	die "logsplitter.pl: Error: rotateBy must be lines or bytes";
}

if ($rotateByTime eq "clock" ){
	$startTimeAdjustment = 0;	
} elsif ($rotateByTime eq "run" ){
	$startTimeAdjustment = time;
} elsif ($rotateByTime ne "" ) {
        die "logsplitter.pl: Error: rotateByTime must be clock or run";
}

if ( "$rotateByTime . $rotateBy" eq "" ){ 
	die "logsplitter.pl: Error: no rotation method provided. Provide by content or time. Both may be used together."
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

#rotate on start
if ($rotateOnStart){
	$rotatedLogNameExt=generateRotatedLogName();
	if ($verbose) {print "Rotated log name:$rotatedLogNameExt\n";}
	if ( -e "$dstDir/$logNameExt" ) {
		move("$dstDir/$logNameExt", "$dstDir/$rotatedLogNameExt");
	}
}

#open log file handler
openLogFile();

#read and process stdin
if ($verbose) {print "Entering stdin read loop\n";}
while (<>) {
	$rotate = 0;

	#print line taken from stdin
	print outfile $_;

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
                $rotatedLogNameExt=generateRotatedLogName();
                close(outfile);
                move("$dstDir/$logNameExt", "$dstDir/$rotatedLogNameExt");
                openLogFile();
	}
}
#close log file after close of input stream
close(outfile);

##### functions
sub openLogFile {
	$logSize=0;
	open(outfile, ">>", "$dstDir/$logNameExt") || die "logsplitter.pl: Cannot open output file: $!";
	if ($verbose) {print "Opened log file $dstDir/$logNameExt\n";}
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
	$rotatedLogName = "$logName-$year-$mon-$mday-$hour$min$sec";
	$rotatedLogNameExt = "$rotatedLogName.$logExt";
	if ($verbose) { print "Rotated log name: $rotatedLogName, $rotatedLogNameExt\n";}
	my $rotatedUniqueSuffix=0;
	while (-e "$dstDir/$rotatedLogNameExt"){
        	if ($verbose) { print "Rotated log name exists. Generating unique suffix.\n";};
       	 	$rotatedUniqueSuffix++;
        	$rotatedLogNameExt = "$rotatedLogName-$rotatedUniqueSuffix.$logExt";
	}
	if ($verbose) { print "Rotated log name: $rotatedLogName, $rotatedLogNameExt\n";}
	return $rotatedLogNameExt;
}

__END__

=head1 NAME

 logsplitter.pl - stdout rotation script. 

=head1 SYNOPSIS

 some_program 2>&1 | perl logsplitter.pl -name logName [options]

 where:
 -name 		log name, but without extension (provided value or default 'log' will be added). This parameter is mandatory,

 -dir		destination directory for log file. Default is current directory,
 -extension 	log extension. Default is 'log',
 -rotateBySize 	rotation done by line or byte count. Default is bytes,
 -limit 	number of lines or bytes in single log file. Default values are 100 k lines and 50 mega bytes. Value provided as integer,
 -rotateByTime	rotation done by clock of process run time. Default is clock,
 -timeLimit	time limit in seconds. Default is 86400 (1 day),
 -startup 	rotate on startup. By default doesn't rotate on startup,
 -identifier 	log process identifier to be used by administrator/scripts to locate split logger running in background,
 -flush 	do not buffer output. flush each line. Default is to use buffering,
 -verbose	debug mode,

 -help 		this help,
 -man		shows longer manual.

 You can use first letters of option names to make command line shorter.

=head1 DESCRIPTION

Forwards stdin data stream to a log file and maintain rotation rules. Rotated files get date/time signature at the end of the file name, but before extension. In case of name conflict (too fast log generation), date/time is extended by unique sequence. Uses internal rotation rules and writes data synchronously just after data reception. Does not require external tool as logrotate, and does not react on HUP signal.

=head1 EXAMPLES

=over 1

=item B<Rotate by bytes>

 seq 1 100 2>&1 | perl logsplitter.pl -n rotate-seq -l 30

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

 seq 1 100 2>&1 | perl logsplitter.pl -n rotate-seq -rotateBySize lines -l 10

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

 # waiting for proper time x1s
 while [ $(date +%S | cut -b2) -ne 1 ]; do sleep 1; echo -n .; done; echo
 for cnt in $(seq 1 100); do echo $cnt; sleep 0.1; done 2>&1 | perl logsplitter.pl -n rotate-seq -rotateByTime run -timeLimit 5 -flush

 ls -lhTU *.log
 -rw-r--r--  1 user  staff   123B Feb 17 16:34:11 2015 rotate-seq-2015-02-17-163416.log	<- lapsed 5 seconds 
 -rw-r--r--  1 user  staff   147B Feb 17 16:34:16 2015 rotate-seq-2015-02-17-163421.log <- lapsed 5 seconds
 -rw-r--r--  1 user  staff    22B Feb 17 16:34:21 2015 rotate-seq.log

=item B<Rotate by clock time>

 for cnt in $(seq 1 100); do echo $cnt; sleep 0.1; done 2>&1 | perl logsplitter.pl -n rotate-seq -rotateByTime clock -timeLimit 5 

 wc -l rotate-seq*
      32 rotate-seq-2015-02-17-161715.log	 <- wall clock passed 5 seconds window
      48 rotate-seq-2015-02-17-161720.log	 <- wall clock passed 5 seconds window
      20 rotate-seq.log
     100 total

=item B<Rotate by lines and process run time>

 for cnt in $(seq 1 100); do echo $cnt; sleep 0.1; done 2>&1 | perl logsplitter.pl -n rotate-seq -rotateByTime run -timeLimit 5 -rotateBy lines -limit 40

 wc -l *.log
      40 rotate-seq-2015-02-17-160626.log	<- 40 lines limit
       1 rotate-seq-2015-02-17-160627.log	<- lapsed 5 seconds
      40 rotate-seq-2015-02-17-160631.log	<- 40 lines limit
       8 rotate-seq-2015-02-17-160632.log	<- lapsed 5 seconds
      11 rotate-seq.log
     100 total

=item B<Rotate file explicitly written by a program>

 mkfifo /tmp/logpipe
 tail -c +1 -f /tmp/logpipe | perl logsplitter.pl -n rotate-seq -rotateBySize lines -l 10 -i test001-rotate-seq &
 seq 1 100 2>&1 >/tmp/logpipe

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

=item B<Identify PID of background logsplitter process>

 ps -f | grep "test001-rotate-seq" | grep -v grep
 501  8553   534   0 11:32AM ttys002    0:00.07 perl logsplitter.pl -n rotate-seq -r lines -l 10 -i test001-rotate-seq

 Note that above example is from OSX. Parameters of ps command and its output varies on different operating systems.

=back

=head1 PERFORMANCE
	
log splitter was verified to work on three levels of speed: (1) unbuffered write, read from stdin: 100MB/s, (2) buffered write (-f option), read from stdin: 30MB/s, (3) unbuffered write, read from fifo pipe: 10MB/s. Each level of measured speed seems enough for logging purposes.

=head1 AUTHOR

Ryszard Styczynski
<ryszard.styczynski@oracle.com>
<http://snailsinnoblesoftware.blogspot.com>

February 2015, version 0.2

=cut

