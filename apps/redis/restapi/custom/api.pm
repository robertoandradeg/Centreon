#
# Copyright 2017 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package apps::redis::restapi::custom::api;

use strict;
use warnings;
use centreon::plugins::http;
use JSON::XS;

sub new {
    my ($class, %options) = @_;
    my $self  = {};
    bless $self, $class;

    if (!defined($options{output})) {
        print "Class Custom: Need to specify 'output' argument.\n";
        exit 3;
    }
    if (!defined($options{options})) {
        $options{output}->add_option_msg(short_msg => "Class Custom: Need to specify 'options' argument.");
        $options{output}->option_exit();
    }
    
    if (!defined($options{noptions})) {
        $options{options}->add_options(arguments => 
                    {
                        "interval:s@" => { name => 'interval' },
                        "hostname:s@" => { name => 'hostname' },
                        "port:s@"     => { name => 'port' },
                        "proto:s@"    => { name => 'proto' },
                        "username:s@" => { name => 'username' },
                        "password:s@" => { name => 'password' },
                        "proxyurl:s@" => { name => 'proxyurl' },
                        "timeout:s@"  => { name => 'timeout' },
                        "ssl:s@"      => { name => 'ssl' },
                    });
    }
    $options{options}->add_help(package => __PACKAGE__, sections => 'REST API OPTIONS', once => 1);

    $self->{output} = $options{output};
    $self->{mode} = $options{mode};    
    $self->{http} = centreon::plugins::http->new(output => $self->{output});

    return $self;

}

sub set_options {
    my ($self, %options) = @_;

    $self->{option_results} = $options{option_results};
}

sub set_defaults {
    my ($self, %options) = @_;

    foreach (keys %{$options{default}}) {
        if ($_ eq $self->{mode}) {
            for (my $i = 0; $i < scalar(@{$options{default}->{$_}}); $i++) {
                foreach my $opt (keys %{$options{default}->{$_}[$i]}) {
                    if (!defined($self->{option_results}->{$opt}[$i])) {
                        $self->{option_results}->{$opt}[$i] = $options{default}->{$_}[$i]->{$opt};
                    }
                }
            }
        }
    }
}

sub check_options {
    my ($self, %options) = @_;

    $self->{hostname} = (defined($self->{option_results}->{hostname})) ? shift(@{$self->{option_results}->{hostname}}) : undef;
    $self->{port} = (defined($self->{option_results}->{port})) ? shift(@{$self->{option_results}->{port}}) : 9443;
    $self->{proto} = (defined($self->{option_results}->{proto})) ? shift(@{$self->{option_results}->{proto}}) : 'https';
    $self->{username} = (defined($self->{option_results}->{username})) ? shift(@{$self->{option_results}->{username}}) : '';
    $self->{password} = (defined($self->{option_results}->{password})) ? shift(@{$self->{option_results}->{password}}) : '';
    $self->{timeout} = (defined($self->{option_results}->{timeout})) ? shift(@{$self->{option_results}->{timeout}}) : 10;
    $self->{proxyurl} = (defined($self->{option_results}->{proxyurl})) ? shift(@{$self->{option_results}->{proxyurl}}) : undef;
    $self->{ssl} = (defined($self->{option_results}->{ssl})) ? shift(@{$self->{option_results}->{ssl}}) : 'tlsv1';
    $self->{interval} = (defined($self->{option_results}->{interval})) ? shift(@{$self->{option_results}->{interval}}) : '15min';
 
    if (!defined($self->{hostname})) {
        $self->{output}->add_option_msg(short_msg => "Need to specify hostname option.");
        $self->{output}->option_exit();
    }

    if (!defined($self->{hostname}) ||
        scalar(@{$self->{option_results}->{hostname}}) == 0) {
        return 0;
    }
    
    return 1;
}

sub build_options_for_httplib {
    my ($self, %options) = @_;

    $self->{option_results}->{hostname} = $self->{hostname};
    $self->{option_results}->{timeout} = $self->{timeout};
    $self->{option_results}->{port} = $self->{port};
    $self->{option_results}->{proto} = $self->{proto};
    $self->{option_results}->{proxyurl} = $self->{proxyurl};
    $self->{option_results}->{credentials} = 1;
    $self->{option_results}->{username} = $self->{username};
    $self->{option_results}->{password} = $self->{password};
    $self->{option_results}->{ssl} = $self->{ssl};
    $self->{option_results}->{warning_status} = '';
    $self->{option_results}->{critical_status} = '';
}

sub settings {
    my ($self, %options) = @_;

    $self->build_options_for_httplib();
    $self->{http}->set_options(%{$self->{option_results}});
}

sub get_connection_info {
    my ($self, %options) = @_;
    
    return $self->{hostname} . ":" . $self->{port};
}

sub get_interval {
    my ($self, %options) = @_;
    
    return $self->{interval};
}

sub get {
    my ($self, %options) = @_;

    $self->settings();

    my $response = $self->{http}->request(url_path => $options{path});
    
    my $content;
    eval {
        $content = JSON::XS->new->utf8->decode($response);
    };
    if ($@) {
        $self->{output}->add_option_msg(short_msg => "Cannot decode json response: $@");
        $self->{output}->option_exit();
    }

    my $return;
    if (ref($content) eq 'ARRAY') {
        foreach my $uid (@$content) {
            if (defined($uid->{errmsg})) {
                $self->{output}->add_option_msg(short_msg => "Cannot get data: " . $uid->{errmsg});
                $self->{output}->option_exit();
            }
            $return->{$uid->{uid}} = $uid;
        }
    } else {
        if (defined($content->{errmsg})) {
            $self->{output}->add_option_msg(short_msg => "Cannot get data: " . $content->{errmsg});
            $self->{output}->option_exit();
        }
        $return = $content;
    }
    
    return $return;
}

1;

__END__

=head1 NAME

RedisLabs Enterprise Cluster REST API

=head1 SYNOPSIS

RedisLabs Enterprise Cluster Rest API custom mode

=head1 REST API OPTIONS

=over 8

=item B<--interval>

Time interval from which to retrieve statistics (Default: '15min').
Can be : '1sec', '10sec', '5min', '15min', 
'1hour', '12hour', '1week'.

=item B<--hostname>

Cluster hostname.

=item B<--port>

Port used (Default: 9443)

=item B<--proto>

Specify https if needed (Default: 'https')

=item B<--username>

Cluster username.

=item B<--password>

Cluster password.

=item B<--proxyurl>

Proxy URL if any

=item B<--timeout>

Set HTTP timeout

=item B<--ssl>

SSL version (Default: tlsv1)

=back

=head1 DESCRIPTION

B<custom>.

=cut
