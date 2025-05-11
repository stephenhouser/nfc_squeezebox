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

package Plugins::RFIDControl::Plugin;

use strict;
use warnings;
use utf8;
use base qw(Slim::Plugin::Base);

use Slim::Utils::Prefs;
use Slim::Buttons::Home;
use Slim::Utils::Misc;
use Slim::Utils::Strings qw(string);
use File::Spec::Functions qw(:ALL);
use Class::Struct;
use Scalar::Util qw(blessed);
use File::Slurp;
use XML::Simple;
use HTML::Entities;
use Time::HiRes qw(time);
use POSIX qw(floor);
use version;

use FindBin qw($Bin);
use lib catdir($Bin, 'Plugins', 'RFIDControl', 'lib');

my $prefs = preferences('plugin.rfidcontrol');
my $serverPrefs = preferences('server');
my $log = Slim::Utils::Log->addLogCategory({
	'category' => 'plugin.rfidcontrol',
	'defaultLevel' => 'ERROR',
	'description' => 'PLUGIN_RFIDCONTROL',
});

sub initPlugin {
	my $class = shift;
	$class->SUPER::initPlugin(@_);

	if (main::WEBUI) {
		require Plugins::RFIDControl::Settings;
		Plugins::RFIDControl::Settings->new($class);
	}

	initPrefs();

	#Slim::Control::Request::subscribe(\&newSongCallback, [['playlist'], ['newsong']]);

	# Client, Query, Tags
	Slim::Control::Request::addDispatch(['rfid', 'pair', '_readerid', '?'], [0, 1, 0, \&rfidPairReader]);
	Slim::Control::Request::addDispatch(['rfid', 'tag', '_tagid'], [1, 0, 0, \&rfidTagChanged]);
}

sub postinitPlugin {
	#Slim::Utils::Timers::setTimer(undef, Time::HiRes::time() + 4, \&initFilters);
	#registerJiveMenu();
	main::DEBUGLOG && $log->is_debug && $log->debug('Plugin "RFIDControl" is enabled');
}

sub weight {
	return 89;
}

sub initPrefs {
	$prefs->init({
		rfidcontrolparentfolderpath => Slim::Utils::OSDetect::dirsFor('prefs'),
		learnenabled => 1,
	});

	$prefs->setValidate({'validator' => 'intlimit', 'low' => 0, 'high' => 1}, 'learnenabled');
}


### CLI ###
# rfid pair 3C:71:BF:83:C0:DC ?
# returns the client id we control
sub rfidPairReader {
	main::DEBUGLOG && $log->is_debug && $log->debug('Entering rfidPairReader');
	my $request = shift;

	if ($request->isNotQuery([['rfid'],['pair']])) {
		$log->warn('Incorrect command');
		$request->setStatusBadDispatch();
		return;
	}

	# get our parameters
	my $readerId = $request->getParam('_readerid');
	if (!defined $readerId || $readerId eq '') {
		$log->warn('_readerId not defined');
		$request->setStatusBadParams();
		return;
	}

	$log->error('_readerId '.$readerId.' received');

	# Look up reader - client assignment
	if ($readerId eq '3C:71:BF:83:C0:DC') {
		$request->addResult('_clientId', '16:c9:43:a6:ab:be')
	}

	#$request->addResult('tag', $tagId);
	$request->setStatusDone();
}


# Launches a tag controlled action based on tag presented
# sort of like a macro favorites.
# 16:c9:43:a6:ab:be rfid tag prince
# 16:c9:43:a6:ab:be rfid tag stop
# 16:c9:43:a6:ab:be rfid tag 100.9
sub rfidTagChanged {
	main::DEBUGLOG && $log->is_debug && $log->debug('Entering rfidTagReceived');
	my $request = shift;
	my $client = $request->client();

	if ($request->isNotCommand([['rfid'],['tag']])) {
		$log->warn('Incorrect command');
		$request->setStatusBadDispatch();
		return;
	}

	if (!defined $client) {
		$log->warn('Client required');
		$request->setStatusNeedsClient();
		return;
	}

	$client = UNIVERSAL::can(ref($client), 'masterOrSelf')?$client->masterOrSelf():$client->master();

	# get our parameters
	my $tagId = $request->getParam('_tagid');
	if (!defined $tagId || $tagId eq '') {
		$log->warn('_tagid not defined');
		$request->setStatusBadParams();
		return;
	}

	# if (!defined ($filters->{$filterId})) {
	# 	$log->warn("Unknown filter $filterId");
	# 	$request->setStatusBadParams();
	# 	return;
	# }
	$log->error('_tagid '.$tagId.' received');
	if ($tagId eq 'stop') {
		my $playRequest = Slim::Control::Request::executeRequest($client, ['stop']);
	}

	if ($tagId eq 'prince') {
		my $playRequest = Slim::Control::Request::executeRequest($client, ['playlist', 'play', '/music/Prince/1999 (1982)/']);
	}
	
	if ($tagId eq '100.9') {
		my $playRequest = Slim::Control::Request::executeRequest($client, ['playlist', 'play', 'http://opml.radiotime.com/Tune.ashx?id=s24232&formats=aac,ogg,mp3&partnerId=15&serial=59bf631fddda17f8c19e2bc4914096f1']);
	}

	#$request->addResult('tag', $tagId);
	$request->setStatusDone();
}


# common
sub newSongCallback {
	my $request = shift;
	my $client = undef;
	my $command = undef;

	$client = $request->client();
}

## for VFD devices ##
sub setMode {
	my $class = shift;
	my $client = shift;
	my $method = shift;
	my $model = Slim::Player::Client::getClient($client->id)->model if $client;
}

sub modeAction {
	my ($client, $item) = @_;
	$client = UNIVERSAL::can(ref($client), 'masterOrSelf')?$client->masterOrSelf():$client->master();
	my $key = undef;
	if (defined ($client)) {
		$key = $client;
	}
}

sub getFunctions {
	return {
		'up' => sub {
			my $client = shift;
			$client->bumpUp();
		},
		'down' => sub {
			my $client = shift;
			$client->bumpDown();
		},
		'left' => sub {
			my $client = shift;
			Slim::Buttons::Common::popModeRight($client);
		},
		'right' => sub {
			my $client = shift;
			$client->bumpRight();
		}
	}
}

sub getDisplayText {
	# Returns the display text for the currently selected item in the menu
	my ($client, $item) = @_;
	my $id = undef;
	my $name = 'RFIDControl';
	return $name;
}

sub getOverlay {
	# Returns the overlay/symbols displayed next to items in the menu
	my ($client, $item) = @_;
	return [undef, $client->symbols('rightarrow')];
}


*escape = \&URI::Escape::uri_escape_utf8;
*unescape = \&URI::Escape::uri_unescape;

1;
