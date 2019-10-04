# Copyright 2019 Cohesity Inc.
#
# Author: Qing Wan
#
# This script will create a view and associated protection job(same name as view) 
# for it on specified Cohesity Cluster
# 
# Usage:
#     perl CreateView.pl --help   
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
    --view       : name of view which will be created
    --viewbox    : name of view box where view will be created from.
                   this parameter is optional, if not specified, first
                   viewbox configured in Cohesity Cluster will be used
    --policy     : name of policy which protection job for the view will
                   follows
    --help|-h    : show help
HELP
    exit(0); 
}

GetOptions ("host=s" => \(my $host = undef),
            "username=s" => \(my $username = undef),
            "password=s" => \(my $password = undef),
            "view=s" => \(my $viewname = undef),
            "viewbox:s" => \(my $viewboxname = ''),
            "policy=s" => \(my $policyname = undef),
            "help|h"   => sub { help() },)
or die ("Error in command line arguments, run with --help to show help\n");

if ($host eq undef || $username eq undef || $password eq undef
    || $viewname eq undef || $policyname eq undef) {
    die ("must speficy host, username, password, viewname and policyname\n");
}

my $iss = IrisService->new(
           hosturl => $host,
           username => $username,
           password => $password
          );

# get target viewbox
my $viewbox = $iss->getViewBox($viewboxname);
if ($viewbox eq undef) {
    die ("cannot get target viewbox\n");
}

if ($viewboxname eq '') {
    print "Name of viewbox is not specified, so first discovered viewbox:$viewbox->{'name'} will be used\n";
}

print "view:$viewname will be created on viewbox:$viewbox->{'name'}\n";

# get target policy
my $policy = $iss->getPolicy($policyname);
if ($policy eq undef) {
    die ("cannot get target policy\n");
}

# create view
my $view = $iss->createView($viewname, $viewbox->{'id'});
if ($view eq undef) {
    die ("failed to create view\n");
}

print "view:$view->{'name'} is created\n";

# create protection job for the view
my $protectionjob = $iss->createViewProtectionJob($viewname, $policy->{'id'}, $viewbox->{'id'});
if ($protectionjob eq undef) {
    print "try delete just created view\n";
    if ($iss->deleteView($viewname)) {
        print 'successfully delete view ' . "$viewname\n";
    } else {
        print 'failed to delete view ' . "$viewname\n";
    }

    die ("failed to create job for the view\n");
}

print "job:$protectionjob->{'name'} is created with policy:$policy->{'name'}\n";
