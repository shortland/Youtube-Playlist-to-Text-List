#!/usr/bin/perl

use warnings;
use strict;

use JSON;
use File::Slurp;

sub beginSequence {
	my $answer;
	my $hash = decode_json(read_file("authkey.persistent"));
	if (length($hash->{apikey}) < 2) {
		print "\nNo YouTube API key on record. \nPlease register for an API key here: \n\thttps://developers.google.com/youtube/registering_an_application\n\nType:\n\t1) to exit\n\t2) to enter your API key\n:";
		chomp($answer = <STDIN>);
		if ($answer eq 2) {
			print "API Key: ";
			chomp($answer = <STDIN>);
			$hash->{apikey} = $answer;
			write_file("authkey.persistent", encode_json($hash));
			die "New key saved. Please restart the script, choosing the option to use a previously saved key.\n"; # redundant
		}
		elsif ($answer eq 1) {
			die "\n";
		}
		else {
			die "Invalid choice\n";
		}
	}
	else {
		print "A previous API key was found. Type: \n\t1) to use the saved key\n\t2) to enter a new API key\n:";
		chomp(my $answer = <STDIN>);
		if ($answer eq 2) {
			print "API Key: ";
			chomp($answer = <STDIN>);
			$hash->{apikey} = $answer;
			write_file("authkey.persistent", encode_json($hash));
			die "New key saved. Please restart the script, choosing the option to use a previously saved key.\n";
		}
		elsif ($answer eq 1) {
			print "Using old key...\n";
			$answer = decode_json(read_file("authkey.persistent"))->{apikey};
			# begin
			print "What's the playlist id?\nWhen viewing a playlist in youtube, the URL will look something like this:\n\thttps://www.youtube.com/playlist?list=PLwMEL7UNT4o9iMzrvNBXZqXbNPFfT6rVD\n\nCopy and paste everything after 'list='. That's the playlist id.\nPlaylist id:";
			chomp(my $answer2 = <STDIN>);
			print "Want a list of:\n\t1) The video titles\n\t2) The video IDs\n\t3) The video URLs\n:";
			chomp(my $answer3 = <STDIN>);
			if($answer3 =~ /^(1|2|3)$/) {
				#ok
			}
			else {
				die "Invalid choice\n";
			}
			getPlayLists($answer, $answer2, "-", $answer3);
		}
		else {
			die "Invalid choice\n";
		}
	}
}

# handler to begin recursive (if necessary) fetching of playlist pages
sub getPlayLists {
	my ($apikey, $playlistid, $nextpagetoken, $handle) = @_;
	my $fileName;
	if ($nextpagetoken =~ /^(-)$/) {
		$fileName = "firstOne";
	}
	else {
		$fileName = $nextpagetoken;
	}
	# handle dir deletion creation
	handleDirMakeDelete($playlistid, $fileName);

	#write the page data.
	writePagesData($apikey, $playlistid, $fileName, "", $playlistid, $handle);
}
# handler to write the json data to files so we can later parse through them all.
# technically we could just get-> then parse. but we're saving the pages incase we want something else later...? song description etc.? idk.
sub writePagesData {
	my ($apikey, $playlistid, $fileName, $next, $dirname, $handle) = @_;
	my $requestUrl = "https://www.googleapis.com/youtube/v3/playlistItems?pageToken=$next&part=snippet,contentDetails&maxResults=50&playlistId=$playlistid&key=$apikey";
	my $response = `curl -s "$requestUrl"`;

	my $error = "";
	$error = decode_json($response)->{error}{errors}[0]->{reason} if exists (decode_json($response)->{error}{errors}[0]->{reason});
	if ($error =~ /^keyInvalid$/) {
		die "It appears your API key is invalid. Please make sure to follow Google's steps to create a valid key.\n";
	}
	elsif ($error =~ /^playlistNotFound$/) {
		die "It appears you entered an invalid 'playlist id'. All usermade playlists start with the first two characters 'PL'. If yours doesn't, you may be looking at the wrong id. (Or it's not a usermade list)\n";
	}
	elsif ($error =~ /^$/) {
		# no error occured ( i think )
	}
	else {
		die "An unhandlable error occured: '" . $error . "'\nPlease report it to me :)\n";
	}
	write_file($dirname . "/" . $fileName . ".json", $response); print $!;
	$response = decode_json($response);
	# reset, and get next page keycode
	$next = "";
	$next = $response->{nextPageToken} if exists $response->{nextPageToken};
	if ($next =~ /^$/) {
		# do nothing
		print "Done. No more pages in playlist.\nProceeding with parsing through pages...\nprint $handle";
		parsePagesInDir($dirname, $handle, getAllFilesInDir($dirname));
	}
	else {
		print "Recursively going to next page. (" . $next . ")\n";
		writePagesData($apikey, $playlistid, $next, $next, $dirname, $handle);
	}
}

sub parsePagesInDir {
	my ($dirname, $handle, @files) = @_;
	# holds video titles, so we can cross reference for repeats
	my @allTitles;
	# create file that'll hold each song title. delimited with new line
	write_file($dirname . "/VideoData.txt", "");
	# json formatted file to be proper :)
	write_file($dirname . "/VideoData.json", "{\"titles\":[]}");
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
			($jsonData = read_file($dirname . "/" . $file)) =~ s/\n//g;
			$jsonData = decode_json($jsonData);
			my @items = @{$jsonData->{items}};
			my $x = 0;
			foreach my $item (@items) {
				if ($handle eq 1) {
					$item = $item->{snippet}{title};
				}
				elsif ($handle eq 2) {
					if ($item->{snippet}{title} =~ /^Deleted video$/) {
						$item = "Deleted video";
					}
					else {
						$item = $item->{snippet}{resourceId}{videoId};
					}
				}
				elsif ($handle eq 3) {
					if ($item->{snippet}{title} =~ /^Deleted video$/) {
						$item = "Deleted video";
					}
					else {
						$item = "https://www.youtube.com/watch?v=".$item->{snippet}{resourceId}{videoId};
					}
				}
				else {
					die "Invalid choice? You shouldn't be able to see this error";
				}

				# find duplicates
				if ($item ~~ @allTitles) {
					print "Skipping found duplicate:\n\t'" . $item . "'\n";
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
	write_file_utf8($dirname . "/VideoData.txt", $flattenedContext);
	print scalar(@allTitles) . " saved!\nInfo has been saved to file: $dirname/VideoData.txt\n";
	my $scalarHash = encode_json(\@allTitles);
	my $readHash = decode_json(read_file($dirname . "/VideoData.json"));
	$readHash->{titles} = $scalarHash;
	write_file_utf8($dirname."/VideoData.json", encode_json($readHash));
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
		unlink $directory . "/" . $fileName;
		print "\t $fileName was deleted...\n";
	}
}

BEGIN {
	beginSequence();
}
