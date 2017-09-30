#!/usr/bin/perl

use warnings;
use strict;

use JSON;
use File::Slurp;

# quick concept. by no means intentionally clean or proper code here!
# ez way without oauth2. using only api key

my $API_KEY = 'x';
my $playListID = 'PLf4g6XtSoMqTJnJ3USrrp1-8S5wNHq6Po'; # add requests to get this later

# initial request
getPlayLists($API_KEY, $playListID, "");

sub getPlayLists {
	my ($apikey, $playlistid, $nextpagetoken) = @_;
	my $requestUrl = "https://www.googleapis.com/youtube/v3/playlistItems?pageToken=$nextpagetoken&part=snippet%2CcontentDetails&maxResults=50&playlistId=$playlistid&key=$apikey";

	my $fileName;
	if ($nextpagetoken =~ /^$/) {
		$fileName = "firstOne";
	}
	else {
		$fileName = $nextpagetoken;
	}

	print $fileName."\n";

	if (-d $playlistid && $fileName =~ /^firstOne$/) {
		print "Directory appears to be from a previous session. Deleting it and its contents...\n";
		deleteDirectory($playlistid);
		print "Recreating directory...\n";
		system("mkdir $playlistid");
	}
	elsif (-d $playlistid && $fileName !~ /^firstOne$/) {
		print "Appears the directory is from the current session. Not changing it.\n";
	}
	else {
		print "Directory doesn't exist... Creating it.\n";
		system("mkdir $playlistid");
	}
}

sub deleteDirectory {
	my ($dirName) = @_;
	deleteFileNamesFromArray($dirName, getAllFilesInDir($dirName));
	rmdir $dirName;
	print "Directory deleted.\n";
}

#return array
sub getAllFilesInDir {
	my @parms = @_;
    my $dir = $parms[0];
    my @files;
    opendir(DIR, $dir) or die $!;
    while (my $file = readdir(DIR)) {
		push @files, $file;
    }
    closedir(DIR);
    return @files;
}

sub deleteFileNamesFromArray {
	my ($directory, @fileNames) = @_;
	foreach my $fileName (@fileNames) {
		unlink $directory."/".$fileName;
		print "\t $fileName was deleted...\n";
	}
}

#rawr ok fine
# #expected that playlist.json is filled... No automatic method for retrieval (Maybe I'll add later date. This is mostly personal project.)
# print "Reading playlist.json...\n";

# # read playlist, remove new lines so that we can parse it? seems to be giving error if i dont do this (decode_json)
# (my $playList = read_file("playlist.json")) =~ s/\n//g;
# # decode so we can parse into it
# $playList = decode_json($playList);
# # tell us how many songs are in the list
# print "There are " . $playList->{pageInfo}{totalResults} . " songs in this playlist.\n";
# my @playListItems = @{$playList->{items}};
# print @playListItems.length;
# foreach my $songItem (@playListItems) {
# 	print $songItem->{snippet}{title}."\n";
# }