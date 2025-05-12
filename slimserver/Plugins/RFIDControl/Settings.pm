#
# Custom Skip 3
#
# (c) 2021 AF
#
# Based on the CustomSkip plugin by (c) 2006 Erland Isaksson
#
# GPLv3 license
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
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
