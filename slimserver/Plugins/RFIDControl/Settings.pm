#
# RFID Control
#

package Plugins::RFIDControl::Settings;

use strict;
use warnings;
use utf8;
use base qw(Slim::Web::Settings);
use File::Basename;
use File::Next;
use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Slim::Utils::Misc;
use Slim::Utils::Strings;

my $prefs = preferences('plugin.rfidcontrol');
my $log = logger('plugin.rfidcontrol');
my $plugin;

sub name {
	return Slim::Web::HTTP::CSRF->protectName('PLUGIN_RFIDCONTROL');
}

sub page {
	return Slim::Web::HTTP::CSRF->protectURI('plugins/RFIDControl/settings/basic.html');
}

sub prefs {
	return ($prefs, qw(rfidcontrolparentfolderpath learnenabled));
}

sub handler {
	my ($class, $client, $paramRef) = @_;
	return $class->SUPER::handler($client, $paramRef);
}

1;
