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

# handler to begin recursive (if necessary) fetching of playlist pages
sub getPlayLists {
	my ($apikey, $playlistid, $nextpagetoken) = @_;
	my $fileName;
	if ($nextpagetoken =~ /^$/) {
		$fileName = "firstOne";
	}
	else {
		$fileName = $nextpagetoken;
	}

	# handle dir deletion creation
	handleDirMakeDelete($playlistid, $fileName);

	#write the page data.
	writePagesData($apikey, $playlistid, $fileName, "", $playlistid);
}
# handler to write the json data to files so we can later parse through them all.
# technically we could just get-> then parse. but we're saving the pages incase we want something else later...? song description etc.? idk.
sub writePagesData {
	my ($apikey, $playlistid, $fileName, $next, $dirname) = @_;
	my $requestUrl = "https://www.googleapis.com/youtube/v3/playlistItems?pageToken=$next&part=snippet,contentDetails&maxResults=50&playlistId=$playlistid&key=$apikey";
	my $response = `curl -s "$requestUrl"`;
	write_file($dirname."/".$fileName.".json", $response); print $!;
	$response = decode_json($response);
	# reset, and get next page keycode
	$next = "";
	$next = $response->{nextPageToken} if exists $response->{nextPageToken};
	if ($next =~ /^$/) {
		# do nothing
		print "Done. No more pages in playlist.\nProceeding with parsing through pages...\n";
		parsePagesInDir($dirname, getAllFilesInDir($dirname));
	}
	else {
		print "Recursively going to next page. (".$next.")\n";
		writePagesData($apikey, $playlistid, $next, $next, $dirname);
	}
}

sub parsePagesInDir {
	my ($dirname, @files) = @_;
	# holds video titles, so we can cross reference for repeats
	my @allTitles;
	# create file that'll hold each song title. delimited with new line
	write_file($dirname."/SongTitles.txt", "");
	# json formatted file to be proper :)
	write_file($dirname."/SongTitles.json", "{\"titles\":[]}");
	my $jsonData; # will contain each files json temporarily
	#parse it through
	foreach my $file (@files) {
		# skip hidden files
		my $leadingChar = substr($file, 0, 1);
		if ($leadingChar =~ /^\./) {
			print "unimportant file... skipping it. (hidden files)\n";
		}
		else {
			print "Reading next file: " . $file . "\n";
			($jsonData = read_file($dirname."/".$file)) =~ s/\n//g;
			$jsonData = decode_json($jsonData);
			my @items = @{$jsonData->{items}};
			my $x = 0;
			foreach my $item (@items) {
				$item = $item->{snippet}{title};

				# find duplicates
				if ($item ~~ @allTitles) {
					print "Skipping found duplicate:\n\t'".$item . "'\n";
				}
				elsif ($item =~ /^Deleted video$/) {
					print "Found deleted video. Skipping it.\n";
				}
				else {
					# add to list
					push(@allTitles, $item);
				}
			}
		}
	}
	my $flattenedContext = join("\n", @allTitles);
	write_file_utf8($dirname."/SongTitles.txt", $flattenedContext);
	print scalar(@allTitles) . " titles saved!\n";
	my $scalarHash = encode_json(\@allTitles);
	my $readHash = decode_json(read_file($dirname."/SongTitles.json"));
	$readHash->{titles} = $scalarHash;
	write_file_utf8($dirname."/SongTitles.json", encode_json($readHash));
}

sub write_file_utf8 {
    my ($name, $data) = @_;
    open my $fh, '>:encoding(UTF-8)', $name or die "Couldn't create '$name': $!";
    local $/;
    print $fh $data;
    close $fh;
}

sub handleDirMakeDelete {
	my ($playlistid, $fileName) = @_;
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
	my ($dir) = @_;
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