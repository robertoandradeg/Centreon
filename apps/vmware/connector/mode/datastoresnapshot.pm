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

package apps::vmware::connector::mode::datastoresnapshot;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $self->{version} = '1.0';
    $options{options}->add_options(arguments =>
                                { 
                                  "datastore-name:s"        => { name => 'datastore_name' },
                                  "filter"                  => { name => 'filter' },
                                  "scope-datacenter:s"      => { name => 'scope_datacenter' },
                                  "disconnect-status:s"     => { name => 'disconnect_status', default => 'unknown' },
                                  "warning-total:s"         => { name => 'warning_total', },
                                  "critical-total:s"        => { name => 'critical_total', },
                                  "warning-snapshot:s"      => { name => 'warning_snapshot', },
                                  "critical-snapshot:s"     => { name => 'critical_snapshot', },
                                });
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
    
    foreach my $label (('warning_total', 'critical_total', 'warning_snapshot', 'critical_snapshot')) {
        if (($self->{perfdata}->threshold_validate(label => $label, value => $self->{option_results}->{$label})) == 0) {
            my ($label_opt) = $label;
            $label_opt =~ tr/_/-/;
            $self->{output}->add_option_msg(short_msg => "Wrong " . $label_opt . " threshold '" . $self->{option_results}->{$label} . "'.");
            $self->{output}->option_exit();
        }
    }
    if ($self->{output}->is_litteral_status(status => $self->{option_results}->{disconnect_status}) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong disconnect-status status option '" . $self->{option_results}->{disconnect_status} . "'.");
        $self->{output}->option_exit();
    }
}

sub run {
    my ($self, %options) = @_;
    $self->{connector} = $options{custom};

    $self->{connector}->add_params(params => $self->{option_results},
                                   command => 'datastoresnapshot');
    $self->{connector}->run();
}

1;

__END__

=head1 MODE

Check snapshots usage on datastores.

=over 8

=item B<--datastore-name>

datastore name to list.

=item B<--filter>

Datastore name is a regexp.

=item B<--scope-datacenter>

Search in following datacenter(s) (can be a regexp).

=item B<--disconnect-status>

Status if datastore disconnected (default: 'unknown').

=item B<--warning-total>

Threshold warning in bytes for all snapshots.

=item B<--critical-total>

Threshold critical in bytes for all snapshots.

=item B<--warning-snapshot>

Threshold warning in bytes for a single snapshot.

=item B<--critical-snapshot>

Threshold critical in bytes for a single snapshot.

=back

=cut
