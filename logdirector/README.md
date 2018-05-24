# SYNOPSIS
     some_program | perl logdirector.pl -name logName [options]
     where:
     -name          log name, but without extension (provided value or default 'log' will be added). This parameter is mandatory,
     -extension     log extension. Default is 'log',
 
     -dir           destination directory for log file. Default is current directory,
     -addDateSubDir create subdirectory with date to keep logs,

     -alwaysRotate  always write to log file with timestamp,
     -prefixDate    put timestamp at front of the file name, default is at the end,
     -separatorDate character to separate timestamp and file name. default is underscore,
 
     -header        add this header on top of each file. Useful for CSV files with hreader,
     -detectHeader  auto detect header from first line of log stream after start. Useful for CSV files with hreader,
     -checkHeaderDups 
                    checks for header duplicates. Useful when writing to non-empty CSV files with header,
 
     -rotateBySize  rotation done by line or byte count. Default is bytes,
     -limit         number of lines or bytes in single log file. Default values are 100 k lines and 50 mega bytes. Value provided as integer,
     -rotateByTime  rotation done by clock of process run time. Default is clock,
     -timeLimit     time limit in seconds. Default is 86400 (1 day),
     -startup       rotate on startup. By default doesn't rotate on startup,
 
     -timeRotationInThread 
                    enable time rotation in thread. Useful when time rotation needs to be independent of data coming from stdin,
     -rotateOnThreadEnd 
                    when rotating in thread, then this flag will rotate the file on the thread end, 
 
     -identifier    log process identifier to be used by administrator/scripts to locate log director running in background,
     -flush         do not buffer output. flush each line. Default is to use buffering,
 
     -verbose       debug mode,
     -help          this help,
     -man           shows longer manual.

     You can use first letters of option names to make command line shorter.

# DESCRIPTION
    Forwards stdin data stream to a log file and maintain log naming and
    rotation rules. Rotated files get date/time signature at the end or at
    begining of the file name, and may be written to daily directory. In
    case of name conflict (too fast log generation), date/time is extended
    by unique sequence. Supports flexible rotation rules. Rewrties file
    headers on request, what is useful for CVS files rotation.

# EXAMPLES

## Rotate by bytes
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

 ## Rotate by lines
     seq 1 100 | perl logdirector.pl -n rotate-seq -rotateBySize lines -l 10
     wc -l rotate-seq* 10 rotate-seq-2015-01-21-170025-1.log 10
     rotate-seq-2015-01-21-170025-2.log 10
     rotate-seq-2015-01-21-170025-3.log 10
     rotate-seq-2015-01-21-170025-4.log 10
     rotate-seq-2015-01-21-170025-5.log 10
     rotate-seq-2015-01-21-170025-6.log 10
     rotate-seq-2015-01-21-170025-7.log 10
     rotate-seq-2015-01-21-170025-8.log 10
     rotate-seq-2015-01-21-170025-9.log 10 rotate-seq-2015-01-21-170025.log
     0 rotate-seq.log 100 total

## Rotate by process run time
      # waiting for proper time x 1s
      while [ $(date +%S | cut -b2) -ne 1 ]; do sleep 1; echo -n .; done; echo
      for cnt in $(seq 1 100); do echo $cnt; sleep 0.1; done  | perl logdirector.pl -n rotate-seq -rotateByTime run -timeLimit 5 -flush
      ls -lhTU *.log
      -rw-r--r--  1 user  staff   123B Feb 17 16:34:11 2015 rotate-seq-2015-02-17-163416.log <- lapsed 5 seconds 
      -rw-r--r--  1 user  staff   147B Feb 17 16:34:16 2015 rotate-seq-2015-02-17-163421.log <- lapsed 5 seconds
      -rw-r--r--  1 user  staff    22B Feb 17 16:34:21 2015 rotate-seq.log

## Rotate by clock time
      for cnt in $(seq 1 100); do echo $cnt; sleep 0.1; done  | perl logdirector.pl -n rotate-seq -rotateByTime clock -timeLimit 5 
      wc -l rotate-seq*
           32 rotate-seq-2015-02-17-161715.log        <- wall clock passed 5 seconds window
           48 rotate-seq-2015-02-17-161720.log        <- wall clock passed 5 seconds window
           20 rotate-seq.log
          100 total

## Rotate by lines and process run time
      for cnt in $(seq 1 100); do echo $cnt; sleep 0.1; done  | perl logdirector.pl -n rotate-seq -rotateByTime run -timeLimit 5 -rotateBy lines -limit 40
      wc -l *.log
           40 rotate-seq-2015-02-17-160626.log       <- 40 lines limit
            1 rotate-seq-2015-02-17-160627.log       <- lapsed 5 seconds
           40 rotate-seq-2015-02-17-160631.log       <- 40 lines limit
            8 rotate-seq-2015-02-17-160632.log       <- lapsed 5 seconds
           11 rotate-seq.log
          100 total
     
## Rotate by clock time, save files to directory keeping timestamp prefix, add header to each file.
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

## Rotate file explicitly written by a program
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

## Identify PID of background logdirector process
      ps -f | grep "test001-rotate-seq" | grep -v grep
      501  8553   534   0 11:32AM ttys002    0:00.07 perl logdirector.pl -n rotate-seq -r lines -l 10 -i test001-rotate-seq
      Note that above example is from OSX. Parameters of ps command and its output varies on different operating systems.

## Log rotation triggered by external process
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

## Detect header duplicates

When the log director starts writing data to an existing non-empty CSV log file, there could be a header present on the first line of the log. 
With option detectHeaderDups it is possible to check that the first line header is not repeated in subsequent writes in the log file. 

## Time based rotation in a thread

If you need to run the time rotation while you need to be independent of incoming data from stdin, you can use an option to rotate 
files in an internal rotation thread. This is useful when you need to generate log files in batches that could be taken up by another script
in an asynchronous manner, for example, when you want to decouple log data collection and a script pushing data to a remote endpoint. 
In such a case, the script pushing data to the remote endpoint won't block collection process.

The below is the example:

```
umc free collect 30 4 | perl logdirector.pl -name free -rotateByTime run -timeLimit 10 -flush -timeRotationInThread -rotateOnThreadEnd
```

This will rotate the file every 10 seconds but only when there is data in the file. The parameter rotateOnThreadEnd will rotate the file 
when the rotation thread ends, i.e. when the log director ends. 

# PERFORMANCE
    log director was verified to work on three levels of speed: (1)
    unbuffered write, read from stdin: 100MB/s, (2) buffered write (-f
    option), read from stdin: 30MB/s, (3) unbuffered write, read from fifo
    pipe: 10MB/s. Each level of measured speed seems enough for logging
    purposes.

# AUTHOR
    Ryszard Styczynski <ryszard.styczynski@oracle.com>
    <http://snailsinnoblesoftware.blogspot.com>

    February 2015 - November 2017, version 0.3

# CONTRIBUTORS

    Tomas Vitvar <tomas@vitvar.com> <http://vitvar.com>
      05-2018: Time based rotation in thread

