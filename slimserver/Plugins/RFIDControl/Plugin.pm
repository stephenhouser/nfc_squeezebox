#
# RFIDControl
# (c) 2025 Stephen Houser <stephenhouser@gmail.com>
#
# This is a Lyrion Music Server (LMS) plugin to allow control of LMS by
# tags read from an RFID reader.
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

	# Add our `rfid` command to the CLI dispatch
	Slim::Control::Request::addDispatch(['rfid', 'tag', '_tagid'], [1, 0, 0, \&handleRfidTag]);
}

sub postinitPlugin {
	main::DEBUGLOG && $log->is_debug && $log->debug('Plugin "RFIDControl" is enabled');
}

sub weight {
	# funny sex number
	return 69;
}

sub initPrefs {
	$prefs->init({
		rfidcontrolparentfolderpath => Slim::Utils::OSDetect::dirsFor('prefs'),
		learnenabled => 1,
	});

	$prefs->setValidate({'validator' => 'intlimit', 'low' => 0, 'high' => 1}, 'learnenabled');

	# read saved tag actions from `tags.csv`
	# TODO: This should be part of the preferences not hardcoded
	$tags = load_csv_to_hash(
    	filename    => '/config/cache/Plugins/RFIDControl/tags.csv',
    	key_columns => [0],    # Use first column as key; change to [0,1] for composite keys
    	has_header  => 1       # Set to 1 if the CSV has a header row
	);
}

### CLI ###
# Launches a tag controlled action based on tag presented
# sort of like a macro favorites.
# 16:c9:43:a6:ab:be rfid tag prince
# 16:c9:43:a6:ab:be rfid tag stop
# 16:c9:43:a6:ab:be rfid tag 100.9
sub handleRfidTag {
	main::DEBUGLOG && $log->is_debug && $log->debug('Entering handleRfidTag');

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
		$request->setStatusDone();
		#$request->setStatusBadParams();
		return;
	}

	$log->error('tag:'.$tagId.' received for client:'.$client->id());

	# Sort out what to do with the tag...
	my $tagCmd = $tags->{uc($tagId)};
	if ($tagCmd) {
		my $cmd = $tagCmd->[1];
		if ($cmd eq 'command') {
			# Allows for an arbitrary command string to be passed to LMS
			my @parameters = split(/ /, $tagCmd->[2]);
			my $request = Slim::Control::Request::executeRequest($client, \@parameters);
			# my $request = Slim::Control::Request::executeRequest($client, ['playlist', 'clear']);

		} elsif ($cmd eq 'url') {
			# Play from a URL, e.g. radio station, etc..
			my $url = $tagCmd->[2];
			my $request = Slim::Control::Request::executeRequest($client, ['playlist', 'play', $url]);

		} elsif ($cmd eq 'album') {
			# Play an album in the music library in album order
			# TODO: music location for albums is hardcoded to /music. Pull from prefs
			# Slim::Utils::Misc::getAudioDir()
			my $album = '/music/'.$tagCmd->[2].'/';
			#Slim::Player::Playlist::shuffle($client, 0);
			# my $shuffle_request = Slim::Control::Request::executeRequest($client, ['playlist', 'shuffle', '0']);
			my $request = Slim::Control::Request::executeRequest($client, ['playlist', 'play', $album]);

		} elsif ($cmd eq 'playlist') {
			# Play the playlist in order
			# TODO: music location for albums is hardcoded to /music. Pull from prefs
			# Slim::Utils::Misc::getPlaylistDir()
			my $album = '/playlist/'.$tagCmd->[2].'.m3u';
			#Slim::Player::Playlist::shuffle($client, 0);
			# my $shuffle_request = Slim::Control::Request::executeRequest($client, ['playlist', 'shuffle', '0']);
			my $request = Slim::Control::Request::executeRequest($client, ['playlist', 'play', $album]);

		} elsif ($cmd eq 'year') {
			# Shuffle, using dynamicplaylist, all the songs from a given year.
			# Requires dynamic playlist plugin and a dynamic playlist named 'play_year' to be defined
			my $year = $tagCmd->[2];
			my $request = Slim::Control::Request::executeRequest($client, ['dynamicplaylist', 'playlist', 'play', 'dplccustom_play_year', 'dynamicplaylist_parameter_1:'.$year]);

		} elsif ($cmd eq 'decade') {
			# Shuffle, using dynamicplaylist, all the songs from a given decade.
			# Requires dynamic playlist plugin and a dynamic playlist named 'play_decade' to be defined
			my $decade = $tagCmd->[2];
			my $request = Slim::Control::Request::executeRequest($client, ['dynamicplaylist', 'playlist', 'play', 'dplccustom_play_decade', 'dynamicplaylist_parameter_1:'.$decade]);

		} elsif ($cmd eq 'artist') {
			# Shuffle, using dynamicplaylist, all the songs from a given artist.
			# Requires dynamic playlist plugin and a dynamic playlist named 'play_artist' to be defined
			my $artist = $tagCmd->[2];
			my $request = Slim::Control::Request::executeRequest($client, ['dynamicplaylist', 'playlist', 'play', 'dplccustom_play_artist', 'dynamicplaylist_parameter_1:'.$artist]);

		} elsif ($cmd eq 'genre') {
			# Shuffle, using dynamicplaylist, all the songs from a given genre.
			# Requires dynamic playlist plugin and a dynamic playlist named 'play_genre' to be defined
			my $genre = $tagCmd->[2];
			my $request = Slim::Control::Request::executeRequest($client, ['dynamicplaylist', 'playlist', 'play', 'dplccustom_play_genre', 'dynamicplaylist_parameter_1:'.$genre]);

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
