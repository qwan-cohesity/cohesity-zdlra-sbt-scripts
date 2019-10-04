# Copyright 2019 Cohesity Inc.
#
# Author: Qing Wan
#
# perl module to trigger REST API to Cohesity Cluster for view creation, job creation
# and job run
#
# Dependency cpan::REST::Client
# Dependency JSON

package IrisService;

use REST::Client;
use JSON;

use strict;

sub new {
    my($class, %args) = @_;

    my $self = {
        client => REST::Client->new(),
        hosturl => undef,
        apppath => '/irisservices/api/v1',
        username => undef,
        password => undef ,
        authorization => undef,
        %args
    };
    bless $self, $class;

    $self->client->setHost($self->{hosturl});
    # Do not validate the certification
    $self->client->getUseragent()->ssl_opts(verify_hostname => 0);
    $self->client->getUseragent()->ssl_opts(SSL_verify_mode => 'SSL_VERIFY_NONE');

    return($self);
}

sub client {
    my $self = shift;
    return $self->{client};
}

sub authHeader {
    my $self = shift;

    # Get token first if there is no token
    if ($self->{authorization} eq undef) {
        print "Fetch the access token for communication with Cohesity Cluster\n";
        $self->getToken();
    }

    return 'Authorization' => "$self->{authorization}";
}

sub acceptHeader {
    return 'Accept' => 'application/json';
}

sub contentHeader {
    return 'Content-Type' => 'application/json';
}

sub successfulResponse {
    my $self = shift;
    my $responseJson = shift;

    if ($responseJson eq undef) {
        return 0;
    }

    if (ref($responseJson) eq 'HASH' && exists $responseJson->{'errorCode'}) {
        print $responseJson->{'errorCode'} . ":" . $responseJson->{'message'} . "\n";
        return 0;
    }
    return 1;
}

sub GET {
    my $self = shift;
    my $resource = shift;
    my $headers = shift;

    if ($resource eq undef) {
        return undef;
    }

    if ($headers eq undef) {
        $headers = {$self->authHeader(), $self->acceptHeader()};
    }

    my $response = $self->client->GET($self->{apppath} . "$resource", $headers);
    return from_json($response->responseContent);
}

sub POST {
    my $self = shift;
    my $resource = shift;
    my $data = shift;
    my $headers = shift;

    if ($resource eq undef) {
        return undef;
    }

    if ($headers eq undef) {
        $headers = {$self->authHeader(), $self->acceptHeader(), $self->contentHeader()};
    }

    my $response = $self->client->POST($self->{apppath} . "$resource", to_json($data), $headers);
    if ($response->responseContent ne '') {
        return from_json($response->responseContent);
    }

    return undef;
}

sub DELETE {
    my $self = shift;
    my $resource = shift;
    my $headers = shift;

    if ($resource eq undef) {
        return undef;
    }

    if ($headers eq undef) {
        $headers = {$self->authHeader()};
    }

    my $response = $self->client->DELETE($self->{apppath} . "$resource", $headers);
    return from_json($response->responseContent);
}

sub getToken {
    my $self = shift;

    my $data = { username => "$self->{username}",
                 password => "$self->{password}" };
    my $headers = {$self->acceptHeader(), $self->contentHeader()};
    my $responseJson = $self->POST('/public/accessTokens', $data, $headers);

    if ($self->successfulResponse($responseJson)) {
        $self->{authorization} = "$responseJson->{'tokenType'} $responseJson->{'accessToken'}";
    }
}

sub getViewBox {
    my $self = shift;
    my $viewboxname = shift;

    my $responseJson = $self->GET('/public/viewBoxes');
    if ($self->successfulResponse($responseJson) && ref($responseJson) eq 'ARRAY') {
        if ($viewboxname ne '') {
            foreach my $viewbox (@{$responseJson}) {
                if ($viewbox->{'name'} eq $viewboxname) {
                    return $viewbox;
                }
            }
        } else {
            return @{$responseJson}[0];
        }
    }
    return undef;
}

sub getPolicy {
    my $self = shift;
    my $policyname = shift;

    my $responseJson = $self->GET('/public/protectionPolicies');
    if ($self->successfulResponse($responseJson) && ref($responseJson) eq 'ARRAY') {
        if ($policyname ne '') {
            foreach my $policy (@{$responseJson}) {
                if ($policy->{'name'} eq $policyname) {
                    return $policy;
                }
            }
        } else {
            return @{$responseJson}[0];
        }
    }
    return undef;
}

