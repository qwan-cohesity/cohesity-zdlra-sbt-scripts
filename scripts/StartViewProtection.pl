# Copyright 2019 Cohesity Inc.
#
# Author: Qing Wan
#
# This script will start a protection run for specified view on Cohesity Cluster
#
# Usage:
#     perl StartViewProtection.pl --help
#

use Getopt::Long;
use strict;
use IrisService;

sub help {
    print <<"HELP";
usage: $0 [options]

options:
    --host       : specify the URL of Cohesity Cluster
    --username   : username to access Cohesity Cluster
    --password   : password to access Choesity Cluster
    --view       : name of target view needs to be protected
    --help|-h    : show help
HELP
    exit(0);
}

GetOptions ("host=s" => \(my $host = undef),
            "username=s" => \(my $username = undef),
            "password=s" => \(my $password = undef),
            "view=s" => \(my $viewname = undef),
            "help|h" => sub { help() },)
or die ("Error in command line arguments, run with --help to show help\n");

if ($host eq undef || $username eq undef || $password eq undef || $viewname eq undef) {
    die ("must speficy host, username, password and viewname\n");
}

my $iss = IrisService->new(
           hosturl => $host,
           username => $username,
           password => $password
          );

# get target view
my $view = $iss->getView($viewname);
if ($view eq undef) {
    die ("failed to get target view\n");
}

my $protectionjobs = $view->{'viewProtection'}->{'protectionJobs'};
my $protectionjob = @{$protectionjobs}[0];
if ($protectionjob->{'type'} ne 'kView') {
    die ("Error: job $protectionjob->{'jobName'} is not for view protection\n");
}

my $policy = $iss->getPolicyForJob($protectionjob->{'jobId'});
if ($policy eq undef) {
    print "failed to get policy for job $protectionjob->{'jobName'} so runnow will not have archival/replication config\n";
}

my $started = $iss->createRunProtectionJob($protectionjob->{'jobId'}, $policy);
if ($started eq 1) {
    print "protection job for view:$viewname is triggered successfully\n";
} else {
    die ("failed to trigger protection job for view:$viewname\n");
}
