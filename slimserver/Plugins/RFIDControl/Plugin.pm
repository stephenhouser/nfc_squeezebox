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

my $tags;

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

	# read tags.csv
	$tags = load_csv_to_hash(
    	filename    => '/config/cache/Plugins/RFIDControl/tags.csv',
    	key_columns => [0],    # Use first column as key; change to [0,1] for composite keys
    	has_header  => 1       # Set to 1 if the CSV has a header row
	);
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

	$log->error('tag:'.$tagId.' received for client:'.$client->id());

	# Sort out what to do with the tag...
	my $tagCmd = $tags->{uc($tagId)};
	if ($tagCmd) {
		my $cmd = $tagCmd->[1];
		if ($cmd eq 'command') {
			my @cmdParameters = split(/ /, $tagCmd->[2]);
			my $request = Slim::Control::Request::executeRequest($client, ['playlist', 'clear']);
		} elsif ($cmd eq 'url') {
			my $url = $tagCmd->[2];
			my $request = Slim::Control::Request::executeRequest($client, ['playlist', 'play', $url]);
		} elsif ($cmd eq 'album') {
			my $album = '/music/'.$tagCmd->[2].'/';
			my $request = Slim::Control::Request::executeRequest($client, ['playlist', 'play', $album]);
		} elsif ($cmd eq 'artist') {
			my $artist = $tagCmd->[2];
			my $request = Slim::Control::Request::executeRequest($client, ['dynamicplaylist', 'playlist', 'play', 'dplccustom_play_artist', 'dynamicplaylist_parameter_1:'.$artist]);
		} elsif ($cmd eq 'genre') {
			my $genre = $tagCmd->[2];
			my $request = Slim::Control::Request::executeRequest($client, ['dynamicplaylist', 'playlist', 'play', 'dplccustom_play_genre', 'dynamicplaylist_parameter_1:'.$genre]);
		} elsif ($cmd eq 'year') {
			my $year = $tagCmd->[2];
			my $request = Slim::Control::Request::executeRequest($client, ['dynamicplaylist', 'playlist', 'play', 'dplccustom_play_year', 'dynamicplaylist_parameter_1:'.$year]);
		} elsif ($cmd eq 'decade') {
			my $decade = $tagCmd->[2];
			my $request = Slim::Control::Request::executeRequest($client, ['dynamicplaylist', 'playlist', 'play', 'dplccustom_play_decade', 'dynamicplaylist_parameter_1:'.$decade]);
		} else {
			$log->warn('Unknown tag command:' . $cmd . ': ' . $tagCmd->[2]);
			$request->setStatusBadParams();
			return;
		}
	} else {
		$log->warn('No entry for tag '.$tagId);
		$request->setStatusBadParams();
		return;
	}

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


## CSV 

sub load_csv_to_hash {
    my (%args) = @_;
    my $filename    = $args{filename} or die "Filename is required.\n";
    my $key_columns = $args{key_columns} || [0];  # Default to first column as key
    my $has_header  = $args{has_header} || 0;

    my %csv_hash;

    open my $fh, '<', $filename or die "Cannot open $filename: $!";

    # Read header if present
    my @header;
    if ($has_header) {
        my $header_line = <$fh>;
        chomp $header_line;
        @header = split_csv_line($header_line);
    }

    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*$/;  # Skip empty lines

        my @fields = split_csv_line($line);

        # Build the key from specified columns
        my $key = join('|', map { $fields[$_] } @$key_columns);

        # Store the entire row as an array reference
        $csv_hash{uc($key)} = \@fields;
    }

    close $fh;
    return \%csv_hash;
}

sub split_csv_line {
    my ($line) = @_;

    # Simple CSV parser: handles commas and quoted fields
    my @fields;
    while (length $line) {
        if ($line =~ s/^"((?:[^"]|"")*)"[, ]*//) {
            # Quoted field, handle escaped quotes
            my $field = $1;
            $field =~ s/""/"/g;
            push @fields, $field;
        } elsif ($line =~ s/^([^,]*),\s*//) {
            # Unquoted field
            push @fields, $1;
        } else {
            # Last field (quoted or unquoted)
            if ($line =~ s/^"(.*)"\s*$//) {
                my $field = $1;
                $field =~ s/""/"/g;
                push @fields, $field;
            } else {
                push @fields, $line;
            }
            last;
        }
    }

    return @fields;
}

*escape = \&URI::Escape::uri_escape_utf8;
*unescape = \&URI::Escape::uri_unescape;

1;