sub createView {
    my $self = shift;
    my $viewname = shift;
    my $viewboxid = shift;

    if ($viewname eq undef || $viewboxid eq undef) {
        return undef;
    }

    my $data = { name => "$viewname",
                 viewBoxId => $viewboxid };
    my $responseJson = $self->POST('/public/views', $data);

    if ($self->successfulResponse($responseJson)) {
        return $responseJson;
    }

    return undef;
}

sub deleteView {
    my $self = shift;
    my $viewname = shift;

    if ($viewname eq undef) {
        return 0;
    }

    return $self->successfulResponse($self->DELETE("/public/views/$viewname"));
}

sub getView {
    my $self = shift;
    my $viewname = shift;

    if ($viewname eq undef) {
        return undef;
    }

    my $responseJson = $self->GET("/public/views/$viewname");
    if ($self->successfulResponse($responseJson)) {
        return $responseJson;
    }

    return undef;
}

sub createViewProtectionJob {
    my $self = shift;
    my $viewname = shift;
    my $policyid = shift;
    my $viewboxid = shift;

    if ($viewname eq undef || $viewboxid eq undef || $policyid eq undef) {
        return undef;
    }

    #my $data = "{\"name\": \"$jobname\", \"policyId\": \"$policyid\", \"viewName\": \"$jobname\",
    #    \"viewBoxId\": $viewboxid, \"environment\": \"kView\", \"timezone\": \"America/New_York\"}";
    my $data = { name => "$viewname",
                 policyId => "$policyid",
                 viewName => "$viewname",
                 viewBoxId => $viewboxid,
                 environment => "kView",
                 timezone => "America/New_York" };
    my $responseJson = $self->POST('/public/protectionJobs', $data);
    if ($self->successfulResponse($responseJson)) {
        return $responseJson;
    }

    return undef;
}

sub createRunProtectionJob {
    my $self = shift;
    my $jobid = shift;
    my $policy = shift;

    if ($jobid eq undef) {
        return 0;
    }

    my $archivalpolicy = $policy->{'snapshotArchivalCopyPolicies'};
    my $replicationpolicy = $policy->{'snapshotReplicationCopyPolicies'};

    my @copytargets = ();
    # fill archival setting from policy
    foreach my $archival (@{$archivalpolicy}) {
        my $copytarget = {};
        $copytarget->{'copyPartial'} = $archival->{'copyPartial'};
        $copytarget->{'archivalTarget'} = $archival->{'target'};
        $copytarget->{'daysToKeep'} = $archival->{'daysToKeep'};
        $copytarget->{'type'} = 'kArchival';
        push @copytargets, $copytarget;
    }

    foreach my $replication (@{$replicationpolicy}) {
        my $copytarget = {};
        $copytarget->{'copyPartial'} = $replication->{'copyPartial'};
        $copytarget->{'replicationTarget'} = $replication->{'target'};
        $copytarget->{'daysToKeep'} = $replication->{'daysToKeep'};
        $copytarget->{'type'} = 'kRemote';
        push @copytargets, $copytarget;
    }
    my $data = {};
    $data->{'copyRunTargets'} = \@copytargets;
    $data->{'runType'} = 'kRegular';

    $self->POST("/public/protectionJobs/run/$jobid", $data);
    return 1;
}

sub getPolicyForJob {
    my $self = shift;
    my $jobid = shift;

    if ($jobid eq undef) {
        return undef;
    }

    my $responseJson = $self->GET("/public/protectionJobs/$jobid");
    if ($self->successfulResponse($responseJson)) {
        my $policyid = $responseJson->{'policyId'};
        my $policyResponseJson = $self->GET("/public/protectionPolicies/$policyid");
        if ($self->successfulResponse($policyResponseJson)) {
            return $policyResponseJson;
        }
    }

    return undef;
}

sub getLastestProtectionRun {
    my $self = shift;
    my $jobid = shift;

    if ($jobid eq undef) {
        return undef;
    }

    my $parameters = "id=$jobid&numRuns=1";

    my $responseJson = $self->GET("/backupjobruns?$parameters");
    if ($self->successfulResponse($responseJson)) {
        return @{$responseJson}[0]->{'backupJobRuns'};
    }

    return undef;
}

1;
