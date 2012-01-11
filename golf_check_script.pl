#! /usr/bin/perl

use strict;
use utf8;
use warnings;

use Cwd ();
use FindBin ();
use LWP::UserAgent ();
use HTML::TreeBuilder ();

#binmode(STDIN,  ":utf8");
binmode(STDOUT, ":utf8");

my $CURRENT_DIR = Cwd::getcwd();
my $PERL = '/usr/bin/perl';
my $ARGC = scalar(@ARGV);

my $MAIN_PL = 'main.pl';

### main
&main();
exit(0);
###

sub main {
	if ($ARGC == 0) { #optionが無い場合は usage 出力
		my $this_dir = $FindBin::Bin;
		my $help_file = 'README';

		open(FILE, "<:utf8", "$this_dir/$help_file") or die $!;
		print <FILE>;
		close(FILE);

		return;
	}

	# make
	if ($ARGV[0] eq 'make' || $ARGV[0] eq 'm') {
		&make();
		return;
	}

=comment
	if ($ARGV[0] =~ /\d/) {
		print $&,$/;
		return;
	}
=cut
}

# 引数のURLからdirectory, input/outputのファイルを作成
sub make {
	if ($ARGC != 2) {
		print 'ERROR : make の引数にURLがありません。',"\n";
		return;
	}

	my $url = $ARGV[1];
	my $user_agent = 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_3; ja-jp) AppleWebKit/533.16 (KHTML, like Gecko) Version/5.0 Safari/533.16';

	if ($url !~ /golf.shinh.org/) {
		print 'golf.shinh.org のURLではありません。',"\n";
		return;
	} else {
		# ディレクトリの作成、移動
		$url =~ /\?/;
		my $dir_path = "$CURRENT_DIR/$'";
		if (! -d $dir_path) {
			mkdir($dir_path);
		}
		chdir($dir_path) or die $!;
	}

	# HTML取得
	my $ua = LWP::UserAgent->new('agent' => $user_agent);
	my $res = $ua->get($url);
	my $content = $res->content;

	&make_io_text(0, $content);
	&make_io_text(1, $content);

	# input/output 作成
	sub make_io_text {
		my ($search, $content) = @_;

		my $search_str = $search==0?'<h2>Sample input':'<h2>Sample output';
		my $file = $search==0?'input':'output';

		for (my $i=1, my $index=0; $i<=3; $i++, $index++) {
			$index = index($content, $search_str, $index);
			if ($index == -1) {
				last;
			}

			my $input_start = index($content, '<pre>', $index) + length'<pre> ';
			my $input_end   = index($content, '</pre>', $index);
	
			my $input_text = '';
			$input_text = substr($content, $input_start, $input_end-$input_start);
			$input_text =~ s/&gt;/>/g;
			$input_text =~ s/&lt;/</g;
	
			# ファイル作成
			my $file_name = "$file$i.txt";
			open(FILE, ">$file_name") or die $!;
			print FILE $input_text;
			close(FILE);
		}
	}

	# main.pl を作成
	open(FILE, ">$MAIN_PL") or die $!;
	print FILE "\n\n\n# $url";
	close(FILE);
}

